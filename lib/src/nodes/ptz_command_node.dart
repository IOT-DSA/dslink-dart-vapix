import 'dart:async';

import 'common.dart';
import 'package:dslink/dslink.dart';

import '../../models.dart';

class PTZCommandNode extends ChildNode {
  static const String isType = 'ptzCommandNode';

  static Map<String, dynamic> defFactory(PTZCameraCommands commands) {
    Map map = {
      r"$is": "node",
      r"$name": commands.camera
    };

    commands.commands.forEach((command) {
      List<dynamic> params = [];

      command.parameters.forEach((param) {
        if (param.type == PTZCommandParamType.ENUM) {
          // enum
          params.add({
            "name": param.name,
            "type": buildEnumType(param.enumValues)
          });
        } else {
          // value
          params.add({
            "name": param.name,
            "type": "string"
          });
        }
      });

      command.subCommands.forEach((subCommand) {
        // TODO: Don't think this happens in practice right now...
        if (subCommand.parameters.length > 1 ||
            subCommand.parameters.first.type == PTZCommandParamType.ENUM) {
          return;
        }

        params.add({
          "name": subCommand.name,
          "type": "string",
          "default": ""
        });
      });

      map[command.name] = {
        r"$is": PTZCommandNode.isType,
        r"$name": command.name,
        r"$invokable": "write",
        r'$params': params,
        r'$columns': [
          {"name": "success", "type": "bool", "default": false},
          {'name': "message", 'type': 'string', 'default': ''}
        ],
        r"$$parameters": command.parameters.map((param) => param.name).join(","),
        r"$$subcommands": command.subCommands.map((subCommand) => subCommand.name).join(",")
      };
    });

    return map;
  }

  PTZCommandNode(String path) : super(path);

  @override
  Future<Map<String, dynamic>> onInvoke(Map<String, dynamic> params) async {
    var client = await getClient();

    List<String> commandParams = this.configs[r"$$parameters"].toString().split(",");
    Map<String, String> queryParams = {
      this.name: commandParams.map((param) => params[param]).join(",")
    };

    List<String> subCommands = this.configs[r"$$subcommands"].toString().split(",");
    for (String subCommand in subCommands) {
      if (params.containsKey(subCommand)) {
        queryParams[subCommand] = params[subCommand];
      }
    }
    
    try {
      await client.runPtzCommand(int.parse(this.parent.name), queryParams);
      return { "success": true, "message": "ok" };
    }
    catch(e) {
      return { "success": false, "message": e.toString() };
    }
  }
}