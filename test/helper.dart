import 'dart:io';
import 'package:lexicon/lexicon.dart';
import 'package:lexicon/src/utils.dart';

Map<String, dynamic> getSyntax() {
  return readJSONSync(File('assets/syntax.json'));
  // return readJSONSync(File('assets/syntax_help.json'));
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

Future<Dictionary> getExample() async {
  final syntax = getSyntax();
  final colors = getColors();
  final faves = getFaves();
  final categories = getCategories();
  Dictionary dictionary = ChDictionary('MCD');
  dictionary.addSyntax(syntax, colors, mapColorFav: faves);
  await dictionary.read(File('assets/MCD.jsonl'), categories: categories);
  return dictionary;
}
