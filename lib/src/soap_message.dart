import 'models/events_alerts.dart';

/// Header SOAPAction for Get Action Templates
const String headerGAT =
    r'http://www.axis.com/vapix/ws/action1/GetActionTemplates';
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
/// Header SOAPAction for Get Light Service Capabilities
const String headerGSC =
    r'http://www.axis.com/vapix/ws/light/GetServiceCapabilities';
/// Header SOAPAction for Get Light Information
const String headerGLI =
    r'http://www.axis.com/vapix/ws/light/GetLightInformation';

const String _action1 = r'xmlns:aa="http://www.axis.com/vapix/ws/action1"';
const String _actionNoNS = r'xmlns="http://www.axis.com/vapix/ws/action1"';
const String _event1 = r'xmlns:aev="http://www.axis.com/vapix/ws/event1"';
const String _eventNoNS = r'xmlns="http://www.axis.com/vapix/ws/event1"';
const String _light = r'xmlns:ali="http://www.axis.com/vapix/ws/light"';
const String _lightNoNs = r'xmlns="http://www.axis.com/vapix/ws/light"';

/// Used for ActionRules for conditions, specifies motion detection
String motion() => r'tns1:VideoAnalytics/tnsaxis:MotionDetection';
/// Used for ActionRules for conditions, specifies which Window detects the
/// motion.
String condition(String windowId) => 'boolean(//SimpleItem[@Name="window" and '
    '@Value="$windowId"]) and boolean(//SimpleItem[@Name="motion" and '
    '@Value="1"])';
/// Used for ActionRules for conditions, specifies Virtual Input trigger
String virtualInput() => r'tns1:Device/tnsaxis:IO/tnsaxis:VirtualInput';
/// Used for ActionRules for conditions, specifies which port number is activated
String viCondition(String port) => 'boolean(//SimpleItem[@Name="port" and '
    '@Value="$port"]) and boolean(//SimpleItem[@Name="active" and @Value="1"])';

String header(String template, String request) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" $template xmlns:tns1="http://www.onvif.org/ver10/topics" xmlns:tnsaxis="http://www.axis.com/2009/event/topics" xmlns:wsnt="http://docs.oasis-open.org/wsn/b-2" xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Body>
    $request
  </soap:Body>
</soap:Envelope>
''';

/// Generate SOAP Envelope to Get Action Templates
String getActionTemplates() => header(_action1,
  '<aa:GetActionTemplates $_actionNoNS></aa:GetActionTemplates>');

/// Generate SOAP Envelope to Get Event Instances
String getEventInstances() => header(_event1,
    '<aev:GetEventInstances $_eventNoNS></aev:GetEventInstances>');

/// Generate SOAP Envelop to Get Action Configurations
String getActionConfigs() => header(_action1,
    '<aa:GetActionConfigurations $_actionNoNS></aa:GetActionConfigurations>');

/// Generate SOAP Envelop to Remove Action Configurations
String removeActionConfigs(String id) => header(_action1,
    '''<aa:RemoveActionConfiguration $_actionNoNS>
      <ConfigurationID>$id</ConfigurationID>
    </aa:RemoveActionConfiguration>''');

/// Generate SOAP Evelop to Add Action Configuration
String addActionConfig(ActionConfig ac) {
  var body = '''<aa:AddActionConfiguration $_actionNoNS>
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
    '<aa:GetActionRules $_actionNoNS></aa:GetActionRules>');

/// Generate SOAP Envelop to Remove Action Rules
String removeActionRule(String id) => header(_action1,
    '''<aa:RemoveActionRule $_actionNoNS>
      <RuleID>$id</RuleID>
    </aa:RemoveActionRule>''');

/// Generate SOAP Envelop to Add Action Rule
String addActionRule(ActionRule ar, ActionConfig ac) {
  bool isCont = ac.template == ActionConfig.continuous;
  String body = '''<aa:AddActionRule $_actionNoNS>
      <NewActionRule>
        <Name>${ar.name}</Name>
        <Enabled>${ar.enabled}</Enabled>
  ''';
  if (isCont) {
    body += '<Conditions>\n';
  } else {
    body += '<StartEvent>\n';
  }
  for (var c in ar.conditions) {
    if (isCont) body += '<Condition>\n';
    body += '        <wsnt:TopicExpression Dialect="http://www.onvif.org/ver10/tev/topicExpression/ConcreteSet">${c.topic}</wsnt:TopicExpression>\n';
    body += '          <wsnt:MessageContent Dialect="http://www.onvif.org/ver10/tev/messageContentFilter/ItemFilter">${c.message}</wsnt:MessageContent>\n';
    if (isCont) body += '</Condition>\n';
  }
  if (isCont) {
    body += '</Conditions>\n';
  } else {
    body += '</StartEvent>';
  }
  body += '''        <PrimaryAction>${ar.primaryAction}</PrimaryAction>
      </NewActionRule>
    </aa:AddActionRule>''';

  return header(_action1, body);
}

String addVirtualActionRule(ActionRule ar, ActionConfig ac) {
  var body = '''<aa:AddActionRule $_actionNoNS>
    <NewActionRule>
      <Name>${ar.name}</Name>
      <Enabled>${ar.enabled}</Enabled>
      <Conditions>\n''';
      for (var c in ar.conditions) {
        body += '<Condition>\n';
        body += '        <wsnt:TopicExpression Dialect="http://www.onvif.org/ver10/tev/topicExpression/ConcreteSet">${c.topic}</wsnt:TopicExpression>\n';
        body += '          <wsnt:MessageContent Dialect="http://www.onvif.org/ver10/tev/messageContentFilter/ItemFilter">${c.message}</wsnt:MessageContent>\n';
        body += '</Condition>\n';
      }
      body += '''</Conditions>
      <PrimaryAction>${ar.primaryAction}</PrimaryAction>
    </NewActionRule>
  </aa:AddActionRule>''';

      return header(_action1, body);
}

/// Generate SOAP Envelope to Get Light Service Capabilities
String getServiceCapabilities() => header(_light,
    '<ali:GetServiceCapabilities $_lightNoNs></ali:GetServiceCapabilities>');

/// Generate SOAP Envelope to Get Light Information
String getLightInformation() => header(_light,
    '<ali:GetLightInformation $_lightNoNs></ali:GetLightInformation>');