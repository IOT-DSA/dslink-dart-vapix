import 'dart:async';

import 'package:dslink/dslink.dart';
import 'device_nodes.dart';

class VirtualPortTrigger extends SimpleNode {
  static const String isType = 'virtualPortTrigger';
  static const String pathName = 'Virtual_Ports';

  static const String _portNum = 'port';
  static const String _state = 'state';
  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> def() => {
    r'$is': isType,
    r'$name': 'Trigger Virtual Port',
    r'$invokable': 'write',
    r'$params': [
      {'name': _portNum, 'type': 'number', 'editor': 'int', 'min': 1, 'max': 32},
      {'name': _state, 'type': 'bool[deactivate,activate]', 'default': false}
    ],
    r'$columns': [
      {'name': _success, 'type': 'bool', 'default': false},
      {'name': _message, 'type': 'string', 'default': '' }
    ]
  };

  VirtualPortTrigger(String path) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    var pNum = (params[_portNum] as num)?.toInt();
    if (pNum == null || pNum <= 0 || pNum > 32) {
      throw new ArgumentError('$_portNum must be between 1 and 32');
    }

    bool active = params[_state];
    var cl = await (parent as DeviceNode).client;
    var res = await cl.setVirtualPort(pNum, active);

    if (res) return { _success: true, _message: 'Success!' };
    return {_success: true, _message: 'Success - No state change' };
  }
}