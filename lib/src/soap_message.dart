String header(String template, String request) =>
    '''<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" $template xmlns:tns1="http://www.onvif.org/ver10/topics" xmlns:tnsaxis="http://www.axis.com/2009/event/topics" xmlns:wsnt="http://docs.oasis-open.org/wsn/b-2" xmlns:soap="http://www.w3.org/2003/05/soap-envelope">
  <soap:Body>
    $request
  </soap:Body>
</soap:Envelope>
''';

String get getEventInstances => header(
    'xmlns:aev="http://www.axis.com/vapix/ws/event1"',
    '<aev:GetEventInstances xmlns="http://www.axis.com/vapix/ws/event1"></aev:GetEventInstances>');

String get getActionConfigs => header(
    'xmlns:aev="http://www.axis.com/vapix/ws/action1"',
    '<aev:GetActionConfigurations xmlns="http://www.axis.com/vapix/ws/action1"></aev:GetActionConfigurations>');

String get getActionRules => header(
    'xmlns:aa="http://www.axis.com/vapix/ws/action1"',
    '<aa:GetActionRules xmlns="http://www.axis.com/vapix/ws/action1"></aa:GetActionRules>');
