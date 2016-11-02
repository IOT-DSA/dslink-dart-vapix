import "package:dslink/dslink.dart";

import "package:dslink_vapix/vapix.dart";

main(List<String> args) async {
  LinkProvider link;

  link = new LinkProvider(args, "Axis-", autoInitialize: false, profiles: {
    AddDevice.isType: (String path) => new AddDevice(path, link),
    DeviceNode.isType: (String path) => new DeviceNode(path),
    ParamValue.isType: (String path) => new ParamValue(path),
    RemoveDevice.isType: (String path) => new RemoveDevice(path, link),
    AddWindow.isType: (String path) => new AddWindow(path),
    RemoveWindow.isType: (String path) => new RemoveWindow(path),
    EventsNode.isType: (String path) => new EventsNode(path),
    EventSourceNode.isType: (String path) => new EventSourceNode(path),
    ActionRuleNode.isType: (String path) => new ActionRuleNode(path),
    ActionConfigNode.isType: (String path) => new ActionConfigNode(path)
  }, defaultNodes: {
    AddDevice.pathName: AddDevice.definition()
  });

  link.init();
  await link.connect();
}

