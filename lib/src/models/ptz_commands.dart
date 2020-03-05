enum PTZCommandParamType {
  VALUE,
  ENUM
}

class PTZCommandParameter {
  final String name;

  final PTZCommandParamType type;
  // only needed if type == ENUM
  final List<String> enumValues;
  
  PTZCommandParameter(this.name, this.type, {this.enumValues : const []});

  factory PTZCommandParameter.fromJson(Map<String, dynamic> map) {
    var t = PTZCommandParamType.values[map['type']];
    return new PTZCommandParameter(map['name'], t, enumValues: map['values']);
  }
  
  Map<String, dynamic> toJson() => {
    'name': name,
    'type': type.index,
    'values': enumValues
  };
}

// just a list that also has access to the camera id
class PTZCameraCommands {
  final List<PTZCommand> commands;
  final int camera;

  PTZCameraCommands(this.commands, this.camera);

  factory PTZCameraCommands.fromJson(Map<String, dynamic> map) {
    var camId = map['camera'];

    List<PTZCommand> cmds =  new List<PTZCommand>();
    for (var cm in (map['commands'] as List<Map<String, dynamic>>)) {
      cmds.add(new PTZCommand.fromJson(cm));
    }

    return new PTZCameraCommands(cmds, camId);
  }

  Map<String, dynamic> toJson() => {
    'camera': camera,
    'commands': commands.map((PTZCommand cmd) => cmd.toJson()).toList()
  };
}

class PTZCommand {
  final String name;

  final List<PTZCommandParameter> parameters;
  final List<PTZCommand> subCommands;
  
  PTZCommand(this.name, this.parameters,
      { this.subCommands: const [] });

  factory PTZCommand.fromStrings(List<String> arr) {
    if (arr.isEmpty) {
      return null;
    }

    String name;
    List<PTZCommandParameter> parameters = [];
    List<PTZCommand> subCommands = [];

    // parse name 

    String str = arr.first.trim();
    var i = str.indexOf("=");
    if (i < 0) {
      throw new StateError("ptz command value no equals sign");
    }

    name = str.substring(0, i);
    
    // parse parameters
    
    String strValue = str.substring(i + 1);
    parameters.addAll(strValue.split(",").map((str) {
      str = str.trim();

      if (str.startsWith("{")) {
        List<String> enumValues = str
            .substring(1, str.length - 1)
            .split("|")
            .map((part) => part.trim())
            .toList();

        return new PTZCommandParameter("value", PTZCommandParamType.ENUM, enumValues: enumValues);
      } else if (str.startsWith("[")) {
        String name = str.substring(1, str.length - 1).trim();
        return new PTZCommandParameter(name, PTZCommandParamType.VALUE);
      }

      throw new StateError("ptz command value invalid syntax");
    }));

    // parse sub commands

    if (arr.length > 1) {
      arr.sublist(1).forEach((substr) {
        PTZCommand subCommand = new PTZCommand.fromStrings([substr]);
        if (subCommand != null) {
          subCommands.add(subCommand);
        }
      });
    }

    return new PTZCommand(name, parameters, subCommands: subCommands);
  }

  factory PTZCommand.fromJson(Map<String, dynamic> map) {
    List<PTZCommandParameter> params = new List<PTZCommandParameter>();
    for (var p in (map['params'] as List<Map<String, dynamic>>)) {
      params.add(new PTZCommandParameter.fromJson(p));
    }

    List<PTZCommand> sub = new List<PTZCommand>();
    for (var sc in (map['commands'] as List<Map<String, dynamic>>)) {
      sub.add(new PTZCommand.fromJson(sc));
    }

    return new PTZCommand(map['name'], params, subCommands: sub);
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'params': parameters.map((PTZCommandParameter cp) => cp.toJson()).toList(),
    'commands': subCommands.map((PTZCommand c) => c.toJson()).toList()
  };
}