import 'dart:async';

import '../../models.dart';

abstract class Device {
  Future<AxisDevice> get device;
  void setDevice(AxisDevice dev);
}
