import 'dart:async';

import 'package:dslink_vapix/src/client.dart';


const String _name = 'Name';
const String _top = 'Top';
const String _left = 'Left';
const String _bot = 'Bottom';
const String _right = 'Right';
const String _hist = 'History';
const String _objSize = 'ObjectSize';
const String _sense = 'Sensitivity';
const String _imgSrc = 'ImageSource';
const String _winType = 'WindowType';

Future<Null> main() async {
  var uri = Uri.parse('http://10.0.1.180');
  var cl = new VClient(uri, 'root', 'root');

  var res = await cl.authenticate();
  print(res);
  //var body = await cl.getEventInstances();
  //print(body);
  var added = await cl.addMotion({
    _name: 'Remote Test',
    _top: 0,
    _left: 0,
    _bot: 500,
    _right: 500,
    _hist: 90,
    _objSize: 40,
    _sense: 55,
    _imgSrc: 0,
    _winType: 'include'
  });
  print('Added: $added');
}

//
//{'name': _name, 'type': 'string', 'placeholder': 'Window Name'},
//{'name': _top, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 9999},
//{'name': _left, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 9999},
//{'name': _bot, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 9999},
//{'name': _right, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 9999},
//{'name': _hist, 'type': 'number', 'editor': 'int', 'min': 0},
//{'name': _objSize, 'type': 'number', 'editor': 'int', 'min': 0},
//{'name': _sense, 'type': 'number', 'editor': 'int', 'min': 0, 'max': 100},
//{'name': _imgSrc, 'type': 'number', 'editor': 'int', 'min': 0},
//{'name': _winType, 'type': 'enum[include,exclude]', 'default': 'include'}
