import 'dart:async';
import 'dart:io';

import 'package:dslink/dslink.dart' show LinkProvider;
import 'package:dslink/nodes.dart' show NodeNamer;

import 'common.dart';
import '../models/events_alerts.dart';
import '../soap_message.dart' as soap;

//* @Node events
//* @Parent DeviceNode
//* @Is eventsNode
//*
//* Collection of event related nodes for the device.
class EventsNode extends ChildNode implements Events {
  static const String _motionEvt = r'$$ax_motionEvt';
  static const String _actRule = r'$$ax_rule';
  static const String _actConf  = r'$$ax_actions';

  static const String isType = 'eventsNode';
  static const String pathName = 'events';
  static const String instances = 'instances';
  static const String sources = 'sources';
  static const String _data = 'data';
  static const String _alarms = 'alarms';
  static const String rulesNd = 'rules';
  static const String actionsNd = 'actions';

  static Map<String, dynamic> definition() => {
    r'$is': isType,
    //* @Node instances
    //* @Parent events
    //*
    //* Collection of event instances.
    //*
    //* event instances are the monitored areas that generate the alarms. Eg:
    //* a motion detection window.
    instances: {
      //* @Node sources
      //* @Parent instances
      //*
      //* Motion detection windows as identified by the event system.
      sources: {},
      //* @Node data
      //* @Parent instances
      //*
      //* Data sources. This should only be motion detection event.
      _data: {}
    },
    //* @Node alarms
    //* @Parent events
    //*
    //* Collection of alarm configurations. Includes trigger rules, and action
    //* to perform when triggered.
    _alarms: {
      //* @Node rules
      //* @Parent alarms
      //*
      //* Collection of rules that define when an action should be triggered.
      rulesNd: {
        AddActionRule.pathName: AddActionRule.definition(),
        AddVirtualRule.pathName: AddVirtualRule.def()
      },
      //* @Node actions
      //* @Parent alarms
      //*
      //* Collection of actions that define what happen when an event is
      //* triggered.
      actionsNd: {
        AddActionConfig.pathName: AddActionConfig.definition()
      }
    },
    RefreshEvents.pathName: RefreshEvents.def()
  };

  final LinkProvider _link;

  EventsNode(String path, this._link) : super(path);

  MotionEvents events;
  List<ActionConfig> actionConfigs;
  List<ActionRule> actionRules;

  void onCreated() {
    var me = getConfig(_motionEvt);
    var ar = getConfig(_actRule);
    var ac = getConfig(_actConf);

    if (me != null) {
      events = new MotionEvents.fromJson(me);
      _addInstances(events);
    }

    if (ar != null) {
      actionRules = new List<ActionRule>();
      for (var r in ar) {
        actionRules.add(new ActionRule.fromJson(r));
      }
      _addActionRules(actionRules);
    }

    if (ac != null) {
      actionConfigs = new List<ActionConfig>();
      for (var c in ac) {
        actionConfigs.add(new ActionConfig.fromJson(c));
      }
      _addActionConfigs(actionConfigs);
    }

    // (node has been moved, remove old one if it exist)
    var nd = provider.getNode('$path/$_alarms/${RefreshEvents.pathName}') as RefreshEvents;
    if (nd != null) nd.remove();
    // And put in the correct location.
    nd = provider.getNode('$path/${RefreshEvents.pathName}') as RefreshEvents;
    if (nd == null) {
      provider.addNode('$path/${RefreshEvents.pathName}', RefreshEvents.def());
    }

    nd = provider.getNode('$path/$_alarms/$rulesNd/${AddVirtualRule.pathName}');
    if (nd == null) {
      provider.addNode('$path/$_alarms/$rulesNd/${AddVirtualRule.pathName}',
          AddVirtualRule.def());
    }
  }

  /// Update children events and actions.
  Future<Null> updateEvents() async {
    var cl = await getClient();
    if (cl == null) return;

    await Future.wait([
        cl.getEventInstances()
            .then((MotionEvents evts) {
              if (evts == null) return evts;
              events = evts;
              configs[_motionEvt] = evts.toJson();
              return evts;
            }).then(_addInstances),
        cl.getActionRules()
            .then((List<ActionRule> rules) {
              if (rules == null) return rules;
              actionRules = rules;
              configs[_actRule] = rules.map((ActionRule ar) => ar.toJson()).toList();
              return rules;
            }).then(_addActionRules),
        cl.getActionConfigs()
            .then((List<ActionConfig> cfgs) {
              if (cfgs == null) return cfgs;
              actionConfigs = cfgs;
              configs[_actConf] = cfgs.map((ActionConfig ac) => ac.toJson()).toList();
              return cfgs;
            }).then(_addActionConfigs)

    ]);
    updateList(r'$is');

    _link.save();
  }

  @override Map save() {
    var m = super.save();
    if (events != null) {
      m[_motionEvt] = events.toJson();
      m[_actRule] = actionRules?.map((ActionRule ar) => ar.toJson())?.toList();
      m[_actConf] = actionConfigs?.map((ActionConfig ac) => ac.toJson())?.toList();
    }
    return m;
  }

  void _addActionRule(ActionRule ar) {
    if (this.actionRules == null) {
      this.actionRules = new List<ActionRule>();
    }

    this.actionRules.add(ar);
    configs[_actRule] = actionRules.map((ActionRule ar) => ar.toJson()).toList();
  }

  void _addActionConfig(ActionConfig ac) {
    if (actionConfigs == null) {
      actionConfigs = new List<ActionConfig>();
    }
    actionConfigs.add(ac);
    configs[_actConf] = actionConfigs.map((ActionConfig ac) => ac.toJson()).toList();
  }

  void _addInstances(MotionEvents events) {
    if (events == null) return;

    var instNd = provider.getOrCreateNode('$path/$instances');
    if (instNd == null) {
      throw new StateError('Unable to locate instances node');
    }

    var sourcesNd = provider.getOrCreateNode('${instNd.path}/$sources');
    if (sourcesNd == null) {
      throw new StateError('Unable to locate instance sources node');
    }

    var chd = sourcesNd.children.values.toList();
    for (var c in chd) {
      if (c is EventSourceNode) RemoveNode(provider, c);
    }

    for(var src in events.sources) {
      provider.addNode('$path/$instances/$sources/${src.value}',
          EventSourceNode.definition(src));
    }
  }

  void _addActionRules(List<ActionRule> rules) {
    if (rules == null) return;

    var alarmNode = provider.getOrCreateNode('$path/$_alarms');
    if (alarmNode == null) {
      throw new StateError('Unable to locate alarm node');
    }

    var arNd = provider.getOrCreateNode('${alarmNode.path}/$rulesNd');
    if (arNd == null) {
      throw new StateError('Unable to locate rules node');
    }

    var chd = arNd.children.values.toList();
    for (var c in chd) {
      if (c is ActionRuleNode) RemoveNode(provider, c);
    }

    for(var rule in rules) {
      provider.addNode('$path/$_alarms/$rulesNd/${rule.id}',
          ActionRuleNode.definition(rule));
    }
  }

  void _addActionConfigs(List<ActionConfig> configs) {
    if (configs == null) return;

    var alarmNode = provider.getOrCreateNode('$path/$_alarms');
    if (alarmNode == null) {
      throw new StateError('Unable to locate alarm node');
    }

    var acNd = provider.getNode('$path/$_alarms/$actionsNd');
    if (acNd == null) {
      throw new StateError('Unable to locate config node');
    }

    var chd = acNd.children.values.toList();
    for (var c in chd) {
      if (c is ActionConfigNode) RemoveNode(provider, c);
    }

    for(var config in configs) {
      provider.addNode('$path/$_alarms/$actionsNd/${config.id}',
          ActionConfigNode.definition(config));
    }
  }
}

//* @Node
//* @MetaType EventSource
//* @Parent sources
//* @Is eventSourceNode
//*
//* Event Source is the motion window which can trigger an event to occur.
//*
//* Event source provdies the details about the motion window which can be
//* associated with an rule and action to form the event. The name and path
//* of the event source are the names defined within the Motion window
//* configuration. The value is the Event Source ID.
//*
//* @Value string
class EventSourceNode extends ChildNode {
  static const String isType = 'eventSourceNode';

  static const String _type = 'type';
  static const String _chan = 'channel';
  static Map<String, dynamic> definition(MotionSource source) => {
    r'$is': isType,
    r'$name': source.name,
    r'$type': 'string',
    r'?value': source.value,
    //* @Node channel
    //* @Parent EventSource
    //*
    //* Channel of the device that the event source uses.
    //*
    //* @Value string
    _chan: {
      r'$name' : 'Channel',
      r'$type' : 'string',
      r'?value' : source.channel,
    },
    //* @Node type
    //* @MetaType EventSourceType
    //* @Parent EventSource
    //*
    //* Type of event source. Should be window.
    //*
    //* @Value string
    _type: {
      r'$name' : 'Type',
      r'$type' : 'string',
      r'?value' : source.type,
    },
  };

  EventSourceNode(String path) : super(path) {
    serializable = false;
  }
}

//* @Action Add_Action
//* @Is addActionConfig
//* @Parent actions
//*
//* Adds an action to the device.
//*
//* Add Action accepts an Alert name, message and remote TCP Server
//* configuration and adds it to the Axis Camera. The only supported action
//* is to send a message to remote TCP Server, generally the IP of the DSLink.
//* On success, the action will add the ActionConfig to the alarms > action node
//*
//* @Param name string The name to give the action/alert to identify it
//* internally.
//* @Param message string The string to send to the TCP server when the action
//* is triggered.
//* @Param continuousAlert bool If the alert should continuously send
//* notifications while something is detected. False means that only the first
//* notification would be sent when detected.
//* @Param ipAddress string IP Address of the remote TCP Server.
//* @Param port number Port that the remote TCP server is running on.
//*
//* @Return values
//* @Column success bool Success returns true on success. False on failure.
//* @Column message string Message returns Success! on success, otherwise
//* it provides an error message.
class AddActionConfig extends ChildNode {
  static const String isType = 'addActionConfig';
  static const String pathName = 'Add_Action';

  static const String _name = 'name';
  static const String _continuous = 'continuousAlert';
  static const String _ipAddr = 'ipAddress';
  static const String _port = 'port';
  static const String _qos = 'qos';
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
      {'name': _port, 'type': 'number', 'editor': 'int', 'default': 4444},
      {'name': _qos, 'type': 'number', 'editor': 'int', 'default': 0, 'min': 0, 'max': 63}
    ],
    r'$columns' : [
      { 'name' : _success, 'type' : 'bool', 'default' : false },
      { 'name' : _message, 'type' : 'string', 'default': '' }
    ]
  };

  LinkProvider _link;

  AddActionConfig(String path, this._link) : super(path);

  @override
  void onCreated() {
    var p = configs[r'$params'];
    if(p is List) {
      bool found = false;

      for(var i = p.length - 1; i > 0; i--) {
        var el = p[i];
        if (el['name'] == _qos) {
          found = true;
          break;
        }
      }

      if (!found) {
        p.add({'name': _qos, 'type': 'number', 'editor': 'int', 'default': 0, 'min': 0, 'max': 63});
        configs[r'$params'] = p;
      }
    }
  }

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false, _message: '' };

    var name = (params[_name] as String)?.trim();
    if (name == null || name.isEmpty) {
      return ret..[_message] = 'Name cannot be empty';
    }

    var msg = (params[_message] as String)?.trim();
    if (msg == null || msg.isEmpty) {
      return ret..[_message] = 'Message cannot be empty';
    }

    var cont = params[_continuous] as bool;
    var tok = cont ? ActionConfig.continuous : ActionConfig.fixed;
    var ipStr = (params[_ipAddr] as String)?.trim();
    if (ipStr == null || ipStr.isEmpty) {
      return ret..[_message] = 'Ip Address cannot be empty';
    }

    var q = (params[_qos] as num)?.toInt();
    if (q == null) q = 0;

    try {
      new InternetAddress(ipStr);
    } catch (e) {
      return ret..[_message] = 'Unable to parse IP Address: $e';
    }

    var port = (params[_port] as num)?.toInt();
    var cfg = new ActionConfig(name, '-1', tok);

    cfg.params
        ..add(new ConfigParams(ConfigParams.Message, msg))
        ..add(new ConfigParams(ConfigParams.Host, ipStr))
        ..add(new ConfigParams(ConfigParams.Port, '$port'))
        ..add(new ConfigParams(ConfigParams.Qos, '$q'));

    if (cont) {
      cfg.params.add(new ConfigParams(ConfigParams.Period, '1'));
    }

    var cl = await getClient();

    var res = await cl.addActionConfig(cfg);
    if (res == null || res.isEmpty) {
      return ret..[_message] = 'Unable to add action';
    } else {
      ret[_success] = true;
      ret[_message] = 'Success!';
    }

    cfg.id = res;
    provider.addNode('${parent.path}/$res', ActionConfigNode.definition(cfg));
    var evntNd = provider.getNode(parent.parent.path) as EventsNode; // Events node
    if (evntNd != null) {
      evntNd._addActionConfig(cfg);
    }
    _link.save();

    return ret;
  }
}

class AddVirtualRule extends ChildNode {
  static const String isType = 'addVirtualRule';
  static const String pathName = 'Add_Virtual_Rule';

  static const String _name = 'name';
  static const String _enabled = 'enabled';
  static const String _port = 'port';
  static const String _action = 'actionId';
  static const String _success = 'success';

  static Map<String, dynamic> def() => {
    r'$is': isType,
    r'$name': 'Add Virtual Rule',
    r'$invokable': 'write',
    r'$params': [
      {'name': _name, 'type': 'string', 'placeholder': 'Rule name'},
      {'name': _enabled, 'type': 'bool', 'default': true},
      {'name': _port, 'type': 'number', 'editor': 'int', 'min': 1, 'max': 32},
      {'name': _action, 'type': 'number', 'editor': 'int', 'default': 0}
    ],
    r'$columns': [
      {'name': _success, 'type': 'bool', 'default': false}
    ]
  };

  final LinkProvider _link;
  AddVirtualRule(String path, this._link): super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: true };

    var name = (params[_name] as String)?.trim();
    if (name == null || name.isEmpty) {
      throw new ArgumentError('"$_name" cannot be empty.');
    }

    var cl = await getClient();
    var rules = cl.getRules();
    var exist = rules.firstWhere((ar) =>
    ar.name.toLowerCase() == name.toLowerCase(), orElse: () => null);
    if (exist != null) {
      throw new ArgumentError('A rule with "$name" already exists');
    }

    var enable = params[_enabled] as bool;
    var port = (params[_port] as num)?.toInt();

    if (port == null || port <= 0 || port > 32) {
      throw new ArgumentError('$_port must be between 1 and 32');
    }

    var action = (params[_action] as num)?.toInt();
    var allConfs = cl.getConfigs();
    var act = allConfs.firstWhere((ac) => ac.id == '$action',
        orElse: () => null);
    if (act == null) {
      throw new ArgumentError('Unable to find an action with ID: $action');
    }

    var rule = new ActionRule('-1', name, enable, '$action');
    rule.conditions.add(new Condition(soap.virtualInput(),
        soap.viCondition('$port')));
    var res = await cl.addActionRule(rule, act, true);

    if (res == null || res.isEmpty) {
      throw new StateError('Unable to add Action Rule');
    }

    rule.id = res;
    provider.addNode('${parent.path}/$res', ActionRuleNode.definition(rule));
    _link.save();

    return ret;
  }
}

//* @Action Add_Rule
//* @Is addActionRule
//* @Parent rules
//*
//* Adds an Action Rule to the Device.
//*
//* Add Action Rule accepts a rule name, and the ID of the Motion Window
//* (Event source) and Primary action (Action Config). This is the test of the
//* Events. When a motion occurs in the specified window, it will trigger the
//* specified Action. On Success, this command will add an ActionRule to the
//* alarms > rules node.
//*
//* @Param name string Name internally identify the rule.
//* @Param enabled bool If the rule is enabled or disabled.
//* @Param windowId number The ID (value) of the motion window (Event source)
//* that should detect the motion for the associated alert.
//* @Param actionId number The ID of the Action (Action Config) that should
//* occur when motion is detected in the Window.
//*
//* @Return values
//* @Column success bool Success returns true on success. False on failure.
//* @Column message string Message returns Success! on success, otherwise
//* it provides an error message.
class AddActionRule extends ChildNode {
  static const String isType = 'addActionRule';
  static const String pathName = 'Add_Rule';

  static const String _name = 'name';
  static const String _enabled = 'enabled';
  static const String _window = 'windowId';
  static const String _primary = 'actionId';
  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Add Rule',
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

    var name = (params[_name] as String)?.trim();
    if (name == null || name.isEmpty) {
      return ret..[_message] = 'Rule name cannot be empty';
    }

    var enable = params[_enabled] as bool;

    var window = (params[_window] as num)?.toInt();
    var cl = await getClient();

    var me = cl.getMotion();
    if (me == null || me.sources == null) {
      throw new StateError('Unable to find any motion windows');
    }

    var win = me.sources.firstWhere((event) => event.value == '$window',
        orElse: () => null);
    if (win == null) {
      throw new StateError('Unable to find a motion window with ID: $window');
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
      ret[_success] = true;
      ret[_message] = 'Success!';
    }

    rule.id = res;
    provider.addNode('${parent.path}/$res', ActionRuleNode.definition(rule));
    var evntNd = provider.getNode(parent.parent.path) as EventsNode; // Events node
    if (evntNd != null) {
      evntNd._addActionRule(rule);
    }

    _link.save();

    return ret;
  }
}

//* @Node
//* @MetaType ActionRule
//* @Is actionRuleNode
//* @Parent rules
//*
//* Action Rule as defined in the remote device.
//*
//* The configuration of the Action Rule as defined in the remote device. The
//* ActionRule has the path name of the Rule ID, the display name of the
//* internally defined name. The rule is what must be true for an event/alert
//* to trigger.
//*
//* @Value string
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
      //* @Node enabled
      //* @MetaType RuleEnabled
      //* @Parent ActionRule
      //*
      //* If the rule is enabled or not.
      //*
      //* @Value bool
      _enabled: {
        r'$name' : 'Enabled',
        r'$type' : 'bool',
        r'?value' : rule.enabled,
      },
      //* @Node primaryAction
      //* @Parent ActionRule
      //*
      //* The ID of the action to execute when the rule is met.
      //*
      //* @Value string
      _primaryAction: {
        r'$name': 'Primary Action',
        r'$type': 'string',
        r'?value': rule.primaryAction
      },
      //* @Node conditions
      //* @Parent ActionRule
      //*
      //* Collection of conditions which must be met to execute the action.
      _conditions: {},
      RemoveActionRule.pathName: RemoveActionRule.definition()
    };
    for (var i = 0; i < rule.conditions.length; i++) {
      var con = rule.conditions[i];
      //* @Node
      //* @MetaType Condition
      //* @Parent conditions
      //*
      //* A condition which contains message a topic for rule to be met.
      ret[_conditions]['$i'] = {
        //* @Node message
        //* @Parent Condition
        //*
        //* Filter expression which must be true.
        //*
        //* @Value string
        _message: {
          r'$name': 'Message',
          r'$type': 'string',
          r'?value': con.message
        },
        //* @Node topic
        //* @Parent Condition
        //*
        //* The topic expression indications which topic the message is tested
        //* against. (Should be VideoAnalytics/MotionDetection)
        //*
        //* @Value string
        _topic: {
          r'$name': 'Topic',
          r'$type': 'string',
          r'?value': con.topic
        }
      };
    }

    return ret;
  }

  ActionRuleNode(String path) : super(path) {
    serializable = false;
  }
}

//* @Action Remove_Rule
//* @Is removeActionRule
//* @Parent ActionRule
//*
//* Removes the Action Rule from the device.
//*
//* Remove Rule will request that the action rule be removed from the device.
//* This must be removed before any Action Configurations that it depends on
//* are removed.
//*
//* @Return values
//* @Column success bool Success returns true on success. False on failure.
//* @Column message string Message returns Success! on success, otherwise
//* it provides an error message.
class RemoveActionRule extends ChildNode {
  static const String isType = 'removeActionRule';
  static const String pathName = 'Remove_Rule';

  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Remove Rule',
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
      RemoveNode(provider, parent);
      _link.save();
    } else {
      ret[_message] = 'Unable to remove Action Rule ID: $id';
    }

    return ret;
  }
}

//* @Node
//* @MetaType ActionConfig
//* @Is actionConfigNode
//* @Parent actions
//*
//* Definition of an Action Config, or Event, in the remote device.
//*
//* ActionConfig is the configuration of the Action, or Event, as defined
//* in the remote device. It will have the path name of the Action Configuration
//* ID, and the display name of the Action as specified internally. The value
//* is also the action configuration ID.
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
      //* @Node template
      //* @Parent ActionConfig
      //*
      //* The template applied to this configuration. Could be fixed or unlimited.
      //*
      //* @Value string
      _template: {
        r'$name' : 'Template Token',
        r'$type' : 'string',
        r'?value' : config.template,
      },
      //* @Node parameters
      //* @Parent ActionConfig
      //*
      //* Collection of parameters specifying the configuration of the action.
      _params: {},
      RemoveActionConfig.pathName: RemoveActionConfig.definition(),
    };

    for (var p in config.params) {
      var nm = NodeNamer.createName(p.name);
      //* @Node
      //* @MetaType Parameter
      //* @Parent parameters
      //*
      //* Parameter name as path and display name, and value as the value.
      //*
      //* @Value string
      ret[_params][nm] = {
        r'$name': p.name,
        r'$type': 'string',
        r'?value': p.value
      };
    }
    return ret;
  }

  ActionConfigNode(String path) : super(path) {
    serializable = false;
  }
}

//* @Action Remove_Config
//* @Is removeActionConfig
//* @Parent ActionConfig
//*
//* Remove the Action from the remote device.
//*
//* @Return values
//* @Column success bool Success returns true on success. False on failure.
//* @Column message string Message returns Success! on success, otherwise
//* it provides an error message.
class RemoveActionConfig extends ChildNode {
  static const String isType = 'removeActionConfig';
  static const String pathName = 'Remove_Config';

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

  RemoveActionConfig(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false, _message: '' };

    var id = parent.value as String;

    var cl = await getClient();
    ret[_success] = await cl.removeActionConfig(id);

    if (ret[_success]) {
      ret[_message] = 'Success!';
      RemoveNode(provider, parent);
      _link.save();
    } else {
      ret[_message] = 'Unable to remove Action Config ID: $id';
    }

    return ret;
  }
}

class RefreshEvents extends ChildNode {
  static const String isType = 'refreshActions';
  static const String pathName = 'Refresh';

  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> def() => {
    r'$is': isType,
    r'$name': 'Refresh',
    r'$invokable': 'write',
    r'$params': [],
    r'$columns': [
      {'name': _success, 'type': 'bool', 'default': false},
      {'name': _message, 'type': 'string', 'default': ''}
    ]
  };

  final LinkProvider _link;

  RefreshEvents(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = {_success: true, _message: 'Success!'};

    var evNd = parent as EventsNode;
    await evNd.updateEvents();

    return ret;
  }

}
