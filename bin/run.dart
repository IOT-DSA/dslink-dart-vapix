import "package:dslink/dslink.dart";

import "package:dslink_vapix/vapix.dart";

main(List<String> args) async {
  LinkProvider link;

  link = new LinkProvider(args, "Axis-", autoInitialize: false, profiles: {
    NoticeNode.isType: (String path) => new NoticeNode(path, link),
    ResolutionNode.isType: (String path) => new ResolutionNode(path),
    RefreshResolution.isType: (String path) => new RefreshResolution(path),
    NotificationNode.isType: (String path) => new NotificationNode(path),
    AddDevice.isType: (String path) => new AddDevice(path, link),
    DeviceNode.isType: (String path) => new DeviceNode(path, link),
    ParamsNode.isType: (String path) => new ParamsNode(path),
    ParamValue.isType: (String path) => new ParamValue(path),
    RemoveDevice.isType: (String path) => new RemoveDevice(path, link),
    AddWindow.isType: (String path) => new AddWindow(path, link),
    RemoveWindow.isType: (String path) => new RemoveWindow(path, link),
    EventsNode.isType: (String path) => new EventsNode(path),
    EventSourceNode.isType: (String path) => new EventSourceNode(path),
    AddActionRule.isType: (String path) => new AddActionRule(path, link),
    ActionRuleNode.isType: (String path) => new ActionRuleNode(path),
    RemoveActionRule.isType: (String path) => new RemoveActionRule(path, link),
    AddActionConfig.isType: (String path) => new AddActionConfig(path, link),
    ActionConfigNode.isType: (String path) => new ActionConfigNode(path),
    ReconnectDevice.isType: (String path) => new ReconnectDevice(path),
    RefreshActions.isType: (String path) => new RefreshActions(path),
    RefreshDevice.isType: (String path) => new RefreshDevice(path),
    RemoveActionConfig.isType: (String path) =>
        new RemoveActionConfig(path, link)
  }, defaultNodes: {
    NoticeNode.pathName: NoticeNode.definition(),
    AddDevice.pathName: AddDevice.definition()
  });

  link.init();
  await link.connect();
}

