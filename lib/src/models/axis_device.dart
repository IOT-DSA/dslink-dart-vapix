class AxisDevice {
  final Uri uri;

  Parameters params;

  AxisDevice(this.uri, String pStr) {
    params = new Parameters(pStr);
  }
}

class Parameters {
  Map<String, dynamic> _map = <String, dynamic>{};

  String get numSources => _map['ImageSource']['NbrOfSources'];

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

  }

  Map<String, dynamic> get map => _map;
}

class CameraResolution {
  final num width;
  final num height;
  final num camera;

  CameraResolution(this.camera, this.width, this.height);
}