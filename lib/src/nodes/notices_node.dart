import 'package:dslink/dslink.dart';
import 'package:dslink/nodes.dart' show NodeNamer;

import '../server.dart';

class NoticeNode extends SimpleNode {
  static const String isType = 'noticeNode';
  static const String pathName = 'Notices';

  static const String _bindIp = 'bindIp';
  static const String _port = 'port';
  static const String _config = 'config';

  static Map<String, dynamic> definition() => {
    r'$is': isType,
    _config: {
      r'$name': 'Server Config',
      _bindIp : {
        r'$name': 'Bind IP',
        r'$type': 'string',
        r'?value': '0.0.0.0',
        r'$writable': 'write'
      },
      _port: {
        r'$name': 'Port number',
        r'$type': 'number',
        r'$editor': 'int',
        r'?value': 4444,
        r'$writable': 'write'
      }
    }
  };

  Server _server;
  String _ip;
  int _pt;

  final LinkProvider _link;

  NoticeNode(String path, this._link) : super(path);

  @override
  void onCreated() {
    var bindNd = provider.getNode('${path}/$_config/$_bindIp');
    var portNd = provider.getNode('${path}/$_config/$_port');
    _ip = bindNd.value as String;
    _pt = (portNd.value as num).toInt();
    bindNd.subscribe((ValueUpdate update) => updateServer(update, false));
    portNd.subscribe((ValueUpdate update) => updateServer(update, true));

    _server = new Server(_ip, _pt);
    _server.start();
    _server.notices.listen(receiveNotice);
  }

  void updateServer(ValueUpdate update, bool isPort) {
    if (isPort) {
      _pt = (update.value as num).toInt();
    } else {
      _ip = update.value as String;
    }

    _server?.close()?.then((_) {
      _server = new Server(_ip, _pt);
      _server.start();
      _server.notices.listen(receiveNotice);
    });
    _link.save();
  }

  void receiveNotice(String str) {
    var ndName = NodeNamer.createName(str.trim());
    var nd = provider.getNode('$path/$ndName') as NotificationNode;
    if (nd == null) {
      nd = provider.addNode('$path/$ndName', NotificationNode.definition())
          as NotificationNode;
    }
    nd.increment();
  }
}

class NotificationNode extends SimpleNode {
  static const String isType = 'notificationNode';
  static Map<String, dynamic> definition() => {
    r'$is': isType,
    r'$type' : 'number',
    r'?value' : 0,
    r'$writable': 'write'
  };

  int curVal;

  NotificationNode(String path): super(path);

  void increment() {
    updateValue(value + 1, force: true);
  }
}
