import 'dart:async';

import 'package:dslink/dslink.dart';
import 'package:dslink/nodes.dart' show NodeNamer;
import 'package:dslink/utils.dart' show logger;

import 'common.dart';
import 'events_node.dart';
import 'param_value.dart';
import 'window_commands.dart';
import '../client.dart';
import '../models/axis_device.dart';
import '../server.dart';

//* @Action Add_Device
//* @Is addDeviceAction
//* @Parent root
//*
//* Add a new Axis Communications device to the link.
//*
//* Adds a new Axis Communications device to the link. It will validate that
//* it can communicate with the device based on the credentials provided. If
//* Successful it will add a new device to the root of the link with the name
//* provided.
//*
//* @Param deviceName string The name of the device to use in the node tree.
//* @Param address string The IP address of the remote device
//* @Param username string Username required to authenticate to the device.
//* @Param password string Password required to authenticate to the device.
//*
//* @Return values
//* @Column success bool Success returns true on success. False on failure.
//* @Column message string Message returns Success! on success, otherwise
//* it provides an error message.
class AddDevice extends SimpleNode {
  static const String isType = 'addDeviceAction';
  static const String pathName = 'Add_Device';

  static const String _name = 'deviceName';
  static const String _addr = 'address';
  static const String _user = 'username';
  static const String _pass = 'password';
  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Add Device',
    r'$invokable' : 'write',
    r'$params' : [
      {'name': _name, 'type': 'string', 'placeholder': 'Device Name'},
      {'name': _addr, 'type': 'string', 'placeholder': 'http://<ipaddress>'},
      {'name': _user, 'type': 'string', 'placeholder': 'Username'},
      {'name': _pass, 'type': 'string', 'editor': 'password'}
    ],
    r'$columns' : [
      { 'name' : _success, 'type' : 'bool', 'default' : false },
      { 'name' : _message, 'type' : 'string', 'default': '' }
    ]
  };

  LinkProvider _link;

  AddDevice(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, String> params) async {
    final ret = { _success: false, _message: '' };

    if (params[_name] == null || params[_name].isEmpty) {
      return ret..[_message] = 'A name must be specified.';
    }
    var name = NodeNamer.createName(params[_name].trim());

    var nd = provider.getNode('/$name');
    if (nd != null) {
      return ret..[_message] = 'A device by that name already exists.';
    }

    Uri uri;
    try {
      uri = Uri.parse(params[_addr]);
    } catch (e) {
      return ret..[_message] = 'Error parsing Address: $e';
    }

    var u = params[_user];
    var p = params[_pass];
    var cl = new VClient(uri, u, p);
    var res = await cl.authenticate();

    switch(res) {
      case AuthError.ok:
        ret..[_success] = true
          ..[_message] = 'Success!';
        nd = provider.addNode('/$name', DeviceNode.definition(uri, u, p));
        _link.save();
        break;
      case AuthError.notFound:
        ret[_message] = 'Unable to locate device parameters page. '
            'Possible invalid firmware version';
        break;
      case AuthError.auth:
        ret[_message] = 'Unable to authenticate with provided credentials';
        break;
      default:
        ret[_message] = 'Unknown error occured. Check log file for errors';
        break;
    }

    return ret;
  }
}

//* @Node
//* @MetaType DeviceNode
//* @Is deviceNode
//* @Parent root
//*
//* Root node of a device.
//*
//* Device node will contain the configuration information required to access
//* a device such as remote address and credentials. It will have the node name
//* specified when being added.
class DeviceNode extends SimpleNode implements Device {
  static const String isType = 'deviceNode';
  static Map<String, dynamic> definition(Uri uri, String user, String pass) => {
    r'$is': isType,
    _uri: uri.toString(),
    _user: user,
    _pass: pass,
    _params: {},
    'mjpgUrl' : {
      r'$name' : 'MJPEG URL',
      r'$type' : 'string',
      r'?value' : '${uri.toString()}/mjpg/video.mjpg',
    },
    EventsNode.pathName: EventsNode.definition(),
    EditDevice.pathName: EditDevice.definition(uri, user),
    RemoveDevice.pathName: RemoveDevice.definition()
  };

  static const String _user = r'$$ax_user';
  static const String _pass = r'$$password';
  static const String _uri = r'$$ax_uri';
  static const String _params = 'params';
  static const String _motion = 'Motion';

  void setDevice(AxisDevice dev) {
    if (_comp.isCompleted) return;
    _device = dev;
    _comp.complete(dev);
  }

  Future<AxisDevice> get device async {
    if (_device != null) return _device;
    return _comp.future;
  }

  Future<VClient> get client async {
    if (_cl != null) return _cl;
    return _clComp.future;
  }

  Completer<AxisDevice> _comp;
  Completer<VClient> _clComp;
  AxisDevice _device;
  VClient _cl;

  DeviceNode(String path) : super(path) {
    _comp = new Completer<AxisDevice>();
    _clComp = new Completer<VClient>();
  }

  @override
  void onCreated() {
    var u = getConfig(_user);
    var p = getConfig(_pass);
    var a = getConfig(_uri);

    Uri uri;
    try {
      uri = Uri.parse(a);
    } catch (e) {
      logger.warning('DeviceNode: Unable to parse uri "$a".', e);
      return;
    }

    _cl = new VClient(uri, u, p);
    _clComp.complete(_cl);

    _cl.authenticate().then((AuthError ae) {
      if (ae != AuthError.ok) return null;

      var dev = _cl.device;
      setDevice(dev);
      return dev;
    }).then((AxisDevice dev) {
      void genNodes(Map<String, dynamic> map, String path) {
        for (String key in map.keys) {
          var el = map[key];
          var nm = NodeNamer.createName(key);
          if (el is Map) {
            var nd = provider.getOrCreateNode('$path/$nm');
            genNodes(el, nd.path);
          } else {
            var nd = provider.getNode('$path/$nm');
            if (nd == null) {
              nd = provider.addNode('$path/$nm', ParamValue.definition(el));
            } else {
              nd.updateValue(el);
            }
          }
        }
      } // end genNodes

      var p = provider.getNode('$path/$_params');
      genNodes(dev.params.map, p.path);
      var mNode = provider.getNode('$path/$_params/$_motion');
      if (mNode == null) return;

      for (var p in mNode.children.keys) {
        provider.addNode('${mNode.path}/$p/${RemoveWindow.pathName}',
            RemoveWindow.definition());
      }
      provider.addNode('${mNode.path}/${AddWindow.pathName}',
          AddWindow.definition());
    });
  }

  Future<AuthError> updateConfig(Uri uri, String user, String pass) async {
    if (pass == null || pass.isEmpty) {
      pass = getConfig(_pass);
    }
    var res = await _cl.updateClient(uri, user, pass);
    if (res == AuthError.ok) {
      _cl = new VClient(uri, user, pass);
      configs[_uri] = uri.toString();
      configs[_user] = user;
      configs[_pass] = pass;
    }

    return res;
  }
}

//* @Action Edit_Device
//* @Is editDevice
//* @Parent DeviceNode
//*
//* Edit the device configuration.
//*
//* Edit the device configuration. It will verify that the new configuration
//* is valid.
//*
//* @Param address string The IP address of the remote device
//* @Param username string Username required to authenticate to the device.
//* @Param password string Password required to authenticate to the device.
//*
//* @Return value
//* @Column success bool Success returns true on success. False on failure.
//* @Column message string Message returns Success! on success, otherwise
//* it provides an error message.
class EditDevice extends SimpleNode {
  static const String isType = 'editDevice';
  static const String pathName = 'Edit_Device';

  static const String _addr = 'address';
  static const String _user = 'username';
  static const String _pass = 'password';
  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition(Uri uri, String user) => {
    r'$is' : isType,
    r'$name' : 'Edit Device',
    r'$invokable' : 'write',
    r'$params' : [
      {'name': _addr, 'type': 'string', 'default': uri.toString()},
      {'name': _user, 'type': 'string', 'placeholder': user},
      {'name': _pass, 'type': 'string', 'editor': 'password'}
    ],
    r'$columns' : [
      { 'name' : _success, 'type' : 'bool', 'default' : false },
      { 'name' : _message, 'type' : 'string', 'default': '' }
    ]
  };

  LinkProvider _link;

  EditDevice(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: false, _message: '' };

    Uri uri;
    try {
      uri = Uri.parse(params[_addr]);
    } catch (e) {
      return ret..[_message] = 'Error parsing Address: $e';
    }

    var u = params[_user];
    var p = params[_pass];
    var res = await (parent as DeviceNode).updateConfig(uri, u, p);

    switch(res) {
      case AuthError.ok:
        ret..[_success] = true
          ..[_message] = 'Success!';
        break;
      case AuthError.notFound:
        ret[_message] = 'Unable to locate device parameters page. '
            'Possible invalid firmware version';
        break;
      case AuthError.auth:
        ret[_message] = 'Unable to authenticate with provided credentials';
        break;
      default:
        ret[_message] = 'Unknown error occured. Check log file for errors';
        break;
    }

    return ret;
  }
}

//* @Action Remove_Device
//* @Is removeDevice
//* @Parent DeviceNode
//*
//* Removes the device from the link.
//*
//* Removes the device from the node tree, closing connection to remote server.
//* This action should always succeed.
//*
//* @Return value
//* @Column success bool Success returns true on success. False on failure.
//* @Column message bool Message returns "Success!" on success.
class RemoveDevice extends SimpleNode {
  static const String isType = 'removeDevice';
  static const String pathName = 'Remove_Device';

  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
    r'$is' : isType,
    r'$name' : 'Remove Device',
    r'$invokable' : 'write',
    r'$params' : [],
    r'$columns' : [
      { 'name' : _success, 'type' : 'bool', 'default' : false },
      { 'name' : _message, 'type' : 'string', 'default': '' }
    ]
  };

  LinkProvider _link;

  RemoveDevice(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = { _success: true, _message: 'Success!' };

    (parent as DeviceNode)._cl?.close();
    parent.remove();
    _link.save();

    return ret;
  }
}

