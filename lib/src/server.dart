import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:dslink/utils.dart' show logger;

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
    logger.finest('Starting Server on IP: $bindIp, port: $port');
    ServerSocket.bind(bindIp, port).then((server) async {
      _svr = server;

      try {
        await for (var sock in _svr) {
          sock.transform(UTF8.decoder).listen((String str) {
            logger.finest('Socket received string: $str');
            _notices.add(str);
          }, onError: (err) {
            logger.warning('Socket received error', err);
            _notices.addError(err);
          }, onDone: () {
            logger.finest('Socket done');
            sock?.close();
          });
        }
      } catch (e) {
        logger.warning('Server received error', e);
      }
    });
  }

  Future<Null> close() {
    logger.info('Closing Server');
    return _svr?.close()?.then((_) => null);
  }
}
