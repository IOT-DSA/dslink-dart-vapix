import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:dslink/utils.dart' show logger;
import 'package:xml/xml.dart' as xml;

import 'soap_message.dart' as soap;
import 'models/axis_device.dart';
import 'models/events_alerts.dart';

enum AuthError { ok, auth, notFound, server, other }

class VClient {
  static final Map<String, VClient> _cache = <String, VClient>{};
  static final String _paramPath = '/axis-cgi/param.cgi';

  Uri _rootUri;
  Uri _origUri;
  String _user;
  String _pass;
  http.Client _client;

  AxisDevice device;
  bool _authenticated = false;

  factory VClient(Uri uri, String user, String pass) =>
      _cache['$user@$uri'] ??= new VClient._(uri, user, pass);

  VClient._(this._origUri, this._user, this._pass) {
    _rootUri = _origUri.replace(userInfo: '$_user:$_pass');
    _client = new http.IOClient();
  }

  // Try authenticate and load the parameters for the device.
  Future<AuthError> authenticate() async {
    if (_authenticated && device != null) return AuthError.ok;

    var q = {'action': 'list'};
    var uri = _rootUri.replace(path: _paramPath, queryParameters: q);
    String body;
    try {
      var resp = await _client.get(uri);
      if (resp.statusCode != HttpStatus.OK) {
        logger.warning('Request returned status code: ${resp.statusCode}');
      }
      body = resp.body;
    } catch (e) {
      logger.warning('Error getting url: $uri', e);
      return AuthError.server;
    }

    if (!body.contains('=')) {
      logger.warning('Error in body: $body');
      return AuthError.other;
    }

    device = new AxisDevice(_rootUri, body);
    _authenticated = true;
    return AuthError.ok;
  }

  Future<AuthError> updateClient(Uri uri, String user, String pass) async {
    var cl = new VClient._(uri, user, pass);
    var res = await cl.authenticate();
    if (res == AuthError.ok) {
      close();
      _cache['$user@$uri'] = cl;
    }
    return res;
  }

  void close() {
    _client.close();
    _cache.remove('$_user@$_origUri');
  }

  Future<String> addMotion(Map params) async {
    final Map<String, String> map = {
      'action': 'add',
      'template': 'motion',
      'group': 'Motion'
    };

    params.forEach((key, val) {
      key = 'Motion.M.$key';
      map[key] = '$val';
    });

    var uri = _rootUri.replace(path: _paramPath, queryParameters: map);
    http.Response resp;
    try {
      resp = await _client.get(uri);
    } catch (e) {
      logger.warning('Error adding motion', e);
    }

    if (resp.statusCode != HttpStatus.OK) return null;
    return resp.body.split(' ')[0];
  }

  Future<bool> removeMotion(String group) async {
    final Map<String, String> map = {
      'action': 'remove',
      'group': 'Motion.$group'
    };

    var uri = _rootUri.replace(path: _paramPath, queryParameters: map);
    http.Response resp;
    try {
      resp = await _client.get(uri);
    } catch (e) {
      logger.warning('Error removing motion window', e);
    }

    var res = resp.body.trim().toLowerCase() == 'ok';
    if (!res) {
      logger.warning('Failed to remove motion window: ${resp.body}');
    }

    return res;
  }

  Future<bool> updateParameter(String path, String value) async {
    final Map<String, String> params = {
      'action': 'update',
      path: value
    };

    var uri = _rootUri.replace(path: _paramPath, queryParameters: params);
    http.Response resp;
    try {
      resp = await _client.get(uri);
    } catch (e) {
      logger.warning('Error modifying parameter: $path', e);
    }

    var res = resp.body.trim().toLowerCase() == 'ok';
    if (!res) {
      logger.warning('Failed to modify parameter: ${resp.body}');
    }

    return res;
  }

  Future<MotionEvents> getEventInstances() async {
    var doc = await _soapRequest(soap.getEventInstances(), soap.headerGEI);

    var el = doc.findAllElements('tnsaxis:MotionDetection')?.first;
    var me = new MotionEvents(el);
    return me;
  }

  Future<List<ActionConfig>> getActionConfigs() async {
    var doc = await _soapRequest(soap.getActionConfigs(), soap.headerGAC);

    var configs = doc.findAllElements('aa:ActionConfiguration');
    var res = new List<ActionConfig>();
    if (configs == null || configs.isEmpty) return res;

    for (var c in configs) {
      var id = c.findElements('aa:ConfigurationID')?.first?.text;
      var nm = c.findElements('aa:Name')?.first?.text;
      var tt = c.findElements('aa:TemplateToken')?.first?.text;
      var config = new ActionConfig(nm, id, tt);
      var params = c.findAllElements('aa:Parameter');
      for (var p in params) {
        var val = p.getAttribute('Value');
        var name = p.getAttribute('Name');
        config.params.add(new ConfigParams(name, val));
      }
      res.add(config);
    }
    return res;
  }

  Future<String> addActionConfig(ActionConfig ac) async {
    var doc = await _soapRequest(soap.addActionConfig(ac), soap.headerAAC);

    if (doc == null) return null;
    var el = doc.findAllElements('aa:ConfigurationID')?.first;
    if (el == null) return null;
    return el.text;
  }

  Future<bool> removeActionConfig(String id) async {
    var doc = await _soapRequest(soap.removeActionConfigs(id), soap.headerRAC);

    if (doc == null) return false;
    var el = doc.findAllElements('aa:RemoveActionConfigurationResponse')?.first;
    if (el == null) return null;
    return el.text == '' || el.text == null;
  }

  Future<List<ActionRule>> getActionRules() async {
    var doc = await _soapRequest(soap.getActionRules(), soap.headerGAR);

    var rules = doc.findAllElements('aa:ActionRule');
    var res = new List<ActionRule>();
    if (rules == null || rules.isEmpty) return res;

    for (var r in rules) {
      var id = r.findElements('aa:RuleID')?.first?.text;
      var nm = r.findElements('aa:Name')?.first?.text;
      var en = r.findElements('aa:Enabled')?.first?.text == 'true';
      var pa = r.findElements('aa:PrimaryAction')?.first?.text;
      var rule = new ActionRule(id, nm, en, pa);
      var conds = r.findAllElements('aa:Condition');
      if (conds != null && conds.isNotEmpty) {
        for(var c in conds) {
          var top = c.findElements('wsnt:TopicExpression')?.first?.text;
          var msg = c.findElements('wsnt:MessageContent')?.first?.text;
          rule.conditions.add(new Condition(top, msg));
        }
      }

      res.add(rule);
    }
    return res;
  }

  Future<String> addActionRule(ActionRule ar, ActionConfig ac) async {
    var doc = await _soapRequest(soap.addActionRule(ar, ac), soap.headerAAR);

    if (doc == null) return null;
    var el = doc.findAllElements('aa:RuleID')?.first;
    if (el == null) return null;

    return el.text;
  }

  Future<bool> removeActionRule(String id) async {
    var doc = await _soapRequest(soap.removeActionRule(id), soap.headerRAR);

    if (doc == null) return false;
    var el = doc.findAllElements('aa:RemoveActionRuleResponse')?.first;
    if (el == null) return null;
    return el.text == '' || el.text == null;
  }

  Future<xml.XmlDocument> _soapRequest(String msg, String header) async {
    final url = _rootUri.replace(path: 'vapix/services');
    final headers = <String, String>{
      'Content-Type': 'text/xml; charset=utf-8',
      'SOAPAction': header
    };

    String respBody;
    try {
      final resp = await _client.post(url, body: msg, headers: headers);

      if (resp.statusCode != HttpStatus.OK) {
        _logErr(resp, header);
      } else {
        respBody = resp.body;
      }
    } catch (e) {
      logger.warning('Sending SOAP request failed', e);
    }

    xml.XmlDocument doc;
    try {
      doc = xml.parse(respBody);
    } catch (e) {
      logger.warning('Failed to parse results: $respBody', e);
      return null;
    }

    return doc;
  }

  void _logErr(http.Response resp, String action) {
    logger.warning('Action Failed: $action\n'
        'Status code: ${resp.statusCode}\n'
        'Reason: ${resp.reasonPhrase}\n'
        'Body: ${resp.body}');
  }

}
