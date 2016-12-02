import 'dart:async';

import 'package:dslink/nodes.dart' show NodeNamer;

import 'common.dart';
import 'param_value.dart';

//* @Action Add_Window
//* @Parent Motion
//* @Is addWindow
//*
//* Add a motion detection window to the remote device.
//*
//* Add Window will attempt to add a motion detection window to the remote
//* device with specified size, position and sensitivity.
//*
//* @Param Name string Name to reference the motion detection window internally.
//* @Param Top number Top position of the window (between 0 and 9999)
//* @Param Left number Left position of the window (between 0 and 9999)
//* @Param Bottom number Bottom position of the window (between 0 and 9999)
//* @Param Right number Right position of the window (between 0 and 9999)
//* @Param History number History size to maintain.
//* @Param ObjectSize number Size the object must be to trigger detection.
//* @Param Sensitivity number Sensitivity of the motion detection.
//* @Param ImageSource number Id of the image source.
//* @Param WindowType enum[include,exclude] If the window detects everything
//* inside the window, or everything outside of the window.
//*
//* @Return values
//* @Column success bool Success returns true on success. False on failure.
//* @Column message string Message returns Success! on success, otherwise
//* it provides an error message.
class AddWindow extends ChildNode {
  static const String isType = 'addWindow';
  static const String pathName = 'Add_Window';

  static const String _name = 'Name';
  static const String _top = 'Top';
  static const String _left = 'Left';
  static const String _bot = 'Bottom';
  static const String _right = 'Right';
  static const String _hist = 'History';
  static const String _objSize = 'ObjectSize';
  static const String _sense = 'Sensitivity';
  static const String _imgSrc = 'ImageSource';
  static const String _winType = 'WindowType';
  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
    r'$is': isType,
    r'$name': 'Add Window',
    r'$invokable': 'write',
    r'$params': [
      {'name': _name, 'type': 'string', 'placeholder': 'Window Name'},
      {'name': _top, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 9999},
      {'name': _left, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 9999},
      {'name': _bot, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 9999},
      {'name': _right, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 9999},
      {'name': _hist, 'type': 'number', 'editor': 'int', 'min': 0},
      {'name': _objSize, 'type': 'number', 'editor': 'int', 'min': 0},
      {'name': _sense, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 100},
      {'name': _imgSrc, 'type': 'number', 'editor': 'int', 'min': 0, 'default': 0},
      {'name': _winType, 'type': 'enum[include,exclude]', 'default': 'include'}
    ],
    r'$columns': [
      { 'name': _success, 'type': 'bool', 'default': false },
      { 'name': _message, 'type': 'string', 'default': '' }
    ]
  };

  AddWindow(String path) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false, _message : '' };

    var cl = await getClient();
    var res = await cl.addMotion(params);

    ret[_success] = res != null;
    ret[_message] = ret[_success] ? 'Success!' : 'Unable to add Window';
    if (!ret[_success]) return ret;

    var nd = provider.getOrCreateNode('${parent.path}/$res');
    for (var key in params.keys) {
      var ndName = NodeNamer.createName(key);
//      var tmpNd = provider.getNode('${nd.path}/$ndName');
//      if (tmpNd == null) {
        provider.addNode('${nd.path}/$ndName',
            ParamValue.definition('${params[key]}'));
//      } else {
//        tmpNd.updateValue(params[key]);
//      }
    }

    provider.addNode('${nd.path}/${RemoveWindow.pathName}',
        RemoveWindow.definition());

    var p = parent;
    while (p != null && p is! Device) {
      p = p.parent;
    }

    if (p != null) {
      var evNode = provider.getNode('${p.path}/events');
      await (evNode as Events)?.updateEvents();
    }

    return ret;
  }
}

//* @Action Remove_Window
//* @Parent MotionWindow
//* @Is removeWindow
//*
//* Remove a motion window from the device.
//*
//* Remove a motion window from the device. This will remove the associated
//* Event source used in generating Event Actions and Rules.
//*
//* @Return values
//* @Column success bool Success returns true on success. False on failure.
//* @Column message string Message returns Success! on success, otherwise
//* it provides an error message.
class RemoveWindow extends ChildNode {
  static const String isType = 'removeWindow';
  static const String pathName = 'Remove_Window';

  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
    r'$is': isType,
    r'$name': 'Remove Window',
    r'$invokable': 'write',
    r'$params': [],
    r'$columns': [
      { 'name': _success, 'type': 'bool', 'default': false },
      { 'name': _message, 'type': 'string', 'default': '' }
    ]
  };

  RemoveWindow(String path) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false, _message : '' };

    var cl = await getClient();
    var nm = parent.name;
    ret[_success] = await cl.removeMotion(nm);

    ret[_message] = ret[_success] ? 'Success!': 'Error removing window group';

    if (ret[_success]) {
      parent.remove();
    }

    return ret;
  }
}
