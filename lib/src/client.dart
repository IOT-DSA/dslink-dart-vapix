import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:dslink/utils.dart' show logger;

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

  Future<AuthError> update(Uri uri, String user, String pass) async {
    var cl = new VClient._(uri, user, pass);
    var res = await cl.authenticate();
    if (res == AuthError.ok) {
      _client.close();
      _cache.remove('$_user@$_origUri');
      _cache['$user@$uri'] = cl;
    }
    return res;
  }

  void close() {

  }

  Future<String> getEventInstances() =>
      _soapRequest(soap.getEventInstances,
          r'http://www.axis.com/vapix/ws/event1/GetEventInstances');

  Future<String> _soapRequest(String msg, String header) async {
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

    return respBody;
  }

  void _logErr(http.Response resp, String action) {
    logger.warning('Action Failed: $action\n'
        'Status code: ${resp.statusCode}\n'
        'Reason: ${resp.reasonPhrase}\n'
        'Body: ${resp.body}');
  }

}
