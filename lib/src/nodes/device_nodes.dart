import 'dart:async';

import 'package:dslink/dslink.dart';
import 'package:dslink/nodes.dart' show NodeNamer;
import 'package:dslink/utils.dart' show logger;

import 'common.dart';
import 'events_node.dart';
import 'param_value.dart';
import 'window_commands.dart';
import 'camera_resolution.dart';
import 'ptz_command_node.dart';
import 'device_leds.dart';
import 'virtual_ports.dart';
import '../client.dart';
import '../../models.dart';

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
  static const String _sec = 'secure';
  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition() => {
        r'$is': isType,
        r'$name': 'Add Device',
        r'$invokable': 'write',
        r'$params': [
          {'name': _name, 'type': 'string', 'placeholder': 'Device Name'},
          {
            'name': _addr,
            'type': 'string',
            'placeholder': 'http://<ipaddress>'
          },
          {'name': _user, 'type': 'string', 'placeholder': 'Username'},
          {'name': _pass, 'type': 'string', 'editor': 'password'},
          {'name': _sec, 'type': 'bool', 'default': true}
        ],
        r'$columns': [
          {'name': _success, 'type': 'bool', 'default': false},
          {'name': _message, 'type': 'string', 'default': ''}
        ]
      };

  LinkProvider _link;

  AddDevice(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = {_success: false, _message: ''};

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
    var s = params[_sec] as bool;
    var cl = new VClient(uri, u, p, s);
    var res = await cl.authenticate();

    switch (res) {
      case AuthError.ok:
        ret
          ..[_success] = true
          ..[_message] = 'Success!';
        nd = provider.addNode('/$name', DeviceNode.definition(uri, u, p, s));
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
  static Map<String, dynamic> definition(
          Uri uri, String user, String pass, bool sec) =>
      {
        r'$is': isType,
        _uri: uri.toString(),
        _user: user,
        _pass: pass,
        _sec: sec,
        _disconnected: {
          r'$type': 'bool',
          r'?value': false
        },
        //* @Node params
        //* @Parent DeviceNode
        //*
        //* Collection of ParamValues on the device. The link will automatically
        //* create a tree based on the configuration tree of the device.
        ParamsNode.pathName: ParamsNode.def(),
        //* @Node mjpgUrl
        //* @Parent DeviceNode
        //*
        //* MJPEG Url of the remote device.
        //*
        //* @Value string
        _mjpgUrl: {
          r'$name': 'MJPEG URL',
          r'$type': 'string',
          r'?value': '${uri.toString()}/mjpg/video.mjpg',
        },
        EventsNode.pathName: EventsNode.definition(),
        EditDevice.pathName: EditDevice.definition(uri, user, sec),
        RemoveDevice.pathName: RemoveDevice.definition(),
        RefreshDevice.pathName: RefreshDevice.def(),
        ReconnectDevice.pathName: ReconnectDevice.def(),
        VirtualPortTrigger.pathName: VirtualPortTrigger.def()
      };

  static const String _user = r'$$ax_user';
  static const String _pass = r'$$password';
  static const String _uri = r'$$ax_uri';
  static const String _sec = r'$$ax_secure';
  static const String _motion = 'Motion';
  static const String _mjpgUrl = 'mjpgUrl';
  static const String _Leds = 'LEDs';
  static const String _disconnected = 'Disconnected';

  void setDevice(AxisDevice dev) {
    _device = dev;
    if (_comp.isCompleted) return;
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
  final LinkProvider link;

  DeviceNode(String path, this.link) : super(path) {
    _comp = new Completer<AxisDevice>();
    _clComp = new Completer<VClient>();
  }

  @override
  void onCreated() {
    _populateMissing();

    var u = getConfig(_user);
    var p = getConfig(_pass);
    var a = getConfig(_uri);
    var s = getConfig(_sec) as bool;

    Uri uri;
    try {
      uri = Uri.parse(a);
    } catch (e) {
      logger.warning('DeviceNode: Unable to parse uri "$a".', e);
      return;
    }

    _cl = new VClient(uri, u, p, s);
    _cl.onDisconnect = _onDisconnect;

    _cl.authenticate().then((AuthError ae) {
      if (ae != AuthError.ok) return null;

      _clComp.complete(_cl);
      setDevice(_cl.device);

      var evntNode = provider.getNode('$path/${EventsNode.pathName}') as EventsNode;
      evntNode.updateEvents();

      _cl.getResolutions().then(_populateResolution);

      if (_cl.supportsPTZ()) {
        _cl.getPTZCommands().then(_populatePTZNodes);
      }
      _cl.hasLedControls().then((bool hasControls) {
        if (hasControls) return _cl.getLeds();
      }).then(_populateLeds);

      return _cl.device;
    }).then(_populateNodes);
  }

  void _populateMissing() {
    CheckNode(provider, '$path/${ReconnectDevice.pathName}',
        ReconnectDevice.def());

    CheckNode(provider, '$path/${ParamsNode.pathName}', ParamsNode.def());
    CheckNode(provider, '$path/${RefreshDevice.pathName}', RefreshDevice.def());

    CheckNode(provider, '$path/${VirtualPortTrigger.pathName}',
        VirtualPortTrigger.def());

    CheckNode(provider, '$path/$_disconnected',
        {r'$name': 'Disconnected', r'$type': 'bool', r'?value': false});

    CheckNode(provider, '$path/${CheckConnection.pathName}',
        CheckConnection.def());
  }

  void _populateLeds(List<Led> leds) {
    if (leds == null || leds.isEmpty) return;
    var ledNodes = provider.getOrCreateNode('$path/$_Leds');

    for (var l in leds) {
      var nm = NodeNamer.createName(l.name);
      var lNode = provider.getNode('${ledNodes.path}/$nm') as SimpleNode;
      if (lNode != null) lNode.remove();

      lNode = provider.getOrCreateNode('${ledNodes.path}/$nm');
      provider.addNode('${lNode.path}/${SetLed.pathName}', SetLed.def(l));
    }
  }

  void _populateResolution(List<CameraResolution> resolutions) {
    var resNode = provider.getOrCreateNode('$path/resolution');

    var refreshNd =
        provider.getNode('${resNode.path}/${RefreshResolution.pathName}');

    if (refreshNd == null) {
      provider.addNode('${resNode.path}/${RefreshResolution.pathName}',
          RefreshResolution.def());
    }

    for (var res in resolutions) {
      provider.addNode(
          '${resNode.path}/${res.camera}', ResolutionNode.def(res));
    }
  }

  void _populatePTZNodes(List<PTZCameraCommands> commandsList) {
    var ptzNode = provider.getOrCreateNode('$path/ptz');

    for (PTZCameraCommands commands in commandsList) {
      var cameraNode = provider.getNode('${ptzNode.path}/${commands.camera}');

      if (cameraNode == null) {
        provider.addNode("${ptzNode.path}/${commands.camera}", PTZCommandNode.defFactory(commands));
      }
    }
  }

  void _populateNodes(AxisDevice dev) {
    if (dev == null) return;

    void genNodes(Map<String, dynamic> map, String path) {
      for (String key in map.keys) {
        var el = map[key];
        var nm = NodeNamer.createName(key);
        if (el is Map<String, dynamic>) {
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

    var p = provider.getNode('$path/${ParamsNode.pathName}');
    if (p == null) {
      throw new StateError('Unable to locate parameters node');
    }
    var chd = p.children.values.toList();
    for (var c in chd) {
      if (c is SimpleNode) c.remove();
    }

    genNodes(dev.params.map, p.path);
    //* @Node Motion
    //* @Parent params
    //*
    //* Collection of Motion detection related parameters.
    var mNode =
        provider.getOrCreateNode('$path/${ParamsNode.pathName}/$_motion');
    if (mNode == null) return;

    //* @Node MotionWindow
    //* @Parent Motion
    //*
    //* Collection of ParamValues that make up the Motion Window.
    for (var p in mNode.children.keys) {
      provider.addNode('${mNode.path}/$p/${RemoveWindow.pathName}',
          RemoveWindow.definition());
    }
    provider.addNode(
        '${mNode.path}/${AddWindow.pathName}', AddWindow.definition());

    link.save();
  }

  Future<AuthError> updateConfig(
      Uri uri, String user, String pass, bool secure) async {
    if (pass == null || pass.isEmpty) {
      pass = getConfig(_pass);
    }
    var res = await _cl.updateClient(uri, user, pass, secure);

    if (res == AuthError.ok) {
      _cl = new VClient(uri, user, pass, secure);
      _cl.onDisconnect = _onDisconnect;
      configs[_uri] = uri.toString();
      configs[_user] = user;
      configs[_pass] = pass;
      configs[_sec] = secure;
      updateList(r'$is');
      setDevice(_cl.device);
      _populateNodes(_device);
      var mjpgUrlNd = provider.getNode('$path/$_mjpgUrl');
      mjpgUrlNd?.updateValue('${uri.toString()}/mjpg/video.mjpg');
    }

    return res;
  }

  Future<AuthError> reconnect() async {
    var res = await _cl.reconnect();
    if (res == AuthError.ok) {
      setDevice(_cl.device);
      _populateNodes(_device);
    }

    return res;
  }

  void _onDisconnect(bool disconnected) {
    provider.updateValue('$path/$_disconnected', disconnected);
    if (!disconnected) {
      children.values.where((nd) => nd is ChildNode).forEach((ChildNode nd) {
        nd.disconnected = null;
      });
    } else {
      children.values
          .where((nd) => nd is ChildNode && nd.disconnected == null)
          .forEach((nd) {
        (nd as ChildNode).disconnected = ValueUpdate.getTs();
      });
    }
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
  static const String _sec = 'secure';
  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> definition(Uri uri, String user, bool sec) => {
        r'$is': isType,
        r'$name': 'Edit Device',
        r'$invokable': 'write',
        r'$params': [
          {'name': _addr, 'type': 'string', 'default': uri.toString()},
          {'name': _user, 'type': 'string', 'placeholder': user},
          {'name': _pass, 'type': 'string', 'editor': 'password'},
          {'name': _sec, 'type': 'bool', 'default': sec}
        ],
        r'$columns': [
          {'name': _success, 'type': 'bool', 'default': false},
          {'name': _message, 'type': 'string', 'default': ''}
        ]
      };

  LinkProvider _link;

  EditDevice(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = {_success: false, _message: ''};

    Uri uri;
    try {
      uri = Uri.parse(params[_addr]);
    } catch (e) {
      return ret..[_message] = 'Error parsing Address: $e';
    }

    var u = params[_user];
    var p = params[_pass];
    var s = params[_sec];
    var res = await (parent as DeviceNode).updateConfig(uri, u, p, s);

    switch (res) {
      case AuthError.ok:
        configs[r'$params'] = [
          {'name': _addr, 'type': 'string', 'default': uri.toString()},
          {'name': _user, 'type': 'string', 'placeholder': u},
          {'name': _pass, 'type': 'string', 'editor': 'password'},
          {'name': _sec, 'type': 'bool', 'default': s}
        ];
        ret
          ..[_success] = true
          ..[_message] = 'Success!';
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
        r'$is': isType,
        r'$name': 'Remove Device',
        r'$invokable': 'write',
        r'$params': [],
        r'$columns': [
          {'name': _success, 'type': 'bool', 'default': false},
          {'name': _message, 'type': 'string', 'default': ''}
        ]
      };

  LinkProvider _link;

  RemoveDevice(String path, this._link) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = {_success: true, _message: 'Success!'};

    (parent as DeviceNode)._cl?.clearConn();
    parent.remove();
    _link.save();

    return ret;
  }
}

class ReconnectDevice extends SimpleNode {
  static const String isType = 'reconnectDevice';
  static const String pathName = 'reconnect';

  static Map<String, dynamic> def() => {
        r'$is': isType,
        r'$name': 'Reconnect Device',
        r'$invokable': 'write',
        r'$params': [],
        r'$columns': [
          {'name': _success, 'type': 'bool', 'default': false},
          {'name': _message, 'type': 'string', 'default': ''}
        ]
      };

  static const String _success = 'success';
  static const String _message = 'message';

  ReconnectDevice(String path) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    var ret = {_success: false, _message: ''};

    var res = await (parent as DeviceNode).reconnect();
    switch (res) {
      case AuthError.ok:
        ret[_success] = true;
        break;
      default:
        ret..[_success] = false
        ..[_message] = 'Failed to authenticate. Please check logs';
    }

    return ret;
  }
}

class RefreshDevice extends SimpleNode {
  static const String isType = 'refreshDevice';
  static const String pathName = 'Refresh_Device';

  static const String _success = 'success';
  static const String _message = 'message';

  static Map<String, dynamic> def() => {
        r'$is': isType,
        r'$name': 'Refresh Device',
        r'$invokable': 'write',
        r'$params': [],
        r'$columns': [
          {'name': _success, 'type': 'bool', 'default': false},
          {'name': _message, 'type': 'string', 'default': ''}
        ]
      };

  RefreshDevice(String path) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    final ret = {_success: true, _message: 'Success!'};

    var p = parent as DeviceNode;
    var cl = p._cl;
    if (cl == null) cl = await p.client;

    var futs = [];
    var eventsNd =
        provider.getNode('${p.path}/${EventsNode.pathName}') as EventsNode;

    if (eventsNd == null) {
      return ret..[_message] = 'Unable to locate events node';
    }

    futs.add(eventsNd.updateEvents());
    futs.add(cl.authenticate(force: true).then((AuthError auth) {
      if (auth != AuthError.ok) {
        ret
          ..[_message] = 'Failed to authenticate'
          ..[_success] = false;
        return;
      }

      var dev = cl.device;
      p._populateNodes(dev);
    }));

    await Future.wait(futs);

    return ret;
  }
}

//* @Action Check_Connection
//* @Is checkConnection
//* @Parent DeviceNode
//*
//* Performs a quick test of the connection to the selected device.
//*
//* This will perform a quick test of the connection to the camera, no more than
//* approximately 5 seconds. To verify that the device is online. This action
//* will throw an error if it is unable to connect to the camera.
class CheckConnection extends ChildNode {
  static const String isType = 'checkConnection';
  static const String pathName = 'Check_Connection';

  static const String _success = 'success';

  static Map<String, dynamic> def() => {
    r'$is': isType,
    r'$name': 'Check Connection',
    r'$invokable': 'write',
    r'$params': [],
    r'$columns': [
      {'name': _success, 'type': 'bool', 'default': false}
    ]
  };

  CheckConnection(String path) : super(path);

  @override
  Future<Map<String, bool>> onInvoke(Map<String, dynamic> params) async {
    var client = await getClient();
    bool ok = false;
    try {
      ok = await client.checkConnection();
    } catch (e) {
      throw new Exception('Failed to connect to device.');
    }

    return {_success: ok};
  }
}