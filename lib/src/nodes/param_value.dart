import 'package:dslink/dslink.dart';

class ParamValue extends SimpleNode {
  static const String isType = 'paramValue';

  static Map<String, dynamic> definition(String val) => {
    r'$is': isType,
    r'$type' : 'string',
    r'?value' : val,
    //r'$writable' : 'write'
  };

  ParamValue(String path) : super(path) {
    serializable = false;
  }
}
