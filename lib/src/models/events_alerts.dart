import 'package:xml/xml.dart' as xml;

class MotionEvents {
  List<MotionSource> sources;
  List<MotionData> data;

  MotionEvents(xml.XmlElement el) {
    var si = el.findAllElements('aev:SourceInstance')?.first;
    sources = new List<MotionSource>();
    for (var child in si.children) {
      var type = child.attributes.firstWhere(_matchNiceName)?.value;
      for (var c in child.children) {
        var nm = c.attributes.firstWhere(_matchNiceName, orElse: () => null)?.value;
        var ch = c.attributes.firstWhere(_matchUserStr, orElse: () => null)?.value;
        var val = c.text;
        sources.add(new MotionSource(type, nm, ch, val));
      }
    }

    data = new List<MotionData>();
    var dt = el.findAllElements('aev:DataInstance')?.first;
    for (var d in dt.children) {
      var name = d.attributes.firstWhere(_matchNiceName)?.value;
      data.add(new MotionData(name));
    }
  }

  MotionEvents.fromJson(Map<String, dynamic> map) {
    sources = new List<MotionSource>();
    for (var s in map['sources']) {
      sources.add(new MotionSource.fromJson(s));
    }

    data = (map['data'] as List<String>)
        .map((String s) => new MotionData(s))
        .toList();
  }

  Map<String, List> toJson() => {
    'sources': sources.map((MotionSource s) => s.toJson()).toList(),
    'data': data.map((MotionData d) => d.name).toList()
  };

  bool _matchNiceName(xml.XmlAttribute xa) => xa.name.local == 'NiceName';
  bool _matchUserStr(xml.XmlAttribute xa) => xa.name.local == 'UserString';
}

class MotionSource {
  String type;
  String name;
  String channel;
  String value;
  MotionSource(this.type, this.name, this.channel, this.value);
  MotionSource.fromJson(Map<String, String> map) {
    type = map['type'];
    name = map['name'];
    channel = map['channel'];
    value = map['value'];
  }

  Map<String,String> toJson() => {
    'type': type,
    'name': name,
    'channel': channel,
    'value': value
  };
}

class MotionData {
  String name;
  MotionData(this.name);
}

class ActionRule {
  String id;
  String name;
  bool enabled;
  String primaryAction; // Maps to ActionConfig
  String windowId;
  List<Condition> conditions;

  ActionRule(this.id, this.name, this.enabled, this.primaryAction) {
    conditions = new List<Condition>();
  }

  ActionRule.fromJson(Map<String, dynamic> map) {
    id = map['id'];
    name = map['name'];
    enabled = map['enabled'];
    primaryAction = map['primary'];
    windowId = map['windowId'];
    conditions = new List<Condition>();
    for (var c in (map['conditions'] as List<Map<String,String>>)) {
      conditions.add(new Condition(c['topic'], c['message']));
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'enabled': enabled,
    'primary': primaryAction,
    'windowId': windowId,
    'conditions': conditions.map((Condition c) => c.toJson())
  };
}

class Condition {
  String topic;
  String message;
  Condition(this.topic, this.message);

  Map<String, String> toJson() => {
    'topic': topic,
    'message': message
  };
}

class ActionConfig {
  static const String continuous = 'com.axis.action.unlimited.notification.tcp';
  static const String fixed = 'com.axis.action.fixed.notification.tcp';
  String id;
  String name;
  String template;
  List<ConfigParams> params;

  ActionConfig(this.name, this.id, this.template) {
    params = new List<ConfigParams>();
  }

  factory ActionConfig.fromJson(Map<String, dynamic> map) {
    var ac = new ActionConfig(map['name'], map['id'], map['template']);
    for (var p in (map['params'] as List<Map<String, String>>)) {
      ac.params.add(new ConfigParams(p['name'], p['value']));
    }
    return ac;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'template': template,
    'params': params.map((ConfigParams cp) => cp.toJson()).toList()
  };
}

class ConfigParams {
  static const String Message = 'message';
  static const String Host = 'host';
  static const String Port = 'port';
  static const String Qos = 'qos';
  static const String Period = 'period';
  String name;
  String value;
  ConfigParams(this.name, this.value);

  Map<String, String> toJson() => {
    'name': name,
    'value': value
  };
}
