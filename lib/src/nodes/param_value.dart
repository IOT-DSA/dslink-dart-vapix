import 'common.dart';

class ParamValue extends ChildNode {
  static const String isType = 'paramValue';

  static Map<String, dynamic> definition(String val) => {
    r'$is': isType,
    r'$type' : 'string',
    r'?value' : val,
    r'$writable' : 'write'
  };

  ParamValue(String path) : super(path) {
    serializable = false;
  }

  @override
  bool onSetValue(dynamic newVal) {
    var p = path.split('/').sublist(3).join('.');

    var oldVal = value;
    getClient().then((cl) {
      return cl.updateParameter(p, newVal);
    }).then((success) {
      if (success) return;
      updateValue(oldVal);
    });

    return false;
  }
}
