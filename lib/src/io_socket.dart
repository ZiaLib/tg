import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:tg/tg.dart' as tg;

class IoSocket extends tg.SocketAbstraction {
  IoSocket(this.socket);

  final Socket socket;

  @override
  late final Stream<Uint8List> receiver = socket.asBroadcastStream();

  @override
  Future<void> send(List<int> data) async {
    socket.add(data);
    await socket.flush();
  }
}