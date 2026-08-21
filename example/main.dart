import 'package:lexicon/lexicon/dictionary.dart';
import 'package:lexicon/lexicon/utils.dart';
import 'dart:io';

void main() async {
  /* ––––––––––––––––––––––––– config files ––––––––––––––––––––––––– */
  final synatxMap = readJSONSync<Map<String, dynamic>>(
    File('assets/syntax.json'),
  );
  final colorMap = readJSONSync<Map<String, dynamic>>(
    File('assets/colors.json'),
  );
  final catMap = readJSONSync<Map<String, dynamic>>(
    File('assets/categories.json'),
  );
  /* ––––––––––––––––––––––––– config files ––––––––––––––––––––––––– */

  /* –––––––––––––––––––––––– dictionary init ––––––––––––––––––––––– */
  Dictionary dictionary = ChDictionary();
  dictionary.addSyntax(synatxMap, colorMap);
  await dictionary.read(File('assets/MCD.jsonl'), categories: catMap);
  /* –––––––––––––––––––––––– dictionary init ––––––––––––––––––––––– */

  // print(dictionary.getSubset(List.generate(10, (index) => index)));
  // print(dictionary.getCharacter(['八','','ba1']));
  // print(dictionary.getCharacter(Character()));
}
