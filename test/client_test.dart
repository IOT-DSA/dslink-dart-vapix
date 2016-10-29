import 'dart:async';

import 'package:dslink_vapix/src/client.dart';

Future<Null> main() async {
  var uri = Uri.parse('http://10.0.1.180');
  var cl = new VClient(uri, 'root', 'root');

  var res = await cl.authenticate();
  print(res);
  var body = await cl.getEventInstances();
  print(body);
}
