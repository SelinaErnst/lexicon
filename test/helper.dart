import 'dart:io';
import 'package:lexicon/lexicon/utils.dart';

Map<String, dynamic> getSyntax() {
  return readJSONSync(File('assets/syntax.json'));
}

Map<String, dynamic> getColors() {
  return readJSONSync(File('assets/colors.json'));
}

Map<String, dynamic> getFaves() {
  return {
    "blue": "Dodger Blue",
    "teal": "Strong Blue",
    "green": "Cyan Blue",
    "grey": "Light Slate Gray",
  };
}

Map<String, dynamic> getCategories() {
  return readJSONSync(File('assets/categories.json'));
}
