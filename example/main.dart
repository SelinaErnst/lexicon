import 'package:lexicon/lexicon/dictionary.dart';
import 'package:lexicon/lexicon/utils.dart';
import 'dart:io';

void main() async {
  /* ––––––––––––––––––––––––– config files ––––––––––––––––––––––––– */
  final synatxMap = readJSONSync(File('assets/syntax.json'))!;
  final colorMap = readJSONSync(File('assets/colors.json'))!;
  final catMap = readJSONSync(File('assets/categories.json'))!;
  /* ––––––––––––––––––––––––– config files ––––––––––––––––––––––––– */

  /* –––––––––––––––––––––––– dictionary init ––––––––––––––––––––––– */
  Dictionary dictionary = Dictionary();
  dictionary.addSyntax(synatxMap, colorMap);
  await dictionary.read(File('assets/MCD.jsonl'), categories: catMap);
  /* –––––––––––––––––––––––– dictionary init ––––––––––––––––––––––– */

  print(dictionary[List.generate(10, (index) => index)]);
  dictionary['ri4'][0].info();
}
