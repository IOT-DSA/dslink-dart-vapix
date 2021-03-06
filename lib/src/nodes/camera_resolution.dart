import 'dart:async';

import 'package:dslink/dslink.dart' show LinkProvider;

import 'common.dart';
import '../models/axis_device.dart' show CameraResolution;

class ResolutionNode extends ChildNode {
  static const String isType = 'resolutionNode';
  static const String _width = 'width';
  static const String _height = 'height';

  static Map<String, dynamic> def(CameraResolution res) => {
        r'$name': 'Camera ${res.camera}',
        r'$is': isType,
        _width: {r'$type': 'num', r'?value': res.width},
        _height: {r'$type': 'num', r'?value': res.height}
      };

  ResolutionNode(String path) : super(path) {
    serializable = false;
  }
}

class RefreshResolution extends ChildNode {
  static const String isType = 'refreshResolution';
  static const String pathName = 'refresh_resolution';

  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> def() => {
        r'$is': isType,
        r'$name': 'Refresh Resolutions',
        r'$invokable': 'write',
        r'$result': 'values',
        r'$params': [],
        r'$columns': [
          {'name': _success, 'type': 'bool', 'default': false},
          {'name': _message, 'type': 'string', 'default': ''}
        ]
      };

  final LinkProvider _link;

  RefreshResolution(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = {_success: false, _message: ''};
    var cl = await getClient();

    List<CameraResolution> resolutions;
    try {
      resolutions = await cl.getResolutions();
    } catch (e) {
      return ret..[_message] = 'Failed to update resolutions. Error: $e';
    }

    var childs = parent.children.values.toList();
    for (var ch in childs) {
      if (ch is ResolutionNode) RemoveNode(provider, ch);
    }

    var pPath = parent.path;

    var dev = await getDevice();
    dev.resolutions = resolutions;

    for (var res in resolutions) {
      provider.addNode('$pPath/${res.camera}', ResolutionNode.def(res));
    }

    _link.save();

    return ret
      ..[_success] = true
      ..[_message] = 'Success!';
  }
}
