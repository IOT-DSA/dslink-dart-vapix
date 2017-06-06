import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:http/http.dart' as http;
import 'package:dslink/utils.dart' show logger;
import 'package:xml/xml.dart' as xml;
import 'package:crypto/crypto.dart' show md5, MD5, Digest;

import 'soap_message.dart' as soap;
import 'models/axis_device.dart';
import 'models/events_alerts.dart';

enum AuthError { ok, auth, notFound, server, other }

typedef void disconnectCallback(bool disconnected);

class VClient {
  static final Map<String, VClient> _cache = <String, VClient>{};
  static final String _paramPath = '/axis-cgi/param.cgi';

  Uri _rootUri;
  Uri _origUri;
  String _user;
  String _pass;
  String _ha1;
  http.Client _client;
  disconnectCallback onDisconnect;

  List<ActionConfig> _configs = new List<ActionConfig>();
  List<ActionRule> _rules = new List<ActionRule>();
  MotionEvents _motionEvents;

  List<ActionConfig> getConfigs() => _configs;
  List<ActionRule> getRules() => _rules;
  MotionEvents getMotion() => _motionEvents;

  AxisDevice device;
  bool _authenticated = false;
  int _authAttempt = 0;

  factory VClient(Uri uri, String user, String pass, bool secure) =>
      _cache['$user@$uri'] ??= new VClient._(uri, user, pass, secure);

  VClient._(this._origUri, this._user, this._pass, bool secure) {
    _rootUri = _origUri.replace(userInfo: '');
    if (!secure) {
      _rootUri = _rootUri.replace(userInfo: '$_user:$_pass');
    }
    _client = new http.IOClient();
  }

  Future<AuthError> reconnect() async {
    _authenticated = false;
    _authAttempt = 0;
    return authenticate();
  }

  // Try authenticate and load the parameters for the device.
  Future<AuthError> authenticate() async {
    if (_authenticated && device != null) return AuthError.ok;

    var q = {'action': 'list'};
    var uri = _rootUri.replace(path: _paramPath, queryParameters: q);
    String body;
    try {
      var resp = await _client.get(uri);
      String authHead;
      while (_authAttempt < 3 && resp.statusCode == HttpStatus.UNAUTHORIZED) {
        authHead = _digestAuth(uri, resp);
        print('Attempt: $_authAttempt');
        resp = await _client.get(uri, headers: {
          HttpHeaders.AUTHORIZATION: authHead
        });
      }

      if (resp.statusCode != HttpStatus.OK) {
        logger.warning('Request returned status code: ${resp.statusCode}');
      }

      if (resp.statusCode == HttpStatus.UNAUTHORIZED) {
        logger.warning('Unauthorized: UserInfo ${uri.userInfo}');
        close();
        if (onDisconnect != null) onDisconnect(true);
        return AuthError.auth;
      }
      body = resp.body;
      _authAttempt = 0;
    } catch (e) {
      logger.warning('Error getting url: $uri', e);
      if (onDisconnect != null) onDisconnect(true);
      return AuthError.server;
    }

    if (!body.contains('=')) {
      logger.warning('Error in body: $body');
      return AuthError.other;
    }

    _authAttempt = 0;
    device = new AxisDevice(_rootUri, body);
    _authenticated = true;
    if (onDisconnect != null) onDisconnect(false);
    return AuthError.ok;
  }

  String _digestAuth(Uri uri, http.Response resp) {
    var authVals = HeaderValue.parse(resp.headers[HttpHeaders.WWW_AUTHENTICATE],
        parameterSeparator: ',') ;

    var reqUri = uri.path;
    if (uri.hasQuery) {
      reqUri = '$reqUri?${uri.query}';
    }
    var realm = authVals.parameters['realm'];
    if (_ha1 == null || _ha1 == "") {
      _ha1 = (md5 as MD5).convert('$_user:$realm:$_pass'.codeUnits).toString();
    }
    var ha2 = (md5 as MD5).convert('${resp.request.method}:$reqUri'.codeUnits)
        .toString();
    var nonce = authVals.parameters['nonce'];
    var nc = (++_authAttempt).toRadixString(16);
    nc = nc.padLeft(8, '0');
    var cnonce = _generateCnonce();
    var qop = authVals.parameters['qop'];
    var response = (md5 as MD5)
        .convert('$_ha1:$nonce:$nc:$cnonce:$qop:$ha2'.codeUnits)
        .toString();

    StringBuffer buffer = new StringBuffer()
      ..write('Digest ')
      ..write('username="$_user"')
      ..write(', realm="$realm"')
      ..write(', nonce="$nonce"')
      ..write(', uri="$reqUri"')
      ..write(', qop=$qop')
      ..write(', algorithm="MD5"')
      ..write(', nc=$nc')
      ..write(', cnonce="$cnonce"')
      ..write(', response="$response"');
    if (authVals.parameters.containsKey('opaque')) {
      buffer.write(', opaque="${authVals.parameters['opaque']}"');
    }

    return buffer.toString();
  }

  String _generateCnonce() {
    List<int> l = <int>[];
    var rand = new Random.secure();
    for (var i = 0; i < 4; i++) {
      l.add(rand.nextInt(255));
    }
    return new Digest(l).toString();
  }

  Future<AuthError>
  updateClient(Uri uri, String user, String pass, bool secure) async {
    var cl = new VClient._(uri, user, pass, secure);
    var res = await cl.authenticate();
    if (res == AuthError.ok) {
      close();
      _cache['$user@$uri'] = cl;
    }
    return res;
  }

  void close() {
    _client?.close();
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
      while (resp.statusCode == HttpStatus.UNAUTHORIZED && _authAttempt < 3) {
        var authHead = _digestAuth(uri, resp);
        resp = await _client.get(uri, headers: {
          HttpHeaders.AUTHORIZATION: authHead
        });
      }
    } catch (e) {
      if (onDisconnect != null) onDisconnect(true);
      _authenticated = false;
      logger.warning('Error adding motion', e);
    }

    if (resp.statusCode != HttpStatus.UNAUTHORIZED) {
      _authAttempt = 0;
    }

    if (resp.statusCode != HttpStatus.OK) {
      if (onDisconnect != null) onDisconnect(true);
      _authenticated = false;
      return null;
    }

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
      while (resp.statusCode == HttpStatus.UNAUTHORIZED && _authAttempt < 3) {
        var authHead = _digestAuth(uri, resp);
        resp = await _client.get(uri, headers: {
          HttpHeaders.AUTHORIZATION: authHead
        });
      }
    } catch (e) {
      logger.warning('Error removing motion window', e);
    }

    if (resp.statusCode != HttpStatus.UNAUTHORIZED) {
      _authAttempt = 0;
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
      while (resp.statusCode == HttpStatus.UNAUTHORIZED && _authAttempt < 3) {
        var authHead = _digestAuth(uri, resp);
        resp = await _client.get(uri, headers: {
          HttpHeaders.AUTHORIZATION: authHead
        });
      }
    } catch (e) {
      logger.warning('Error modifying parameter: $path', e);
      if (onDisconnect != null) onDisconnect(true);
      _authenticated = false;
      return false;
    }

    if (resp.statusCode != HttpStatus.UNAUTHORIZED) {
      _authAttempt = 0;
    }

    var res = resp.body.trim().toLowerCase() == 'ok';
    if (!res) {
      logger.warning('Failed to modify parameter "$path" with value: $value\n'
          'Response was: ${resp.body}');
    }

    return res;
  }

  Future<MotionEvents> getEventInstances() async {
    var doc = await _soapRequest(soap.getEventInstances(), soap.headerGEI);

    if (doc == null) return null;
    var els = doc.findAllElements('tnsaxis:MotionDetection');
    if (els == null || els.isEmpty) {
      els = doc.findAllElements('tnsaxis:VMD3');
      if (els == null || els.isEmpty) return null;
    }
    var me = new MotionEvents(els.first);
    _motionEvents = me;
    return me;
  }

  Future<List<ActionConfig>> getActionConfigs() async {
    print('Getting Configs');
    var doc = await _soapRequest(soap.getActionConfigs(), soap.headerGAC);

    if (doc == null) return null;
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
    ac.id = el.text;
    _configs.add(ac);
    return el.text;
  }

  Future<bool> removeActionConfig(String id) async {
    var doc = await _soapRequest(soap.removeActionConfigs(id), soap.headerRAC);

    if (doc == null) return false;
    var el = doc.findAllElements('aa:RemoveActionConfigurationResponse')?.first;
    if (el == null) return false;

    var ret = (el.text == null || el.text.isEmpty);
    if (ret) {
      _configs.removeWhere((ac) => ac.id == id);
    }
    return ret;
  }

  Future<List<ActionRule>> getActionRules() async {
    var doc = await _soapRequest(soap.getActionRules(), soap.headerGAR);

    if (doc == null) return null;
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
    _rules = res;
    return res;
  }

  Future<String> addActionRule(ActionRule ar, ActionConfig ac) async {
    var doc = await _soapRequest(soap.addActionRule(ar, ac), soap.headerAAR);

    if (doc == null) return null;
    var el = doc.findAllElements('aa:RuleID')?.first;
    if (el == null) return null;
    ar.id = el.text;
    _rules.add(ar);
    return el.text;
  }

  Future<bool> removeActionRule(String id) async {
    var doc = await _soapRequest(soap.removeActionRule(id), soap.headerRAR);

    if (doc == null) return false;
    var el = doc.findAllElements('aa:RemoveActionRuleResponse')?.first;
    if (el == null) return null;
    var ret = (el.text == null || el.text.isEmpty);

    if (ret) {
      _rules.removeWhere((ar) => ar.id == id);
    }
    return ret;
  }

  Future<xml.XmlDocument> _soapRequest(String msg, String header) async {
    var qp = {
      'timestamp': '${new DateTime.now().millisecondsSinceEpoch}'
    };
    final url = _rootUri.replace(path: 'vapix/services', queryParameters: qp);
    final headers = <String, String>{
      'Content-Type': 'text/xml;charset=UTF-8',
      'SOAPAction': header
    };

    String respBody;
    try {
      var resp = await _client.post(url, body: msg, headers: headers)
          .timeout(new Duration(seconds: 30));

      while (resp.statusCode == HttpStatus.UNAUTHORIZED && _authAttempt < 4) {
        var auth = _digestAuth(url, resp);
        headers[HttpHeaders.AUTHORIZATION] = auth;
        resp = await _client.post(url, headers: headers, body: msg);
      }

      if (resp.statusCode != HttpStatus.UNAUTHORIZED) {
        _authAttempt = 0;
      }

      if (resp.statusCode != HttpStatus.OK) {
        _logErr(resp, header, msg, headers);
      } else {
        respBody = resp.body;
      }
    } on TimeoutException catch (e) {
      if (onDisconnect != null) onDisconnect(true);
      _authenticated = false;
      logger.warning('SOAP Request timed out.', e);
      return null;
    } catch (e) {
      logger.warning('Sending SOAP request failed', e);
      if (onDisconnect != null) onDisconnect(true);
      _authenticated = false;
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

  void _logErr(http.Response resp, String action, String msg, Map headers) {
    logger.warning('Action Failed: $action\n'
        'Status code: ${resp.statusCode}\n'
        'Reason: ${resp.reasonPhrase}\n'
        'Body: ${resp.body}\n'
        'Message: $msg\n'
        'Headers: $headers');
  }

}
