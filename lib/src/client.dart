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
enum AuthState { failed, authenticated, trying, not }

typedef void disconnectCallback(bool isDisconnected);

const Duration _Timeout = const Duration(seconds: 30);

SecurityContext context;

class VClient {
  static final Map<String, VClient> _cache = <String, VClient>{};
  static const String _paramPath = '/axis-cgi/param.cgi';
  static const String _imgSizePath = '/axis-cgi/imagesize.cgi';
  static const String _ptzPath = '/axis-cgi/com/ptz.cgi';
  static const String _ledsPath = '/axis-cgi/ledcontrol/getleds.cgi';
  static const String _viActive = '/axis-cgi/virtualinput/activate.cgi';
  static const String _viDeactive = '/axis-cgi/virtualinput/deactivate.cgi';

  ReqController _controller;
  Uri _rootUri;
  Uri _origUri;
  String _user;
  String _pass;
  // Callback is called after timing out 3 times, or if we receive an
  // UNAUTHENTICATED error after sending Digest (eg username/password error)
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
  AuthState _currAuth = AuthState.not;
  Completer<AuthError> _authStatus;
  Timer _retryTimer;
  Duration _retryDur;

  factory VClient(Uri uri, String user, String pass, bool secure) =>
      _cache['$user@$uri'] ??= new VClient._(uri, user, pass, secure);

  VClient._(this._origUri, this._user, this._pass, bool secure) {
    _rootUri = _origUri.replace(userInfo: '');
    if (!secure) {
      _rootUri = _rootUri.replace(userInfo: '$_user:$_pass');
    }

    _controller = new ReqController();
    _authStatus = new Completer<AuthError>();
  }

  Future<AuthError> reconnect() async {
    if (_currAuth != AuthState.trying) {
      _currAuth = AuthState.not;
    }

    return authenticate(force: true);
  }

  Future retry(bool isDisconnected) async {
    if (_currAuth == AuthState.trying) return;

    if (onDisconnect != null) {
      onDisconnect(isDisconnected);
    }

    // Don't try fallback if we reconnected.
    if (!isDisconnected) {
      _retryDur = null;
      _retryTimer?.cancel();
      return;
    }

    if (_retryDur == null) {
      _retryDur = new Duration(minutes: 5);
    } else {
      var min = _retryDur.inMinutes * 2;
      if (min > 120) min = 120;

      _retryDur = new Duration(minutes: min);
    }

    if (_retryTimer?.isActive == true) _retryTimer.cancel();

    _retryTimer = new Timer(_retryDur, () { authenticate(); });
  }

  // Send a request to the root URL of a camera. Return true if we receive
  // any response at all. Throws an error on timeout (5 second duration) or
  // any socket errors.
  Future<bool> checkConnection() async {
    var ok = true;

    try {
      await http.get(_rootUri).timeout(const Duration(seconds: 5));
    } catch (e) {
      logger.info('Check connection to ${_rootUri.host} failed:', e);
      ok = false;
      new Future.delayed(const Duration(milliseconds:  500), () => retry(!ok));
      rethrow;
    } finally {
      if (onDisconnect != null) {
        onDisconnect(!ok);
      }
    }

    if (ok && _retryTimer != null && _retryTimer.isActive) {
      _retryTimer.cancel();
      _retryDur = null;
    }
      return ok;
  }

  // Try authenticate and load the parameters for the device.
  Future<AuthError> authenticate({bool force: false}) async {
    // When authentication don't try again if we're already in the middle of trying
    if (_currAuth == AuthState.trying) return _authStatus.future;

    if (_retryTimer?.isActive == true) {
      _retryTimer.cancel();
    }

    if (_currAuth == AuthState.authenticated && device != null && !force) {
      return AuthError.ok;
    }

    if (_authStatus == null || _authStatus.isCompleted) {
      _authStatus = new Completer<AuthError>();
    }

    _currAuth = AuthState.trying;

    var q = {'action': 'list'};
    var uri = _rootUri.replace(path: _paramPath, queryParameters: q);

    ClientResp resp;
    String body;
    try {
      resp = await _addRequest(uri, reqMethod.GET);
    } on TimeoutException {
      logger.info('Requests to ${_rootUri.host} timed out.');
      _authStatus.complete(AuthError.server);
      clearConn(); // Reset
      retry(true); // Retry
      return _authStatus.future;
    } catch (e) {
      logger.warning('${_rootUri.host} -- Failed to authenticate.', e);
      clearConn();
      _authStatus.complete(AuthError.server);
      return _authStatus.future;
    }

    if (resp.status == HttpStatus.UNAUTHORIZED) {
      logger.warning('${_rootUri.host} -- Unauthorized: UserInfo '
          '${uri.userInfo}');
      clearConn();
      _authStatus.complete(AuthError.auth);
      return _authStatus.future;
    }

    body = resp.body;
    if (!body.contains('=')) {
      logger.warning('${_rootUri.host} -- Error in body when authenticating: '
          '$body');
      clearConn();
      _authStatus.complete(AuthError.other);
      return _authStatus.future;
    }

    var dev = new AxisDevice(_rootUri, body);
    if (device != null) {
      // Copy the resolution, PTZ commands and LEDS
      device.cloneTo(dev);
    }
    device = dev;

    _currAuth = AuthState.authenticated;

    retry(false);
    _authStatus.complete(AuthError.ok);
    return _authStatus.future;
  }

  Future<AuthError> updateClient(
      Uri uri, String user, String pass, bool secure) async {
    var cl = new VClient._(uri, user, pass, secure);
    var res = await cl.authenticate();
    if (res == AuthError.ok) {
      clearConn();
      _cache['$user@$uri'] = cl;
    }
    return res;
  }

  /// Clear the connection state, removing from cache and flagging as not
  /// authenticated.
  void clearConn() {
    _currAuth = AuthState.not;
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

    List<PTZCameraCommands> res;
    var futures = new List<Future<PTZCameraCommands>>();
    for (var i = 1; i <= numCams; i++) {
      final Map<String, String> map = {'info': '1', 'camera': '$i'};

      var uri = _rootUri.replace(path: _ptzPath, queryParameters: map);

      try {
        futures.add(
            _addRequest(uri, reqMethod.GET)
              .then(_getCommands)
              .then((List<PTZCommand> cmds) => new PTZCameraCommands(cmds, i)));

        res = await Future.wait(futures);
      } catch (e) {
        logger.warning('${_rootUri.host}-- ' +
            'Failed to check for PTZ commands on camera $i.', e);
      }
    }

    return res;
  }

  Future<List<PTZCommand>> _getCommands(ClientResp resp) async {
    var lines = resp.body.split("\n");
    bool foundStart = false;

    List<PTZCommand> commands = [];
    List<String> queue = [];

    void flushQueue() {
      if (queue.isEmpty) return;

      PTZCommand command = new PTZCommand.fromStrings(queue);
      if (command != null) commands.add(command);

      queue.clear();
    }

    for (String line in lines) {
      // Ignore leading lines until we reach whoami (should be first command)
      if (line.startsWith("whoami")) {
        foundStart = true;
        continue;
      }

      // If we haven't hit first command, keep looking
      if (!foundStart) continue;

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
    return commands;
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

    return body.split(' ')[0];
  }

  Future<bool> removeMotion(String group) async {
    var groupStr = group.contains('Motion') ? group : 'Motion.$group';

    final Map<String, String> map = {
      'action': 'remove',
      'group': groupStr
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

  Future<bool> removeMotions(Iterable<String> groups) async {
    String groupStr = '';
    var i = 0;
    for (var g in groups) {
      groupStr += 'Motion.$g';
      if (++i <= groups.length - 1) groupStr += ',';
    }

    return removeMotion(groupStr);
  }

  Future<String> addStreamProfile(Map params) async {
    final Map<String, String> map = {
      'action': 'add',
      'template': 'streamprofile',
      'group': 'StreamProfile'
    };

    params.forEach((String k, String v) {
      var key = 'StreamProfile.S.$k';
      map[key] = v.toString();
    });

    var uri = _rootUri.replace(path: _paramPath, queryParameters: map);
    ClientResp resp;

    try {
      resp = await _addRequest(uri, reqMethod.GET);
    } catch (e) {
      logger.warning('${_rootUri.host}-- Failed to add Stream Profile.', e);
      return null;
    }

    // Example good response: "S4 OK"
    String body = resp.body;
    if (resp.status != HttpStatus.OK || body == null || body.isEmpty) {
      logger.warning('${_rootUri.host}-- Failed to add Stream Profile. ' +
          'Status: ${resp.status}');
      return null;
    }

    return body.split(' ')[0];
  }

  Future<bool> removeStreamProfile(String group) async {
    var groupStr = group.contains('StreamProfile') ? group : 'StreamProfile.$group';

    final Map<String, String> map = {
      'action': 'remove',
      'group': groupStr
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

  Future<bool> setVirtualPort(int port, bool active) async {
    final Map<String, String> params = {
      'schemaversion': '1',
      'port': '$port'
    };

    var p = active ? _viActive : _viDeactive;
    var uri = _rootUri.replace(path: p, queryParameters: params);

    xml.XmlDocument doc;
    try {
      var resp = await _addRequest(uri, reqMethod.GET);
      doc = xml.parse(resp.body);
    } catch (e) {
      logger.warning('${_rootUri.host} -- Error requesting virtual input', e);
      rethrow;
    }

    var errs = doc.findAllElements('GeneralError');
    if (errs != null && errs.isNotEmpty) {
      var err = errs.first;
      var errCode = err.findElements('ErrorCode')?.first?.text;
      var errDesc = err.findElements('ErrorDescription')?.first?.text;
      throw new Exception('$errCode - $errDesc');
    }

    var states = doc.findAllElements('StateChanged');
    if (states == null || states.isEmpty) {
      throw new StateError('Response did not contain StateChange or error');
    }

    var stateChange = states.first;
    return stateChange.text.trim().toLowerCase() == 'true';
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

    xml.XmlDocument doc;
    ClientResp res;
    try {
      res = await _addRequest(uri, reqMethod.GET);
      doc = xml.parse(res.body);
    } catch (e) {
      logger.warning(
          '${_rootUri.host} -- GetLEDs - Failed to parse results: '
              '${res.body}',
          e);
      return null;
    }

    if (doc == null) return null;
    var els = doc.findAllElements('LedCapabilities');
    var list = new List<Led>();

    if (els == null) return null;
    for (var el in els) {
      list.add(new Led.fromXml(el));
    }

    return list;
  }

  Future<Iterable<xml.XmlElement>> getActionTemplates() async {
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

  Future<String> setLedColor(ActionConfig ac) async {
    var doc = await _soapRequest(soap.addActionConfig(ac), soap.headerAAC);

    if (doc == null) return null;
    var el = doc.findAllElements('aa:ConfigurationID')?.first;
    if (el == null) return null;
    ac.id = el.text;
    _configs.add(ac);
    return el.text;
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
    } else {
      logger.warning('${_rootUri.host} - Failed to remove action config: $id - "${el.text}"');
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

  Future<String> addActionRule(ActionRule ar, ActionConfig ac, [bool virt = false]) async {
    xml.XmlDocument doc;
    if (virt) {
      doc = await _soapRequest(soap.addVirtualActionRule(ar, ac), soap.headerAAR);
    } else {
      doc = await _soapRequest(soap.addActionRule(ar, ac), soap.headerAAR);
    }
    if (doc == null) return null;

    var fault = doc.findAllElements('SOAP-ENV:Fault');
    if (fault != null && fault.isNotEmpty) {
      var err = fault.first.findAllElements('SOAP-ENV:Text');
      if (err != null && err.isNotEmpty) {
        var msg = err.first.text;
        logger.info('${_rootUri.host} - Add ActionRule failed:\n${doc.toString()}');
        throw new Exception('Remote server error: $msg');
      }
    }

    var ruleIds = doc.findAllElements('aa:RuleID');
    if (ruleIds == null || ruleIds.isEmpty) {
      logger.info('${_rootUri.host} - No ruleID found. Failed to add? Data:\n${doc.toString()}');
      return null;
    }
    var el = ruleIds.first;
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
    } else {
      logger.warning('${_rootUri.host} - Failed to remove action rule: $id - "${el.text}"');
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
      logger.warning('${_rootUri.host} -- Error sending SOAP request -- ' +
          'Action: $header', e);
      return null;
    }

    xml.XmlDocument doc;
    try {
      if (resp.body == null || resp.body.isEmpty) {
        throw new StateError('XML Soap response was empty.');
      }
      doc = xml.parse(resp.body);
    } catch (e) {
      logger.warning(
          '${_rootUri.host} -- $header -- Failed to parse results: '
          '${resp.body}',
          e);
      return null;
    }

    return doc;
  }

  Future<ClientResp> _addRequest(Uri uri, reqMethod method,
      [String msg, Map headers]) {
    var cr = new ClientReq(_user, _pass, uri, method, msg, headers);
    cr.callback = retry;
    return _controller.add(cr);
  }
}

class ReqController {
  static ReqController _singleton;
  final Queue<ClientReq> _queue;
  final Queue<http.Client> _clients;

  factory ReqController() {
    _singleton ??= new ReqController._();
    if (_singleton._clients.length < 10) {
      var cl = new HttpClient(context: context);

      cl.badCertificateCallback = (X509Certificate cr, String host, int port) {
        logger.warning('Invalid certificate received for: $host:$port');
        return true;
      };
      _singleton._clients.add(new http.IOClient(cl));
    }

    return _singleton;
  }

  ReqController._() :
        _queue = new Queue<ClientReq>(),
        _clients = new Queue<http.Client>();

  /// Generate a new nonce value for Digest Authentication
  static String _generateCnonce() {
    List<int> l = <int>[];
    var rand = new Random.secure();
    for (var i = 0; i < 4; i++) {
      l.add(rand.nextInt(255));
    }
    return new Digest(l).toString();
  }

  // Generate new Digest Authentication header
  static String _digestAuth(ClientReq cr, http.Response resp) {
    var authVals = HeaderValue.parse(resp.headers[HttpHeaders.WWW_AUTHENTICATE],
        parameterSeparator: ',');

    var uri = cr.url;
    var reqUri = uri.path;
    if (uri.hasQuery) {
      reqUri = '$reqUri?${uri.query}';
    }

    var realm = authVals.parameters['realm'];
    var _ha1 = (md5 as MD5)
        .convert('${cr.user}:$realm:${cr.pass}'.codeUnits)
        .toString();

    var ha2 = (md5 as MD5)
        .convert('${resp.request.method}:$reqUri'.codeUnits)
        .toString();

    var nonce = authVals.parameters['nonce'];
    var nc = cr.authAttempts.toRadixString(16);
    nc = nc.padLeft(8, '0');
    var cnonce = _generateCnonce();
    var qop = authVals.parameters['qop'];
    var response = (md5 as MD5)
        .convert('$_ha1:$nonce:$nc:$cnonce:$qop:$ha2'.codeUnits)
        .toString();

    StringBuffer buffer = new StringBuffer()
      ..write('Digest ')
      ..write('username="${cr.user}"')
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

  Future<ClientResp> add(ClientReq cr) {
    _queue.add(cr);
    _sendRequest();
    return cr.response;
  }

  Future _sendRequest() async {
    if (_queue.isEmpty || _clients.isEmpty) return;

    ClientReq req = _queue.removeFirst();
    var client = _clients.removeFirst();

    http.Response resp;
    try {
      switch (req.method) {
        case reqMethod.GET:
          resp = await client
              .get(req.url, headers: req.headers)
              .timeout(_Timeout);
          break;
        case reqMethod.POST:
          resp = await client
              .post(req.url, headers: req.headers, body: req.msg)
              .timeout(_Timeout);
          break;
      }

      var headers = req.headers ?? {};
      while (resp.statusCode == HttpStatus.UNAUTHORIZED && req.authAttempts < 4) {
        req.authAttempts += 1;
        var auth = _digestAuth(req, resp);
        headers[HttpHeaders.AUTHORIZATION] = auth;
        if (req.method == reqMethod.GET) {
          resp = await client.get(req.url, headers: headers).timeout(_Timeout);
        } else if (req.method == reqMethod.POST) {
          resp = await client
              .post(req.url, headers: headers, body: req.msg)
              .timeout(_Timeout);
        }
      }

      if (resp.statusCode != HttpStatus.UNAUTHORIZED) req.authAttempts = 0;

      req._comp.complete(new ClientResp(resp.statusCode, resp.body));
    } on TimeoutException catch(e) {
      if (req.timeout < 2) {
        // Retry timeouts 3 times. Add to the top of the queue
        req.timeout++;
        _queue.addFirst(req);
      } else {
        logger.info('Request to ${req.url.host} had 3 consecutive timeouts.');
        req._comp.completeError(e);
        req.callback(true);
      }
    } catch (e) {
      req._comp.completeError(e);
    } finally {
      _clients.add(client);
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
  final String user;
  final String pass;
  disconnectCallback callback;
  Future<ClientResp> get response => _comp.future;
  int authAttempts = 0;
  int timeout = 0;

  Completer<ClientResp> _comp;
  ClientReq(this.user, this.pass, this.url, this.method,
      [this.msg = null, this.headers = null]) {
    _comp = new Completer<ClientResp>();
  }
}

class ClientResp {
  final String body;
  final int status;
  ClientResp(this.status, this.body);
}
