import 'dart:async';

import 'package:dslink/nodes.dart' show NodeNamer;
import 'package:dslink/dslink.dart' show LinkProvider;

import 'common.dart';
import 'param_value.dart';
import '../../models.dart' show Parameters;

class AddStream extends ChildNode {
  static const String isType = 'addStreamProfile';
  static const String pathName = 'Add_Stream';

  static const String _name = 'Name';
  static const String _desc = 'Description';
  static const String _res = 'resolution';
  static const String _compress = 'compression';
  static const String _rot = 'rotation';
  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> def(Parameters params) => {
    r'$is': isType,
    r'$name': 'Add Stream',
    r'$invokable': 'write',
    r'$params': [
      {'name': _name, 'type': 'string', 'placeholder': 'Stream Name'},
      {'name': _desc, 'type': 'string', 'placeholder': 'Stream descriptions'},
      {'name': _res, 'type': 'enum[${params.resolutions}]'},
      {'name': _compress, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 100, 'default': 0},
      {'name': _rot, 'type': 'enum[${params.rotations}]', 'default': '0'},
    ],
    r'$columns': [
      { 'name': _success, 'type': 'bool', 'default': false },
      { 'name': _message, 'type': 'string', 'default': '' }
    ]
  };

  final LinkProvider link;

  AddStream(String path, this.link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false, _message : '' };

    var cl = await getClient();
    if (cl == null) {
      throw new StateError('Unable to retreive client');
    }

    var streamName = notNullString(params[_name], _name);
    var imgResolution = notNullString(params[_res], _res);
    var imgParams = <String, String>{
      _res: imgResolution
    };


    var imgCompression = params[_compress];
    if (imgCompression != null && imgCompression is int && imgCompression != 0) {
      imgParams[_compress] = imgCompression.toString();
    }

    var imgRotation = params[_rot];
    if (imgRotation != null && imgRotation is String && imgRotation != '0') {
      imgParams[_rot] = imgRotation;
    }

    String paramsString = '';
    int i = 0;
    for (var k in imgParams.keys) {
      paramsString += '$k=${imgParams[k]}';
      if (i < imgParams.length - 1) {
        paramsString += '&';
      }
      i++;
    }

    var config = <String, String>{
      _name: streamName,
      'Parameters': paramsString
    };

    String description = params[_desc];
    if (description != null && description.isNotEmpty) {
      config[_desc] = description;
    }

    var res = await cl.addStreamProfile(config);
    // TODO: Continue here

    return ret;
  }
}

String notNullString(String value, String name) {
  final up = new ArgumentError.value(value, name, "should not be null or empty.");
  if (value == null) throw up;
  var clean = value.trim();
  if (clean.isEmpty) throw up;

  return clean;
}