import 'dart:async';

import 'package:dslink/dslink.dart';

import '../../models.dart';
import '../client.dart' show VClient;

abstract class Device {
  Future<AxisDevice> get device;
  Future<VClient> get client;
  void setDevice(AxisDevice dev);
}

abstract class Events {
  Future<Null> updateEvents();
}

abstract class ChildNode extends SimpleNode  {
  ChildNode(String path) : super(path);

  Device _getDev() {
    var p = parent;
    while(p != null && p is! Device) {
      p = p.parent;
    }

    return p as Device;
  }

  Future<AxisDevice> getDevice() => _getDev()?.device;
  Future<VClient> getClient() => _getDev()?.client;

  String _discoTs;
  String get disconnected => _discoTs;
  void set disconnected(String val) {
    _discoTs = val;
    updateList(r'$disconnectedTs');
  }
}

void CheckNode(SimpleNodeProvider provider, String path, Map<String, dynamic> map) {
  var nd = provider.getNode(path);
  if (nd != null) return;

  provider.addNode(path, map);
}

void RemoveNode(SimpleNodeProvider provider, SimpleNode node) {
  if (node == null || provider == null) return;

  var childs = node.children.keys.toList();
  for (var cPath in childs) {
    RemoveNode(provider, provider.getNode(node.path + '/$cPath'));
  }

  provider.removeNode(node.path, recurse: false);
}