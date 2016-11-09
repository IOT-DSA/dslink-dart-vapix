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
        var nm = c.attributes.firstWhere(_matchNiceName)?.value;
        var ch = c.attributes.firstWhere(_matchUserStr)?.value;
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

  bool _matchNiceName(xml.XmlAttribute xa) => xa.name.local == 'NiceName';
  bool _matchUserStr(xml.XmlAttribute xa) => xa.name.local == 'UserString';
}

class MotionSource {
  String type;
  String name;
  String channel;
  String value;
  MotionSource(this.type, this.name, this.channel, this.value);
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
}

class Condition {
  String topic;
  String message;
  Condition(this.topic, this.message);
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
}
