import 'dart:io';
import 'package:suhan_lexicon/suhan_lexicon.dart';
import 'package:suhan_lexicon/src/utils.dart';

Map<String, dynamic> getSyntax() {
  return readJSONSync(File('assets/syntax.json'));
  // return readJSONSync(File('assets/syntax_help.json'));
}

Map<String, dynamic> getColors() {
  return readJSONSync(File('assets/colors.json'));
}

Map<String, dynamic> getFaves() {
  return readJSONSync(File('assets/named_colors.json'));
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
  final testfile = File('assets/test.json');
  await writeJsonToFile(categories, testfile);

  if (await testfile.exists()) await File('assets/test.json').delete();
  return dictionary;
}
