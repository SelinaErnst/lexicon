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
  ChDictionary dictionary = ChDictionary();
  dictionary.addSyntax(synatxMap, colorMap);
  await dictionary.read(File('assets/MCD.jsonl'), categories: catMap);
  /* –––––––––––––––––––––––– dictionary init ––––––––––––––––––––––– */

  // print(dictionary.getSlice(stop: 10));
  // final char = dictionary.search(pattern: 'ri4')[0];
  // print(char);
  // print(char.toMarkdownTable());
}
