import 'package:dslink/dslink.dart';
import 'package:dslink/nodes.dart' show NodeNamer;

import 'common.dart';
import '../server.dart';

//* @Node Notices
//* @Is noticeNode
//* @Parent root
//*
//* Notice Node is a collection of notifications received by the TCP server.
//*
//* Notice Node manages the internal TCP server configuration. The TCP Server
//* receives notifications from the Axis Cameras and updates the corresponding
//* notifications.
class NoticeNode extends SimpleNode {
  static const String isType = 'noticeNode';
  static const String pathName = 'Notices';

  static const String _bindIp = 'bindIp';
  static const String _port = 'port';
  static const String _config = 'config';
  static const String _status = 'status';

  static Map<String, dynamic> definition() => {
    r'$is': isType,
    //* @Node config
    //* @Parent Notices
    //*
    //* config is a collection of Configuration values for the TCP Server.
    _config: {
      r'$name': 'Server Config',
      //* @Node bindIp
      //* @Parent config
      //*
      //* bindIp is the IP address that the TCP Server is bound to.
      //*
      //* @Value string write
      _bindIp : {
        r'$name': 'Bind IP',
        r'$type': 'string',
        r'?value': '0.0.0.0',
        r'$writable': 'write'
      },
      //* @Node port
      //* @Parent config
      //*
      //* port is the Port number that the TCP Server is bound to.
      //*
      //* @Value number write
      _port: {
        r'$name': 'Port number',
        r'$type': 'number',
        r'$editor': 'int',
        r'?value': 4444,
        r'$writable': 'write'
      },
      _status: {
        r'$name': 'Status',
        r'$type': 'bool[stopped,running]',
        r'$writable': 'write',
        r'?value': true
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
    var bindNd = provider.getNode('$path/$_config/$_bindIp');
    var portNd = provider.getNode('$path/$_config/$_port');
    var statusNd = provider.getNode('$path/$_config/$_status') as SimpleNode;
    if (statusNd == null) {
      statusNd = provider.addNode('$path/$_config/$_status', {
        r'$name': 'Status',
        r'$type': 'bool[stopped,running]',
        r'$writable': 'write',
        r'?value': true
      });
    }

    _ip = bindNd.value as String;
    _pt = (portNd.value as num).toInt();
    bindNd.subscribe((ValueUpdate update) => updateServer(update, false));
    portNd.subscribe((ValueUpdate update) => updateServer(update, true));
    statusNd.subscribe(_runningChanged);

    var running = statusNd.value as bool;

    if (running) {
      _startServer();
    }
  }

  void updateServer(ValueUpdate update, bool isPort) {
    if (isPort) {
      _pt = (update.value as num).toInt();
    } else {
      _ip = update.value as String;
    }

    if (_server.running) {
      _server?.close()?.then((_) => _startServer());
    }

    _link.save();
  }

  void receiveNotice(Notice note) {
    var ndName = NodeNamer.createName(note.msg.trim());
    var nd = provider.getNode('$path/$ndName') as NotificationNode;
    if (nd == null) {
      nd = provider.addNode('$path/$ndName', NotificationNode.def())
          as NotificationNode;
    }
    nd.attributes['@origin'] = note.origin;
    updateList('@origin');
    nd.increment();
  }

  void _runningChanged(ValueUpdate update) {
    var run = update.value as bool;
    if (!run && _server != null && _server.running) {
      _server.close();
    } else if (run) {
      if (_server == null || !_server.running) {
        _startServer();
      }
    }
    _link.save();
  }

  void _startServer() {
    if (_server == null || _server.bindIp != _ip || _server.port != _pt) {
      _server = new Server(_ip, _pt);
    }

    _server.start().then((bool running) {
      var statusNd = provider.getNode('$path/$_config/$_status') as SimpleNode;
      statusNd.updateValue(running);
      if (running) {
        _server.notices.listen(receiveNotice);
      }
    });
  }
}


//* @Node
//* @MetaType Notification
//* @Is notificationNode
//* @Parent Notices
//*
//* Notification received by the TCP Server.
//*
//* The node name and path will be the string that was received by the
//* TCP Server. The Value shows the number of times the notification has been
//* received.
//*
//* @Value number write
class NotificationNode extends SimpleNode {
  static const String isType = 'notificationNode';
  static Map<String, dynamic> def() => {
    r'$is': isType,
    r'$type' : 'number',
    r'?value' : 0,
    r'$writable': 'write',
    r'@origin': '',
    RemoveNotification.pathName: RemoveNotification.def()
  };

  int curVal;

  NotificationNode(String path): super(path);

  void increment() {
    if (value == null || value is! int) {
      updateValue(1);
    } else {
      updateValue(value + 1, force: true);
    }
  }

  @override
  void onCreated() {
    if (!children.containsKey(RemoveNotification.pathName)) {
      provider.addNode('$path/${RemoveNotification.pathName}',
        RemoveNotification.def());
    }
  }
}

class RemoveNotification extends SimpleNode {
  static const String _success = 'success';

  static const isType = 'removeNotification';
  static const pathName = 'remove_notification';
  static Map<String, dynamic> def() => {
    r'$is': isType,
    r'$name': 'Remove Notification',
    r'$invokable': 'write',
    r'$params': [],
    r'$columns': [
      {'name': _success, 'type': 'bool', 'default': false}
    ]
  };

  final LinkProvider _link;

  RemoveNotification(String path, this._link): super(path);

  @override
  Map<String, bool> onInvoke(Map<String, dynamic> params) {
    RemoveNode(provider, parent);

    _link.save();

    return {_success: true};
  }
}
