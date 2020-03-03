import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:dslink/utils.dart' show logger;

class Notice {
  final String origin;
  final String msg;
  Notice(this.origin, this.msg);
}

class Server {
  final String bindIp;
  final int port;
  bool get running => _running;
  Stream<Notice> get notices => _notices.stream;

  ServerSocket _svr;
  StreamController<Notice> _notices;
  bool _running = false;

  Server([this.bindIp = '0.0.0.0', this.port = 4444]);

  Future<bool> start() async {
    logger.info('Starting Notification Server on IP: $bindIp, port: $port');

    try {
      _svr = await ServerSocket.bind(bindIp, port);
      _svr.handleError((e) {
        logger.warning("SocketServer encountered error", e);
      });
    } catch (e) {
      logger.warning('Error running notification server.', e);
      _running = false;
      return _running;
    }

    _running = true;
    _notices = new StreamController<Notice>();
    _svr.listen(handleSocket,
        onDone: () {_running = false;},
        // Include both onError in listen and handleError to ensure nothing
        // slips by.
        onError: (e) {
          logger.warning("Socket server encountered error in listen", e);
        }, cancelOnError: false);

    return _running;
  }

  Future<Null> handleSocket(Socket sock) async {
    var addr = sock.remoteAddress.address;
    sock.transform(UTF8.decoder).listen((String str) {
      str = str.trim();
      logger.finest('Socket received string: $str from $addr');
      _notices.add(new Notice(addr, str));
    }, onError: (err) {
      logger.warning('Socket received error', err);
      _notices.addError(err);
    }, onDone: () {
      sock?.close();
    });
  }

  Future<Null> close() async {
    logger.info('Closing Notification Server');
    _running = false;
    await _notices.close();
    return _svr?.close()?.then((_) => null);
  }
}
