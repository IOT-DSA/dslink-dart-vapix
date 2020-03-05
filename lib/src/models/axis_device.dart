import 'ptz_commands.dart';
import 'device_leds.dart';

class AxisDevice {
  final Uri uri;
  Parameters params;
  List<CameraResolution> resolutions;
  List<PTZCameraCommands> ptzCommands;
  List<Led> leds;

  AxisDevice(this.uri, String pStr) {
    params = new Parameters(pStr);
  }

  AxisDevice cloneTo(AxisDevice dev) {
    dev..resolutions = resolutions
        ..ptzCommands = ptzCommands
        ..leds = leds;
    return dev;
  }

  AxisDevice._(this.uri, this.params, this.resolutions, this.ptzCommands, this.leds);

  factory AxisDevice.fromJson(Map<String, dynamic> map) {
    var u = Uri.parse(map['uri']);
    var p = new Parameters.fromJson(map['params']);

    var res = new List<CameraResolution>();
    if (map['resolutions'] != null) {
      for (var r in map['resolutions']) {
        res.add(new CameraResolution.fromJson(r));
      }
    }

    var ptzCmds = new List<PTZCameraCommands>();
    if (map['ptz'] != null) {
      for (var ptz in map['ptz']) {
        ptzCmds.add(new PTZCameraCommands.fromJson(ptz));
      }
    }

    List<Led> leds;
    var ledsJson = map['leds'] as List<Map<String, dynamic>>;
    if (ledsJson != null) {
      leds = new List<Led>();
      for (var led in ledsJson) {
        leds.add(new Led.fromJson(led));
      }
    }

    return new AxisDevice._(u, p, res, ptzCmds, leds);
  }

  Map<String, dynamic> toJson() => {
    'uri': uri.toString(),
    'params': params._map,
    'resolutions': resolutions?.map((CameraResolution res) => res.toJson())?.toList(),
    'ptz': ptzCommands?.map((PTZCameraCommands cmd) => cmd.toJson())?.toList(),
    'leds': leds?.map((Led l) => l.toJson())?.toList()
  };
}

class Parameters {
  Map<String, dynamic> _map = <String, dynamic>{};

  String get numSources => _map['ImageSource']['NbrOfSources'];
  String get resolutions => _map['Properties']['Image']['Resolution'];
  String get rotations => _map['Properties']['Image']['Rotation'];

  Parameters(String str) {
    var lines = str.split('\n');
    for (var s in lines) {
      var ind = s.indexOf('=');
      if (ind == -1) continue;
      var key = s.substring(0, ind);
      var val = s.substring(ind + 1, s.length);
      var keys = key.split('.').sublist(1);

      Map m = _map[keys[0]];
      if (m == null) {
        _map[keys[0]] = {};
        m = _map[keys[0]];
      }
      for (var i = 1; i < keys.length; i++) {
        var tmp = m[keys[i]];
        if (tmp == null) {
          if (i == keys.length - 1) {
            m[keys[i]] = val;
          } else {
            m[keys[i]] = {};
            m = m[keys[i]];
          }
        } else {
          m = tmp;
        }
      }
    }
  } // End constructor

  Parameters.fromJson(this._map);

  Map<String, dynamic> get map => _map;
}

class CameraResolution {
  final num width;
  final num height;
  final num camera;

  CameraResolution(this.camera, this.width, this.height);
  factory CameraResolution.fromJson(Map<String, num> map) {
    return new CameraResolution(map['camera'], map['width'], map['height']);
  }

  Map<String, num> toJson() => {
    'camera': camera,
    'width': width,
    'height': height
  };
}