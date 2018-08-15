import 'dart:async';

import 'common.dart';
import '../models/device_leds.dart';
import '../models/events_alerts.dart';

class SetLed extends ChildNode {
  static const String isType = 'setLed';
  static const String pathName = 'Set_Led';

  static const String _ledName = r'$ledName';
  static const String _name = 'name';
  static const String _color = 'color';
  static const String _interval = 'flashInterval';
  static const String _success = 'success';

  static Map<String, dynamic> def(Led led) {
    var colors = led.colors
        .where((Color c) => c.userControllable)
        .map((Color c) => c.name)
        .join(',');

    var ret = {
      r'$is': isType,
      r'$name': 'Set LED',
      r'$invokable': 'write',
      _ledName: led.name,
      r'$params': [
        {'name': _name, 'type': 'string', 'description': 'Name for Configuration'},
        {'name': _color, 'type': 'enum[$colors]', 'default': 'none'},
        {
          'name': _interval,
          'type': 'number',
          'editor': 'int',
          'description': 'Number of milliseconds between flashes.'
        }
      ],
      r'$columns': [
        {'name': _success, 'type': 'bool', 'default': false}
      ]
    };

    return ret;
  }

  String _led;

  SetLed(String path): super(path);

  void onCreated() {
    _led = getConfig(_ledName);
  }

  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false };

    var name = (params[_name] as String)?.trim();
    if (name == null || name.isEmpty) {
      throw new ArgumentError('"name" cannot be empty');
    }

    String color = params[_color];
    if (color == null || color.isEmpty) {
      throw new ArgumentError("Color parameter cannot be empty");
    }

    int interval = (params[_interval] as num)?.toInt() ?? 0;
    var ac = new ActionConfig(name, null, 'com.axis.action.unlimited.ledcontrol');
    ac.params..add(new ConfigParams('led', _led))
      ..add(new ConfigParams('color', color))
      ..add(new ConfigParams('interval', '$interval'));

    var cl = await getClient();
    var res = await cl.setLedColor(ac);
    // TODO: Add action config if I get success?
  }
}