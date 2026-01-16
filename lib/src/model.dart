import 'dart:typed_data';
import 'package:json_annotation/json_annotation.dart';
import 'package:t/t.dart';
import 'package:tg/tg.dart';

part 'model.g.dart';

class DcOptionConverter
    implements JsonConverter<DcOption?, Map<String, dynamic>?> {
  const DcOptionConverter();

  @override
  DcOption? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    return DcOption(
      ipv6: json['ipv6'] as bool? ?? false,
      mediaOnly: json['mediaOnly'] as bool? ?? false,
      tcpoOnly: json['tcpoOnly'] as bool? ?? false,
      cdn: json['cdn'] as bool? ?? false,
      static: json['static'] as bool? ?? false,
      thisPortOnly: json['thisPortOnly'] as bool? ?? false,
      id: json['id'] as int,
      ipAddress: json['ipAddress'] as String,
      port: json['port'] as int,
      secret: json['secret'] != null
          ? Uint8List.fromList((json['secret'] as List).cast<int>())
          : null,
    );
  }

  @override
  Map<String, dynamic>? toJson(DcOption? object) {
    if (object == null) return null;
    return object.toJson();
  }
}

@JsonSerializable()
class TelegramSessionSocks5Proxy {
  final String host;
  final int port;
  final String? username;
  final String? password;

  TelegramSessionSocks5Proxy({
    required this.host,
    required this.port,
    required this.username,
    required this.password,
  });

  factory TelegramSessionSocks5Proxy.fromJson(Map<String, dynamic> json) =>
      _$TelegramSessionSocks5ProxyFromJson(json);

  Map<String, dynamic> toJson() => _$TelegramSessionSocks5ProxyToJson(this);
}

enum ProxyType {
  @JsonValue('none')
  none,
  @JsonValue('socks5')
  socks5,
}

@JsonSerializable()
class ProxyConfig {
  final ProxyType type;

  ProxyConfig({required this.type});

  factory ProxyConfig.fromJson(Map<String, dynamic> json) =>
      _$ProxyConfigFromJson(json);

  Map<String, dynamic> toJson() => _$ProxyConfigToJson(this);
}

@JsonSerializable()
class Socks5ProxyConfig extends ProxyConfig {
  final String host;
  final int port;
  final String? username;
  final String? password;

  Socks5ProxyConfig({
    required this.host,
    required this.port,
    this.username,
    this.password,
  }) : super(type: ProxyType.socks5);

  factory Socks5ProxyConfig.fromJson(Map<String, dynamic> json) =>
      _$Socks5ProxyConfigFromJson(json);

  @override
  Map<String, dynamic> toJson() => _$Socks5ProxyConfigToJson(this);
}

class ProxyConfigConverter
    implements JsonConverter<ProxyConfig?, Map<String, dynamic>?> {
  const ProxyConfigConverter();

  @override
  ProxyConfig? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;

    final type = ProxyType.values.firstWhere(
          (e) => e.toString().split('.').last == json['type'],
      orElse: () => ProxyType.none,
    );
    switch (type) {
      case ProxyType.none:
        return ProxyConfig.fromJson(json);
      case ProxyType.socks5:
        return Socks5ProxyConfig.fromJson(json);
    }
  }

  @override
  Map<String, dynamic>? toJson(ProxyConfig? object) {
    return object?.toJson();
  }
}

@JsonSerializable()
class TelegramSessionDevice {
  String? deviceModel;
  String? appVersion;
  String? systemVersion;
  String? systemLangCode;
  String? langCode;

  TelegramSessionDevice({
    this.deviceModel,
    this.appVersion,
    this.systemVersion,
    this.systemLangCode,
    this.langCode,
  });

  factory TelegramSessionDevice.fromJson(Map<String, dynamic> json) =>
      _$TelegramSessionDeviceFromJson(json);

  Map<String, dynamic> toJson() => _$TelegramSessionDeviceToJson(this);
}

@JsonSerializable()
class TelegramSession {
  final ProxyConfig proxyConfig;
  @DcOptionConverter()
  DcOption? dcOption;
  AuthorizationKey? authorizationKey;
  TelegramSessionDevice? device;

  @ProxyConfigConverter()
  TelegramSession({
    required this.proxyConfig,
    this.dcOption,
    this.authorizationKey,
    this.device,
  });

  factory TelegramSession.fromJson(Map<String, dynamic> json) =>
      _$TelegramSessionFromJson(json);

  Map<String, dynamic> toJson() => _$TelegramSessionToJson(this);
}

const defaultDcOption = DcOption(
  ipv6: false,
  mediaOnly: false,
  tcpoOnly: false,
  cdn: false,
  static: false,
  thisPortOnly: false,
  id: 4,
  ipAddress: '149.154.167.92',
  port: 443,
);
