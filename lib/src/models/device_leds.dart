import 'package:xml/xml.dart' as xml;

class Led {
  List<Color> colors;
  String name;

  Led.fromXml(xml.XmlElement el) {
    var nEl = el.findElements('LedName')?.first;
    if (nEl == null) throw new FormatException('No "LedName" specified.');
    name = nEl.text;

    var cEls = el.findElements('Color');
    colors = new List<Color>();
    cEls.forEach((xml.XmlElement el) {
      colors.add(new Color.fromXml(el));
    });
  }
}

class Color {
  String name;
  bool userControllable;

  Color.fromXml(xml.XmlElement el) {
    var cEl = el.findElements('ColorName')?.first;
    if (cEl == null) {
      throw new FormatException('No "ColorName" specified for color');
    }

    name = cEl.text;
    var uc = el.findElements('UserControllable')?.first?.text;
    userControllable = uc == 'true';
  }
}