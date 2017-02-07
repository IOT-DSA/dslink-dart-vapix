import 'dart:async';

import 'package:dslink_vapix/src/client.dart';

Future main() async {
  var uri = Uri.parse('http://192.168.1.6');
  var cl = new VClient(uri, 'root', 'root', true);

  var res = await cl.authenticate();
  print(res);
  var temp = await cl.getEventInstances();
  print(temp);
}
