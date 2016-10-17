import "package:dslink/dslink.dart";

import "package:dslink_vapix/vapix.dart";

main(List<String> args) async {
    LinkProvider link;

    link = new LinkProvider(args, "Axis-", autoInitialize: false, profiles: {

    }, defaultNodes: {

    });

    link.init();
    await link.connect();
}

