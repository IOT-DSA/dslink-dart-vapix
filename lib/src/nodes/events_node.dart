import 'package:dslink/nodes.dart' show NodeNamer;

import 'common.dart';
import '../models/events_alerts.dart';

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
      _rules: {},
      _actions: {}
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
      _conditions: {}
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
      _params: {}
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
