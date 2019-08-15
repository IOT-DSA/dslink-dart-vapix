import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:dslink/utils.dart' show logger;

class Server {
  final String bindIp;
  final int port;
  bool get running => _running;
  Stream<String> get notices => _notices.stream;

  ServerSocket _svr;
  StreamController<String> _notices;
  bool _running = false;

  Server([this.bindIp = '0.0.0.0', this.port = 4444]);

  Future<bool> start() async {
    logger.info('Starting Notification Server on IP: $bindIp, port: $port');

    try {
      _svr = await ServerSocket.bind(bindIp, port);
    } catch (e) {
      logger.warning('Error running notification server.', e);
      _running = false;
      return _running;
    }

    _running = true;
    _notices = new StreamController<String>();
    _svr.listen((sock) {
      var addr = sock.address.address;
      sock.transform(UTF8.decoder).listen((String str) {
        str = str.trim();
        logger.finest('Socket received string: $str from $addr');
        _notices.add(str);
      }, onError: (err) {
        logger.warning('Socket received error', err);
        _notices.addError(err);
      }, onDone: () {
        sock?.close();
      });
    });

    return _running;
  }

  Future<Null> close() async {
    logger.info('Closing Notification Server');
    _running = false;
    await _notices.close();
    return _svr?.close()?.then((_) => null);
  }
}
