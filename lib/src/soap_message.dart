import 'models/events_alerts.dart';

/// Header SOAPAction for Get Action Rules
const String headerGAR =
    r'http://www.axis.com/vapix/ws/action1/GetActionRules';
/// Header SOAPAction for Remove Action Rules
const String headerRAR =
    r'http://www.axis.com/vapix/ws/action1/RemoveActionRule';
/// Header SOAPAction for Add Action Rules
const String headerAAR =
    r'http://www.axis.com/vapix/ws/action1/AddActionRule';
/// Header SOAPAction for Get Action Configurations
const String headerGAC =
    r'http://www.axis.com/vapix/ws/action1/GetActionConfigurations';
/// Header SOAPAction for Remove Action Configurations
const String headerRAC =
    r'http://www.axis.com/vapix/ws/action1/RemoveActionConfiguration';
/// Header SOAPAction for Add Action Configurations
const String headerAAC =
    r'http://www.axis.com/vapix/ws/action1/AddActionConfiguration';
/// Header SOAPAction for Get Event Instances
const String headerGEI =
    r'http://www.axis.com/vapix/ws/event1/GetEventInstances';

const String _event1 = r'xmlns:aev="http://www.axis.com/vapix/ws/event1"';
const String _action1 = r'xmlns:aa="http://www.axis.com/vapix/ws/action1"';


String header(String template, String request) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" $template xmlns:tns1="http://www.onvif.org/ver10/topics" xmlns:tnsaxis="http://www.axis.com/2009/event/topics" xmlns:wsnt="http://docs.oasis-open.org/wsn/b-2" xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Body>
    $request
  </soap:Body>
</soap:Envelope>
''';

/// Generate SOAP Envelope to Get Event Instances
String getEventInstances() => header(_event1,
    '<aev:GetEventInstances xmlns="$_event1"></aev:GetEventInstances>');

/// Generate SOAP Envelop to Get Action Configurations
String getActionConfigs() => header(_action1,
    '<aa:GetActionConfigurations xmlns="$_action1"></aa:GetActionConfigurations>');

/// Generate SOAP Envelop to Remove Action Configurations
String removeActionConfigs(String id) => header(_action1,
    '''<aa:RemoveActionConfiguration xmlns="$_action1">
      <ConfigurationID>$id</ConfigurationID>
    </aa:RemoveActionConfiguration>''');

/// Generate SOAP Evelop to Add Action Configuration
String addActionConfig(ActionConfig ac) {
  var body = '''<aa:AddActionConfiguration xmlns="$_action1">
    <NewActionConfiguration>
      <TemplateToken>${ac.template}</TemplateToken>
      <Name>${ac.name}</Name>
      <Parameters>
  ''';

  for (var p in ac.params) {
    body += '<Parameter Name="${p.name}" Value="${p.value}"></Parameter>\n';
  }

  body += '''</Parameters>
    </NewActionConfiguration>
  </aa:AddActionConfiguration>''';

  return header(_action1, body);
}

/// Generate SOAP Envelop to Get Action Rule
String getActionRules() => header(_action1,
    '<aa:GetActionRules xmlns="$_action1"></aa:GetActionRules>');

/// Generate SOAP Envelop to Remove Action Rules
String removeActionRule(String id) => header(_action1,
    '''<aa:RemoveActionRule xmlns="$_action1">
      <RuleId>$id</RuleId>
    </aa:RemoveActionRule>''');

/// Generate SOAP Envelop to Add Action Rule
String addActionRule(ActionRule ar) {
  String body = '''<aa:AddActionRule xmlns="$_action1">
      <NewActionRule>
        <Name>${ar.name}</Name>
        <Enabled>${ar.enabled}</Enabled>
        <StartEvent>
  ''';
  for (var c in ar.conditions) {
    body += '<wsnt:TopicExpression Dialect="http://www.onvif.org/ver10/tev/topicExpression/ConcreteSet">${c.topic}</wsnt:TopicExpression>\n';
    body += '<wsnt:MessageContent Dialect="http://www.onvif.org/ver10/tev/messageContentFilter/ItemFilter">${c.message}</wsnt:MessageContent>\n';
  }
  body += '''</StartEvent>
      <PrimaryAction>${ar.primaryAction}</PrimaryAction>
    </NewActionRule>
  </aa:AddActionRule>''';

  return header(_action1, body);
}
