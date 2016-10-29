import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:dslink/utils.dart' show logger;
import 'package:xml/xml.dart' as xml;

import 'soap_message.dart' as soap;
import 'models/axis_device.dart';

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

  Future<String> getEventInstances() async {
    var doc = await _soapRequest(soap.getEventInstances,
        r'http://www.axis.com/vapix/ws/event1/GetEventInstances');

    var el = doc.findAllElements('tnsaxis:MotionDetection').first;
    print(el);
    return '';
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

    var doc = xml.parse(respBody);

    return doc;
  }

  void _logErr(http.Response resp, String action) {
    logger.warning('Action Failed: $action\n'
        'Status code: ${resp.statusCode}\n'
        'Reason: ${resp.reasonPhrase}\n'
        'Body: ${resp.body}');
  }

}
