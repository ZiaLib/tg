part of '../tg.dart';

class Client extends t.Client {
  final int apiId;
  final String apiHash;
  void Function(t.UpdatesBase updates)? onUpdate;
  void Function(AuthorizationKey authKey)? onAuthKeyUpdate;
  void Function()? onUnauthorized;
  TelegramSession session;

  final Duration timeout;
  final int? requestRetries;
  final int? connectionRetries;
  final Duration retryDelay;
  final bool autoReconnect;

  late Obfuscation obfuscation;
  late IoSocket socket;
  late MessageIdGenerator idGenerator;
  late int _sessionId;

  final Map<int, Completer<t.Result>> _pending = {};
  final Map<int, t.TlMethod> _pendingMethods = {};
  final _streamController = StreamController<UpdatesBase>.broadcast();

  List<t.DcOption> _dcOptions = [];
  StreamSubscription? _updateSubscription;
  bool _connected = false;
  int _connectionAttempts = 0;
  bool _migrating = false;
  final Map<int, Client> _dcClients = {};

  List<t.DcOption> get dcOptions => _dcOptions;

  bool get connected => _connected;

  Stream<UpdatesBase> get stream => _streamController.stream;

  Client({
    required this.apiId,
    required this.apiHash,
    required this.session,
    this.onUpdate,
    this.onAuthKeyUpdate,
    this.onUnauthorized,
    this.timeout = const Duration(seconds: 10),
    this.requestRetries = 5,
    this.connectionRetries,
    this.retryDelay = const Duration(seconds: 1),
    this.autoReconnect = true,
  }) : super();

  static Future<AuthorizationKey> authorize(
    SocketAbstraction socket,
    Obfuscation obfuscation,
    MessageIdGenerator idGenerator,
  ) async {
    final Set<int> msgsToAck = {};
    final uot = _UnEncryptedTransformer(
      socket.receiver,
      msgsToAck,
      obfuscation,
    );
    final dh = _DiffieHellman(
      socket,
      uot.stream,
      obfuscation,
      idGenerator,
      msgsToAck,
    );
    final ak = await dh.exchange();
    await uot.dispose();
    return ak;
  }

  Future<void> connect() async {
    _connectionAttempts = 0;
    await _connectWithRetry();
  }

  Future<void> updateSession(TelegramSession session) async {
    await close();
    this.session = session;
    await connect();
  }

  Future<void> _connectWithRetry() async {
    while (true) {
      try {
        await _performConnect();
        _connected = true;
        _connectionAttempts = 0;
        _migrating = false;
        break;
      } catch (_) {
        _connected = false;
        _connectionAttempts++;
        if (connectionRetries != null &&
            connectionRetries! >= 0 &&
            _connectionAttempts >= connectionRetries!) {
          rethrow;
        }
        await Future.delayed(retryDelay);
      }
    }
  }

  Future<void> _performConnect() async {
    await close();
    _sessionId = Random().nextInt(1 << 31);
    session.dcOption ??= defaultDcOption;
    session.device = TelegramSessionDevice(
      deviceModel: session.device?.deviceModel ?? Platform.operatingSystem,
      appVersion: session.device?.appVersion ?? '1.0.0',
      systemVersion:
          session.device?.systemVersion ?? Platform.operatingSystemVersion,
      systemLangCode: session.device?.systemLangCode ?? 'en',
      langCode: session.device?.langCode ?? 'en',
    );
    final Socket rawSocket;
    switch (session.proxyConfig.type) {
      case ProxyType.none:
        rawSocket = await Socket.connect(
          session.dcOption!.ipAddress,
          session.dcOption!.port,
        ).timeout(timeout);
        break;
      case ProxyType.socks5:
        final proxyConfig = session.proxyConfig as Socks5ProxyConfig;
        rawSocket = await SocksTCPClient.connect(
          [
            ProxySettings(
              InternetAddress(proxyConfig.host),
              proxyConfig.port,
              username: proxyConfig.username,
              password: proxyConfig.password,
            ),
          ],
          InternetAddress(session.dcOption!.ipAddress),
          session.dcOption!.port,
        ).timeout(timeout);
        break;
    }
    socket = IoSocket(rawSocket);
    _updateSubscription = stream.listen(
      (updates) {
        onUpdate?.call(updates);
      },
      onError: (error) async {
        if (autoReconnect) {
          await _handleDisconnection();
        }
      },
      onDone: () async {
        if (autoReconnect) {
          await _handleDisconnection();
        }
      },
    );
    obfuscation = Obfuscation.random(false, session.dcOption!.id);
    idGenerator = MessageIdGenerator();
    await socket.send(obfuscation.preamble);
    if (_migrating) {
      session.authorizationKey = null;
      _migrating = false;
    }
    session.authorizationKey ??= await authorize(
      socket,
      obfuscation,
      idGenerator,
    ).timeout(timeout);
    final transformer = _EncryptedTransformer(
      socket.receiver,
      obfuscation,
      session.authorizationKey!,
    );
    transformer.stream.listen((v) {
      _handleIncomingMessage(v);
    });
    final config = await _initConnection().timeout(timeout);
    if (config.result?.dcOptions is List) {
      _dcOptions.clear();
      _dcOptions = List<t.DcOption>.from(config.result!.dcOptions);
    }
  }

  Future<t.Result<t.Config>> _initConnection() async {
    return await initConnection<t.Config>(
      apiId: apiId,
      deviceModel: session.device!.deviceModel!,
      appVersion: session.device!.appVersion!,
      systemVersion: session.device!.systemVersion!,
      systemLangCode: session.device!.systemLangCode!,
      langCode: session.device!.langCode!,
      langPack: '',
      query: t.HelpGetConfig(),
    );
  }

  Future<void> _handleDisconnection() async {
    if (!autoReconnect || !_connected || _migrating) return;
    _connected = false;
    try {
      await _connectWithRetry();
    } catch (_) {}
  }

  void _handleIncomingMessage(t.TlObject msg) {
    if (msg is UpdatesBase) {
      _streamController.add(msg);
    }
    if (msg is t.MsgContainer) {
      for (final message in msg.messages) {
        _handleIncomingMessage(message);
      }
      return;
    } else if (msg is t.Msg) {
      _handleIncomingMessage(msg.body);
      return;
    } else if (msg is t.BadServerSalt) {
      final badMsgId = msg.badMsgId;
      final task = _pending[badMsgId];
      final method = _pendingMethods[badMsgId];
      session.authorizationKey = AuthorizationKey(
        session.authorizationKey!.id,
        session.authorizationKey!.key,
        msg.newServerSalt,
      );
      onAuthKeyUpdate?.call(session.authorizationKey!);
      _sessionId = Random().nextInt(1 << 31);
      if (method != null && task != null && !task.isCompleted) {
        _pending.remove(badMsgId);
        _pendingMethods.remove(badMsgId);
        Future.microtask(() async {
          try {
            final result = await _invokeInternal(method).timeout(timeout);
            task.complete(result);
          } catch (e) {
            task.completeError(e);
          }
        });
        return;
      }
    } else if (msg is t.BadMsgNotification) {
      final badMsgId = msg.badMsgId;
      final task = _pending[badMsgId];
      task?.completeError(BadMessageException._(msg));
      _pending.remove(badMsgId);
      _pendingMethods.remove(badMsgId);
    } else if (msg is t.RpcResult) {
      final reqMsgId = msg.reqMsgId;
      final task = _pending[reqMsgId];
      final result = msg.result;
      if (result is t.RpcError) {
        if (result.errorCode == 401) {
          close().then((_) => onUnauthorized?.call());
        }
        task?.complete(t.Result.error(result));
        _pending.remove(reqMsgId);
        _pendingMethods.remove(reqMsgId);
        return;
      } else if (result is t.GzipPacked) {
        final gZippedData = GZipDecoder().decodeBytes(result.packedData);
        final newObj =
            BinaryReader(Uint8List.fromList(gZippedData)).readObject();
        final newRpcResult = t.RpcResult(reqMsgId: reqMsgId, result: newObj);
        _handleIncomingMessage(newRpcResult);
        return;
      }
      task?.complete(t.Result.ok(msg.result));
      _pending.remove(reqMsgId);
      _pendingMethods.remove(reqMsgId);
    } else if (msg is t.GzipPacked) {
      final gZippedData = GZipDecoder().decodeBytes(msg.packedData);
      final newObj = BinaryReader(Uint8List.fromList(gZippedData)).readObject();
      _handleIncomingMessage(newObj);
    }
  }

  @override
  Future<t.Result<t.TlObject>> invoke(t.TlMethod method) async {
    return await _invokeWithRetry(method, 0);
  }

  Future<t.Result<t.TlObject>> _invokeWithRetry(
    t.TlMethod method,
    int attempts,
  ) async {
    try {
      if (!_connected) {
        if (autoReconnect && !_migrating) {
          await _handleDisconnection();
        } else {
          throw Exception('Client not connected');
        }
      }
      final result = await _invokeInternal(method).timeout(timeout);
      final error = result.error;
      if (error != null) {
        if (error.errorMessage.startsWith('PHONE_MIGRATE_')) {
          _migrating = true;
          final dcId = int.parse(error.errorMessage.split('_').last);
          session.dcOption = _dcOptions.firstWhere(
            (dcOption) => dcOption.id == dcId && !dcOption.ipv6,
          );
          await connect();
          return await _invokeWithRetry(method, attempts);
        } else if (error.errorMessage.contains('_MIGRATE_')) {
          final dcId = int.parse(error.errorMessage.split('_').last);
          final result = await _invokeOnDC(error, method, dcId);
          return result;
        }
        if (_shouldRetry(error, attempts)) {
          await Future.delayed(retryDelay);
          return await _invokeWithRetry(method, attempts + 1);
        }
      }
      return result;
    } catch (e) {
      if (_shouldRetryException(e, attempts)) {
        await Future.delayed(retryDelay);
        if (!_connected && autoReconnect) {
          await _handleDisconnection();
        }
        return await _invokeWithRetry(method, attempts + 1);
      }
      rethrow;
    }
  }

  Future<t.Result<t.TlObject>> _invokeOnDC(
    t.RpcError error,
    t.TlMethod method,
    int dcId,
  ) async {
    if (_dcClients.containsKey(dcId)) {
      return await _dcClients[dcId]!._invokeInternal(method).timeout(timeout);
    }
    final dcClient = await _createDCClient(dcId);
    if (dcClient == null) {
      return t.Result.error(error);
    }
    _dcClients[dcId] = dcClient;
    return await dcClient._invokeInternal(method).timeout(timeout);
  }

  Future<Client?> _createDCClient(int dcId) async {
    final exportRes = await _invokeInternal(
      t.AuthExportAuthorization(dcId: dcId),
    ).timeout(timeout);
    if (exportRes.error != null) {
      return null;
    }
    final exportAuth = exportRes.result as t.AuthExportedAuthorization;
    final dcOptionIndex = _dcOptions.indexWhere(
      (option) => option.id == dcId && !option.ipv6,
    );
    if (dcOptionIndex == -1) {
      return null;
    }
    final dcOption = _dcOptions[dcOptionIndex];
    final newSession = TelegramSession(
      dcOption: dcOption,
      device: session.device,
      proxyConfig: session.proxyConfig,
    );
    final dcClient = Client(
      apiId: apiId,
      apiHash: apiHash,
      session: newSession,
      timeout: timeout,
      requestRetries: requestRetries,
      connectionRetries: connectionRetries,
      retryDelay: retryDelay,
      autoReconnect: false,
    );
    await dcClient.connect();
    final importRes = await dcClient
        ._invokeInternal(
          t.AuthImportAuthorization(
            id: exportAuth.id,
            bytes: exportAuth.bytes,
          ),
        )
        .timeout(timeout);
    if (importRes.error != null) {
      await dcClient.close();
      return null;
    }
    return dcClient;
  }

  Future<t.Result<t.TlObject>> _invokeInternal(t.TlMethod method) async {
    final preferEncryption = session.authorizationKey!.id != 0;
    final msgsToAck = session.authorizationKey!._msgsToAck;
    final completer = Completer<t.Result>();
    final m = idGenerator._next(preferEncryption);
    if (preferEncryption && msgsToAck.isNotEmpty) {
      final ack = idGenerator._next(false);
      final ackMsg = MsgsAck(msgIds: msgsToAck.toList());
      msgsToAck.clear();
      final container = MsgContainer(
        messages: [
          Msg(
            msgId: m.id,
            seqno: m.seqno,
            bytes: 0,
            body: method,
          ),
          Msg(
            msgId: ack.id,
            seqno: ack.seqno,
            bytes: 0,
            body: ackMsg,
          )
        ],
      );
      void nop(TlObject o) {}
      nop(container);
    }
    _pending[m.id] = completer;
    _pendingMethods[m.id] = method;
    final buffer = session.authorizationKey!.id == 0
        ? _encodeNoAuth(method, m)
        : _encodeWithAuth(method, m, _sessionId, session.authorizationKey!);
    obfuscation.send.encryptDecrypt(buffer, buffer.length);
    await socket.send(buffer);
    return completer.future;
  }

  bool _shouldRetry(t.RpcError error, int attempts) {
    if (requestRetries == null || requestRetries! < 0) {
      return true;
    }
    if (attempts >= requestRetries!) {
      return false;
    }
    final errorMsg = error.errorMessage.toUpperCase();
    return errorMsg.contains('SERVER_ERROR') ||
        errorMsg.contains('RPC_CALL_FAIL') ||
        errorMsg.contains('FLOOD_WAIT');
  }

  bool _shouldRetryException(Object exception, int attempts) {
    if (requestRetries == null || requestRetries! < 0) {
      return true;
    }
    if (attempts >= requestRetries!) {
      return false;
    }
    return exception is TimeoutException ||
        exception is SocketException ||
        exception is IOException;
  }

  Future<void> close() async {
    _connected = false;
    await _updateSubscription?.cancel();
    _updateSubscription = null;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          Exception('Client closed'),
        );
      }
    }
    _pending.clear();
    _pendingMethods.clear();
    for (final dcClient in _dcClients.values) {
      try {
        await dcClient.close();
      } catch (_) {}
    }
    _dcClients.clear();
    try {
      await socket.socket.close();
    } catch (_) {}
  }
}
