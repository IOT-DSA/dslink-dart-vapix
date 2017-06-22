import 'dart:async';

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

  ResolutionNode(String path) : super(path);
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

  RefreshResolution(String path) : super(path);

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
      if (ch is ResolutionNode) ch.remove();
    }

    var pPath = parent.path;
    for (var res in resolutions) {
      provider.addNode('$pPath/${res.camera}', ResolutionNode.def(res));
    }

    return ret
      ..[_success] = true
      ..[_message] = 'Success!';
  }
}
