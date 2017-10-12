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
}

// just a list that also has access to the camera id
class PTZCameraCommands {
  final List<PTZCommand> commands;
  final int camera;

  PTZCameraCommands(this.commands, this.camera);
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
}