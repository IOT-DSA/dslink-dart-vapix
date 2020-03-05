import 'dart:async';
import 'dart:io';

import "package:dslink/dslink.dart";
import 'package:dslink/utils.dart' show logger;


import "package:dslink_vapix/vapix.dart";
import "package:dslink_vapix/src/client.dart" show context;

main(List<String> args) async {
  LinkProvider link;

  checkSsl();

  link = new LinkProvider(args, "Axis-", autoInitialize: false, profiles: {
    NoticeNode.isType: (String path) => new NoticeNode(path, link),
    NotificationNode.isType: (String path) => new NotificationNode(path),
    RemoveNotification.isType: (String path) => new RemoveNotification(path, link),
    ResolutionNode.isType: (String path) => new ResolutionNode(path),
    RefreshResolution.isType: (String path) => new RefreshResolution(path, link),
    PTZCommandNode.isType: (String path) => new PTZCommandNode(path),
    AddDevice.isType: (String path) => new AddDevice(path, link),
    DeviceNode.isType: (String path) => new DeviceNode(path, link),
    ParamsNode.isType: (String path) => new ParamsNode(path),
    ParamValue.isType: (String path) => new ParamValue(path),
    EditDevice.isType: (String path) => new EditDevice(path, link),
    RemoveDevice.isType: (String path) => new RemoveDevice(path, link),
    ResetDevice.isType: (String path) => new ResetDevice(path, link),
    AddWindow.isType: (String path) => new AddWindow(path, link),
    RemoveWindow.isType: (String path) => new RemoveWindow(path, link),
    EventsNode.isType: (String path) => new EventsNode(path, link),
    EventSourceNode.isType: (String path) => new EventSourceNode(path),
    AddActionRule.isType: (String path) => new AddActionRule(path, link),
    AddVirtualRule.isType: (String path) => new AddVirtualRule(path, link),
    ActionRuleNode.isType: (String path) => new ActionRuleNode(path),
    RemoveActionRule.isType: (String path) => new RemoveActionRule(path, link),
    AddActionConfig.isType: (String path) => new AddActionConfig(path, link),
    ActionConfigNode.isType: (String path) => new ActionConfigNode(path),
    ReconnectDevice.isType: (String path) => new ReconnectDevice(path),
    RefreshActions.isType: (String path) => new RefreshActions(path, link),
    RefreshDevice.isType: (String path) => new RefreshDevice(path),
    CheckConnection.isType: (String path) => new CheckConnection(path),
    RemoveActionConfig.isType: (String path) =>
        new RemoveActionConfig(path, link),
    SetLed.isType: (String path) => new SetLed(path),
    VirtualPortTrigger.isType: (String path) => new VirtualPortTrigger(path),
    AddStream.isType: (String path) => new AddStream(path, link),
    RemoveStream.isType: (String path) => new RemoveStream(path, link)
  }, defaultNodes: {
    NoticeNode.pathName: NoticeNode.definition(),
    AddDevice.pathName: AddDevice.definition()
  });

  link.init();
  await link.connect();
}

void checkSsl() {
  String certPath = Directory.current.path;
  if (Platform.isWindows) {
    certPath += r'\';
  } else {
    certPath += r'/';
  }
  certPath += 'certs';

  Directory certsDir = new Directory(certPath);
  if (!certsDir.existsSync()) return;

  var files = certsDir.listSync();
  if (files.isEmpty) return;

  var con = new SecurityContext();
  for (var f in files) {
    try {
      con.setTrustedCertificates(f.path);
      logger.info('Imported certificate: ${f.path}');
    } catch (e) {
      logger.warning('Failed to import certificate: ${f.path}', e);
    }
  }

  context = con;
}
