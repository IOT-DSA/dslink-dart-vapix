import 'dart:async';
import 'dart:io';
import 'dart:convert';

class Server {
  final String bindIp;
  final int port;
  Stream<String> get notices => _notices.stream;

  ServerSocket _svr;
  StreamController<String> _notices;

  Server([this.bindIp = '0.0.0.0', this.port = 4444]) {
    _notices = new StreamController<String>();
  }

  void start() {
    ServerSocket.bind(bindIp, port).then((server) async {
      _svr = server;

      await for (var sock in _svr) {
        sock.transform(UTF8.decoder).listen((String str) {
          print('Socket received string: $str');
          _notices.add(str);
        }, onError: (err) {
          print('Received error: $err');
          _notices.addError(err);
        }, onDone: () {
          print('Socket Done');
          sock?.close();
        });
      }
    });
  }
}
