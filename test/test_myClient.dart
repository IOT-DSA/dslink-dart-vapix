import 'dart:async';

import 'package:dslink_vapix/src/client.dart';

Future main() async {
  var uri = Uri.parse('http://10.54.80.155');
  var cl = new VClient(uri, 'root', 'Dg!ux1234', true);

  var res = await cl.authenticate();
  print(res);
  var hasControls = await cl.hasLedControls();
  print('hasControls: $hasControls');
  if (hasControls) {
    var temp = await cl.getLeds();
    for (var t in temp) {
      print('Light: ${t.name}');
      for (var c in t.colors) {
        print('\tColor: ${c.name} - ${c.userControllable}');
      }
    }
  }
}
