import 'dart:async';

import 'package:dslink_vapix/src/client.dart';
import 'package:dslink_vapix/src/soap_message.dart' as soap;
import 'package:dslink_vapix/models.dart';


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
  var body = await cl.getEventInstances();
  for (var el in body.sources) {
    print(el.type);
    print(el.name);
    print(el.channel);
    print(el.value);
  }
//  var added = await cl.addMotion({
//    _name: 'Remote Test',
//    _top: 0,
//    _left: 0,
//    _bot: 500,
//    _right: 500,
//    _hist: 90,
//    _objSize: 40,
//    _sense: 55,
//    _imgSrc: 0,
//    _winType: 'include'
//  });
//  print('Added: $added');

  body = await cl.getActionRules();
  for (var rule in body) {
    print('Rule: ${rule.name} (${rule.id})');
    print('Enabled: ${rule.enabled}');
    print('PrimaryAction: ${rule.primaryAction}');
    print('Conditions:');
    for(var c in rule.conditions) {
      print('\tTopic: ${c.topic}');
      print('\tMsg: ${c.message}');
    }
    print('\n\n');
  }

  body = await cl.getActionConfigs();
  for (var config in body) {
    print('Config: ${config.name} (${config.id})');
    print('Template: ${config.template}');
    print('Params:');
    for (var p in config.params) {
      print('\t${p.name}: ${p.value}');
    }
    print('\n\n');
  }

//  var testConfig = new ActionConfig('Add Remote', '-1', 'com.axis.action.unlimited.notification.tcp');
//  testConfig.params..add(new ConfigParams('message', 'Remote Magic'))
//      ..add(new ConfigParams('host', '10.0.1.234'))
//      ..add(new ConfigParams('port', '8888'))
//      ..add(new ConfigParams('qos', '0'))
//      ..add(new ConfigParams('period', '1'));
//
//  print(soap.addActionConfig(testConfig));

//  var body = await cl.addActionConfig(testConfig);
//  print(body);

//  var testRule = new ActionRule('-1', 'Matt Rules', true, '9');
//  testRule.conditions.add(new Condition('tns1:VideoAnalytics/tnsaxis:MotionDetection',
//      'boolean(//SimpleItem[@Name="window" and @Value="1"]) and boolean(//SimpleItem[@Name="motion" and @Value="1"])'));
//
//  print(soap.addActionRule(testRule));
//
//  var body = await cl.addActionRule(testRule);
//  print(body);
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
