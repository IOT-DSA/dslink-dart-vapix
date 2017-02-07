import 'dart:async';
import 'dart:math' show Random;
import 'dart:convert' show UTF8;
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:dslink_vapix/src/soap_message.dart' as soap;

String _ha1;
String _user;
String _pass;
int _authAttempt = 0;

Future<Null> main() async {
  var cl = new http.Client();

  _user = 'root';
  _pass = 'root';

  var rootUri = Uri.parse('http://192.168.1.6/vapix/services');

  var headers = <String, String>{
    'Content-Type': 'text/xml;charset=UTF-8',
    'SOAPAction': soap.headerGAR
  };

  var msg = soap.getActionRules();
  var res = await cl.post(rootUri, headers: headers, body: msg);

  while (res.statusCode == HttpStatus.UNAUTHORIZED) {
    var auth = _digestAuth(rootUri, res);
    headers[HttpHeaders.AUTHORIZATION] = auth;
    res = await cl.post(rootUri, headers: headers, body: msg);
  }

  print(res.statusCode);
  print(res.body);
}

String _generateCnonce() {
  List<int> l = <int>[];
  var rand = new Random.secure();
  for (var i = 0; i < 4; i++) {
    l.add(rand.nextInt(255));
  }
  return new Digest(l).toString();
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
