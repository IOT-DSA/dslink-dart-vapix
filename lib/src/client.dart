import 'dart:async';
import 'dart:collection' show Queue;
import 'dart:io';
import 'dart:math' show Random;

import 'package:http/http.dart' as http;
import 'package:dslink/utils.dart' show logger;
import 'package:xml/xml.dart' as xml;
import 'package:crypto/crypto.dart' show md5, MD5, Digest;

import 'soap_message.dart' as soap;
import '../models.dart';

enum AuthError { ok, auth, notFound, server, other }

typedef void disconnectCallback(bool disconnected);

const Duration _Timeout = const Duration(seconds: 30);

class VClient {
  static final Map<String, VClient> _cache = <String, VClient>{};
  static const String _paramPath = '/axis-cgi/param.cgi';
  static const String _imgSizePath = '/axis-cgi/imagesize.cgi';
  static const String _ptzPath = '/axis-cgi/com/ptz.cgi';
  static const String _ledsPath = '/axis-cgi/ledcontrol/getleds.cgi';

  Uri _rootUri;
  Uri _origUri;
  String _user;
  String _pass;
  String _ha1;
  http.Client _client;
  disconnectCallback onDisconnect;
  Queue<ClientReq> _queue;

  List<ActionConfig> _configs = new List<ActionConfig>();
  List<ActionRule> _rules = new List<ActionRule>();

  // populated lazilly
  // see getPTZCommands
  List<PTZCameraCommands> _ptzCommands;
  
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
    _queue = new Queue<ClientReq>();
  }

  Future<AuthError> reconnect() async {
    _authenticated = false;
    _authAttempt = 0;
    return authenticate();
  }

  // Try authenticate and load the parameters for the device.
  Future<AuthError> authenticate({bool force: false}) async {
    if (_authenticated && device != null && !force) return AuthError.ok;

    var q = {'action': 'list'};
    var uri = _rootUri.replace(path: _paramPath, queryParameters: q);

    ClientResp resp;
    String body;
    try {
      resp = await _addRequest(uri, reqMethod.GET);
    } catch (e) {
      logger.warning('${_rootUri.host} -- Failed to authenticate.', e);
      return AuthError.server;
    }

    if (resp.status == HttpStatus.UNAUTHORIZED) {
      logger.warning('${_rootUri.host} -- Unauthorized: UserInfo '
          '${uri.userInfo}');
      close();
      if (onDisconnect != null) onDisconnect(true);
      return AuthError.auth;
    }

    body = resp.body;
    if (!body.contains('=')) {
      logger.warning('${_rootUri.host} -- Error in body when authenticating: '
          '$body');
      return AuthError.other;
    }

    device = new AxisDevice(_rootUri, body);
    _authenticated = true;
    if (onDisconnect != null) onDisconnect(false);
    return AuthError.ok;
  }

  String _digestAuth(Uri uri, http.Response resp) {
    var authVals = HeaderValue.parse(resp.headers[HttpHeaders.WWW_AUTHENTICATE],
        parameterSeparator: ',');

    var reqUri = uri.path;
    if (uri.hasQuery) {
      reqUri = '$reqUri?${uri.query}';
    }
    var realm = authVals.parameters['realm'];
    if (_ha1 == null || _ha1 == "") {
      _ha1 = (md5 as MD5).convert('$_user:$realm:$_pass'.codeUnits).toString();
    }
    var ha2 = (md5 as MD5)
        .convert('${resp.request.method}:$reqUri'.codeUnits)
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

  Future<AuthError> updateClient(
      Uri uri, String user, String pass, bool secure) async {
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

  bool supportsPTZ() {
    if (device == null) {
      throw new StateError("supportsPTZ called before device initialized");
    }

    return device.params.map["Properties"]["PTZ"]["PTZ"] == "yes";
  }

  Future<List<PTZCameraCommands>> getPTZCommands() async {
    // use cache if available
    if (_ptzCommands != null) {
      return _ptzCommands;
    }

    if (!supportsPTZ()) {
      return const [];
    }

    var numCams = int.parse(device.params.numSources);

    var futures = new List<Future<PTZCameraCommands>>();
    for (var i = 1; i <= numCams; i++) {
      final Map<String, String> map = {
        'info': '1',
        'camera': i.toString()
      }; 

      var uri = _rootUri.replace(path: _ptzPath, queryParameters: map);
    
      try {
        futures.add(_addRequest(uri, reqMethod.GET).then((ClientResp resp) {
          var lines = resp.body.split("\n");
          bool start = false;

          List<PTZCommand> commands = [];
          List<String> queue = [];

          void flushQueue() {
            if (queue.isEmpty) {
              return;
            }

            PTZCommand command = new PTZCommand.fromStrings(queue);
            if (command != null) {
              commands.add(command);
            }

            queue.clear();
          }

          for (String line in lines) {
            if (line.startsWith("whoami")) {
              start = true;
              continue;
            }

            if (!start) {
              continue;
            }

            // if subcommand or queue is empty, add to queue and continue
            if (line.startsWith(" ") || line.startsWith("\t") || queue.isEmpty) {
              queue.add(line);
              continue;
            }

            // flush queue, then start anew
            flushQueue();

            if (line.isNotEmpty) {
              queue.add(line);
            }
          }

          // make sure last command is added
          flushQueue();
          
          return new PTZCameraCommands(commands, i);
        }));
      } catch (e) {
        logger.warning('${_rootUri.host}-- Failed to check for PTZ commands on camera $i.', e);
      }
    }

    return await Future.wait(futures);
  }

  Future<bool> runPtzCommand(int cameraId, Map<String, dynamic> params) async {
    params.forEach((key, val) {
      if (val is List) {
        params[key] = val.join(",");
      }

      params[key] = val.toString();
    });

    params["camera"] = cameraId.toString();

    var uri = _rootUri.replace(path: _ptzPath, queryParameters: params);
    ClientResp resp;
    try {
      resp = await _addRequest(uri, reqMethod.GET);
    } catch (e) {
      logger.warning('${_rootUri.host}-- Failed to execute PTZ command.', e);
      return null;
    }

    return resp.status == HttpStatus.OK;
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
    ClientResp resp;
    try {
      resp = await _addRequest(uri, reqMethod.GET);
    } catch (e) {
      logger.warning('${_rootUri.host}-- Failed to add motion window.', e);
      return null;
    }

    String body = resp.body;
    if (resp.status != HttpStatus.OK || body == null || body.isEmpty) {
      logger.warning('${_rootUri.host}-- Failed to add motion window. '
          'Status: ${resp.status}');
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

    ClientResp resp;
    try {
      resp = await _addRequest(uri, reqMethod.GET);
    } catch (e) {
      logger.warning('${_rootUri.host} -- Failed to remove motion', e);
      return false;
    }

    var res = resp.body.trim().toLowerCase() == 'ok';
    if (!res) {
      logger.warning('${_rootUri.host} -- Failed to remove motion window: '
          '${resp.body}');
    }

    return res;
  }

  Future<bool> updateParameter(String path, String value) async {
    final Map<String, String> params = {'action': 'update', path: value};

    var uri = _rootUri.replace(path: _paramPath, queryParameters: params);
    ClientResp resp;
    try {
      resp = await _addRequest(uri, reqMethod.GET);
    } catch (e) {
      logger.warning('${_rootUri.host} -- Error modifying parameter: $path', e);
      return false;
    }

    var res = resp.body.trim().toLowerCase() == 'ok';
    if (!res) {
      logger.warning('${_rootUri.host} -- Failed to modify parameter "$path" '
          'with value: $value\nResponse was: ${resp.body}');
    }

    return res;
  }

  Future<List<CameraResolution>> getResolutions() async {
    var numCams = int.parse(device.params.numSources);

    var futs = new List<Future>();
    for (var i = 1; i <= numCams; i++) {
      var params = {'camera': '$i'};
      var uri = _rootUri.replace(path: _imgSizePath, queryParameters: params);
      futs.add(_addRequest(uri, reqMethod.GET).then((ClientResp resp) {
        int width;
        int height;
        var lines = resp.body.split('\n');
        for (var line in lines) {
          if (line.contains('width')) {
            var tmp = line.split('=').map((str) => str.trim()).toList();
            width = int.parse(tmp[1]);
          } else if (line.contains('height')) {
            var tmp = line.split('=').map((str) => str.trim()).toList();
            height = int.parse(tmp[1]);
          } else {
            continue;
          }
        }
        return new CameraResolution(i, width, height);
      }));
    }

    return Future.wait(futs);
  }

  //***************************************
  //************** SOAP CALLS *************
  //***************************************

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

  Future<List<Led>> getLeds() async {
    final query = <String,String>{
      'schemaversion': '1'
    };
    var uri = _rootUri.replace(path: _ledsPath, queryParameters: query);
    var res = await _addRequest(uri, reqMethod.GET);

    xml.XmlDocument doc;
    try {
      doc = xml.parse(res.body);
    } catch (e) {
      logger.warning(
          '${_rootUri.host} -- Failed to parse results: '
              '${res.body}',
          e);
      return null;
    }

    if (doc == null) return null;
    var els = doc.findAllElements('LedCapabilities');

    var list = new List<Led>();

    if (els == null) return list;
    for (var el in els) {
      list.add(new Led.fromXml(el));
    }

    return list;
  }

  Future<Iterable<xml.XmlElement>> getActionTemplates() async {
    print('Getting Templates.');
    var doc = await _soapRequest(soap.getActionTemplates(), soap.headerGAT);
    
    if (doc == null) return [];
    
    return doc.findAllElements('aa:ActionTemplate');
  }

  Future<bool> hasLedControls() async {
    var templates = await getActionTemplates();

    for (var t in templates) {
      var token = t.findElements('aa:TemplateToken')?.first;
      if (token == null) continue;
      if (token.text == 'com.axis.action.unlimited.ledcontrol') return true;
    }

    return false;
  }

  Future<List<ActionConfig>> getActionConfigs() async {
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
    _configs = res;
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
        for (var c in conds) {
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
    var qp = {'timestamp': '${new DateTime.now().millisecondsSinceEpoch}'};
    final url = _rootUri.replace(path: 'vapix/services', queryParameters: qp);
    final headers = <String, String>{
      'Content-Type': 'text/xml;charset=UTF-8',
      'SOAPAction': header
    };

    ClientResp resp;
    try {
      resp = await _addRequest(url, reqMethod.POST, msg, headers);
    } catch (e) {
      logger.warning('${_rootUri.host} -- Error sending SOAP request.', e);
      return null;
    }

    xml.XmlDocument doc;
    try {
      doc = xml.parse(resp.body);
    } catch (e) {
      logger.warning(
          '${_rootUri.host} -- Failed to parse results: '
          '${resp.body}',
          e);
      return null;
    }

    return doc;
  }

  Future<ClientResp> _addRequest(Uri uri, reqMethod method,
      [String msg, Map headers]) {
    var cr = new ClientReq(uri, method, msg, headers);
    _queue.add(cr);
    _sendRequest();
    return cr.response;
  }

  bool _reqPending = false;
  Future _sendRequest() async {
    if (_reqPending || _queue.isEmpty) return;

    _reqPending = true;
    ClientReq req = _queue.removeFirst();

    http.Response resp;
    try {
      switch (req.method) {
        case reqMethod.GET:
          resp = await _client
              .get(req.url, headers: req.headers)
              .timeout(_Timeout);
          break;
        case reqMethod.POST:
          resp = await _client
              .post(req.url, headers: req.headers, body: req.msg)
              .timeout(_Timeout);
          break;
      }

      var headers = req.headers ?? {};
      while (resp.statusCode == HttpStatus.UNAUTHORIZED && _authAttempt < 4) {
        var auth = _digestAuth(req.url, resp);
        headers[HttpHeaders.AUTHORIZATION] = auth;
        if (req.method == reqMethod.GET) {
          resp = await _client.get(req.url, headers: headers).timeout(_Timeout);
        } else if (req.method == reqMethod.POST) {
          resp = await _client
              .post(req.url, headers: headers, body: req.msg)
              .timeout(_Timeout);
        }
      }

      if (resp.statusCode != HttpStatus.UNAUTHORIZED) _authAttempt = 0;
      req._comp.complete(new ClientResp(resp.statusCode, resp.body));
    } catch (e) {
      _authenticated = false;
      if (onDisconnect != null) onDisconnect(true);
      req._comp.completeError(e);
    } finally {
      _reqPending = false;
      _sendRequest();
    }
  }
}

enum reqMethod { GET, POST }

class ClientReq {
  final Uri url;
  final String msg;
  final Map headers;
  final reqMethod method;
  Future<ClientResp> get response => _comp.future;

  Completer<ClientResp> _comp;
  ClientReq(this.url, this.method, [this.msg = null, this.headers = null]) {
    _comp = new Completer<ClientResp>();
  }
}

class ClientResp {
  final String body;
  final int status;
  ClientResp(this.status, this.body);
}
