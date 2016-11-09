import 'dart:async';
import 'dart:io';

import 'package:dslink/dslink.dart' show LinkProvider;
import 'package:dslink/nodes.dart' show NodeNamer;

import 'common.dart';
import '../models/events_alerts.dart';
import '../soap_message.dart' as soap;

class EventsNode extends ChildNode {
  static const String isType = 'eventsNode';
  static const String pathName = 'events';
  static const String _instances = 'instances';
  static const String _source = 'sources';
  static const String _data = 'data';
  static const String _alarms = 'alarms';
  static const String _rules = 'rules';
  static const String _actions = 'actions';

  static Map<String, dynamic> definition() => {
    r'$is': isType,
    _instances: {
      _source: {},
      _data: {}
    },
    _alarms: {
      _rules: {
        AddActionRule.pathName: AddActionRule.definition()
      },
      _actions: {
        AddActionConfig.pathName: AddActionConfig.definition()
      }
    }
  };

  EventsNode(String path) : super(path);

  void onCreated() {
    getClient().then((cl) {
      cl.getEventInstances().then(_addInstances);
      cl.getActionRules().then(_addActionRules);
      cl.getActionConfigs().then(_addActionConfigs);
    });
  }

  void _addInstances(MotionEvents events) {
    for(var src in events.sources) {
      provider.addNode('$path/$_instances/$_source/${src.value}',
          EventSourceNode.definition(src));
    }
  }

  void _addActionRules(List<ActionRule> rules) {
    for(var rule in rules) {
      provider.addNode('$path/$_alarms/$_rules/${rule.id}',
          ActionRuleNode.definition(rule));
    }
  }

  void _addActionConfigs(List<ActionConfig> configs) {
    for(var config in configs) {
      provider.addNode('$path/$_alarms/$_actions/${config.id}',
          ActionConfigNode.definition(config));
    }
  }
}

class EventSourceNode extends ChildNode {
  static const String isType = 'eventSourceNode';

  static const String _type = 'type';
  static const String _chan = 'channel';
  static Map<String, dynamic> definition(MotionSource source) => {
    r'$is': isType,
    r'$name': source.name,
    r'$type': 'string',
    r'?value': source.value,
    _chan: {
      r'$name' : 'Channel',
      r'$type' : 'string',
      r'?value' : source.channel,
    },
    _type: {
      r'$name' : 'Type',
      r'$type' : 'string',
      r'?value' : source.type,
    },
  };

  EventSourceNode(String path) : super(path);
}

class AddActionConfig extends ChildNode {
  static const String isType = 'addActionConfig';
  static const String pathName = 'Add_Action';

  static const String _name = 'name';
  static const String _continuous = 'continuousAlert';
  static const String _ipAddr = 'ipAddress';
  static const String _port = 'port';
  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Add Action',
    r'$invokable' : 'write',
    r'$params' : [
      {'name': _name, 'type': 'string', 'placeholder': 'Alert Name'},
      {'name': _message, 'type': 'string', 'placeholder': 'Alert Message'},
      {'name': _continuous, 'type': 'bool', 'default': false},
      {'name': _ipAddr, 'type': 'string', 'placeholder': '0.0.0.0'},
      {'name': _port, 'type': 'number', 'editor': 'int', 'default': 4444}
    ],
    r'$columns' : [
      { 'name' : _success, 'type' : 'bool', 'default' : false },
      { 'name' : _message, 'type' : 'string', 'default': '' }
    ]
  };

  LinkProvider _link;

  AddActionConfig(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false, _message: '' };

    var name = params[_name] as String;
    if (name == null || name.isEmpty) {
      return ret..[_message] = 'Name cannot be empty';
    }

    var msg = params[_message] as String;
    if (msg == null || msg.isEmpty) {
      return ret..[_message] = 'Message cannot be empty';
    }

    var cont = params[_continuous] as bool;
    var tok = cont ? ActionConfig.continuous : ActionConfig.fixed;
    var ipStr = params[_ipAddr] as String;
    if (ipStr == null || ipStr.isEmpty) {
      return ret..[_message] = 'Ip Address cannot be empty';
    }

    InternetAddress ip;
    try {
      ip = new InternetAddress(ipStr);
    } catch (e) {
      return ret..[_message] = 'Unable to parse IP Address: $e';
    }

    var port = (params[_port] as num)?.toInt();
    var cfg = new ActionConfig(name, '-1', tok);

    cfg.params..add(new ConfigParams(ConfigParams.Message, msg))
        ..add(new ConfigParams(ConfigParams.Host, ipStr))
        ..add(new ConfigParams(ConfigParams.Port, '$port'))
        ..add(new ConfigParams(ConfigParams.Qos, '0'));

    if (cont) {
      cfg.params.add(new ConfigParams(ConfigParams.Period, '1'));
    }

    var cl = await getClient();

    var confs = cl.getConfigs();
    var exists = confs.firstWhere((ac) =>
        ac.name.toLowerCase() == name.toLowerCase(), orElse: () => null);
    if (exists != null) {
      return ret..[_message] = 'An action with the name "$name" already exists';
    }

    var res = await cl.addActionConfig(cfg);
    if (res == null || res.isEmpty) {
      return ret..[_message] = 'Unable to add action';
    } else {
      ret[_success] = true;
      ret[_message] = 'Success!';
    }

    cfg.id = res;
    provider.addNode('${parent.path}/$res', ActionConfigNode.definition(cfg));
    _link.save();

    return ret;
  }
}

class AddActionRule extends ChildNode {
  static const String isType = 'addActionRule';
  static const String pathName = 'Add_Action';

  static const String _name = 'name';
  static const String _enabled = 'enabled';
  static const String _window = 'windowId';
  static const String _primary = 'actionId';
  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Add Action',
    r'$invokable' : 'write',
    r'$params' : [
      {'name': _name, 'type': 'string', 'placeholder': 'Rule name'},
      {'name': _enabled, 'type': 'bool', 'default': true},
      {'name': _window, 'type': 'number', 'editor': 'int', 'default': 0},
      {'name': _primary, 'type': 'number', 'editor': 'int', 'default': 0}
    ],
    r'$columns' : [
      { 'name' : _success, 'type' : 'bool', 'default' : false },
      { 'name' : _message, 'type' : 'string', 'default': '' }
    ]
  };

  LinkProvider _link;

  AddActionRule(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false, _message: '' };

    var name = params[_name] as String;
    if (name == null || name.isEmpty) {
      return ret..[_message] = 'Rule name cannot be empty';
    }

    var cl = await getClient();
    var rules = cl.getRules();
    var exist = rules.firstWhere((ar) =>
          ar.name.toLowerCase() == name.toLowerCase(), orElse: () => null);
    if (exist != null) {
      return ret..[_message] = 'A rule with the name "$name" already exists';
    }

    var enable = params[_enabled] as bool;

    var window = (params[_window] as num)?.toInt();
    var me = cl.getMotion();
    var win = me.sources.firstWhere((event) => event.value == '$window',
        orElse: () => null);
    if (win == null) {
      return ret..[_message] = 'Unable to find a window with ID: $window';
    }

    var action = (params[_primary] as num)?.toInt();
    var allConfs = cl.getConfigs();
    var act = allConfs.firstWhere((ac) => ac.id == '$action',
        orElse: () => null);
    if (act == null) {
      return ret..[_message] = 'Unable to find an action with ID: $action';
    }

    var rule = new ActionRule('-1', name, enable, '$action');
    rule.conditions.add(new Condition(soap.motion(),
        soap.condition('$window')));
    var res = await cl.addActionRule(rule, act);

    if (res == null || res.isEmpty) {
      return ret..[_message] = 'Unable to add Action Rule';
    } else {
      ret[_message] = 'Success!';
    }

    rule.id = res;
    provider.addNode('${parent.path}/$res', ActionRuleNode.definition(rule));
    _link.save();

    return ret;
  }
}


class ActionRuleNode extends ChildNode {
  static const String isType = 'actionRuleNode';

  static const String _enabled = 'enabled';
  static const String _primaryAction = 'primaryAction';
  static const String _conditions = 'conditions';
  static const String _message = 'message';
  static const String _topic = 'topic';
  static Map<String, dynamic> definition(ActionRule rule) {
    var ret = <String, dynamic>{
      r'$is': isType,
      r'$name': rule.name,
      r'$type': 'string',
      r'?value': rule.id,
      _enabled: {
        r'$name' : 'Enabled',
        r'$type' : 'bool',
        r'?value' : rule.enabled,
      },
      _primaryAction: {
        r'$name': 'Primary Action',
        r'$type': 'string',
        r'?value': rule.primaryAction
      },
      _conditions: {},
      RemoveActionRule.pathName: RemoveActionRule.definition()
    };
    for (var i = 0; i < rule.conditions.length; i++) {
      var con = rule.conditions[i];
      ret[_conditions]['$i'] = {
        _message: {
          r'$name': 'Message',
          r'$type': 'string',
          r'?value': con.message
        },
        _topic: {
          r'$name': 'Topic',
          r'$type': 'string',
          r'?value': con.topic
        }
      };
    }

    return ret;
  }

  ActionRuleNode(String path) : super(path);
}

class RemoveActionRule extends ChildNode {
  static const String isType = 'removeActionRule';
  static const String pathName = 'Remove_Action';

  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Remove Action',
    r'$invokable' : 'write',
    r'$params' : [],
    r'$columns' : [
      { 'name' : _success, 'type' : 'bool', 'default' : false },
      { 'name' : _message, 'type' : 'string', 'default': '' }
    ]
  };

  LinkProvider _link;

  RemoveActionRule(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false, _message: '' };

    var id = parent.value as String;
    var cl = await getClient();

    ret[_success] = await cl.removeActionRule(id);
    if (ret[_success]) {
      ret[_message] = 'Success!';
      parent.remove();
      _link.save();
    } else {
      ret[_message] = 'Unable to remove Action Rule ID: $id';
    }

    return ret;
  }
}

class ActionConfigNode extends ChildNode {
  static const String isType = 'actionConfigNode';

  static const String _template = 'template';
  static const String _params = 'parameters';
  static Map<String, dynamic> definition(ActionConfig config) {
    var ret = <String, dynamic>{
      r'$is': isType,
      r'$name': config.name,
      r'$type': 'string',
      r'?value': config.id,
      _template: {
        r'$name' : 'Template Token',
        r'$type' : 'string',
        r'?value' : config.template,
      },
      _params: {},
      RemoveActionConfig.pathName: RemoveActionConfig.definition(),
    };

    for (var p in config.params) {
      var nm = NodeNamer.createName(p.name);
      ret[_params][nm] = {
        r'$name': p.name,
        r'$type': 'string',
        r'?value': p.value
      };
    }
    return ret;
  }

  ActionConfigNode(String path) : super(path);
}

class RemoveActionConfig extends ChildNode {
  static const String isType = 'removeActionConfig';
  static const String pathName = 'Remove_Config';

  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Remove Config',
    r'$invokable' : 'write',
    r'$params' : [],
    r'$columns' : [
      { 'name' : _success, 'type' : 'bool', 'default' : false },
      { 'name' : _message, 'type' : 'string', 'default': '' }
    ]
  };

  LinkProvider _link;

  RemoveActionConfig(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false, _message: '' };

    var id = parent.value as String;

    var cl = await getClient();
    ret[_success] = await cl.removeActionConfig(id);

    if (ret[_success]) {
      ret[_message] = 'Success!';
      parent.remove();
      _link.save();
    } else {
      ret[_message] = 'Unable to remove Action Config ID: $id';
    }

    return ret;
  }
}
