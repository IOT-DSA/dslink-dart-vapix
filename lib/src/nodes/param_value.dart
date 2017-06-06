import 'common.dart';

class ParamsNode extends ChildNode {
  static const String isType = 'paramsNode';
  static const String pathName = 'params';

  static Map<String, dynamic> def() => {
    r'$is': isType
  };

  ParamsNode(String path) : super(path);
}

//* @Node
//* @MetaType ParamValue
//* @Parent params
//*
//* Parameter of the Device configuration.
//*
//* ParamValue is the value of a parameter within the Axis Camera.
//* Parameters will automatically generate a tree based on the tree provided
//* by the remote device. The path and name of the ParamValue will be that of
//* the path in the device's configuration. The value is the value of that
//* parameter.
//*
//* @Value string write
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
