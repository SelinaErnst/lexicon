import 'package:lexicon/lexicon/dictionary.dart';
import 'package:lexicon/lexicon/utils.dart';
import 'package:test/test.dart';
import 'dart:io';

void main() async {
  final String pathDictionaryJSONL =
      '/home/selina/Applications/MyApps/suhan/packages/lexicon/assets/MCD.jsonl';
  final String pathSyntaxMap =
      '/home/selina/Applications/MyApps/suhan/packages/lexicon/assets/syntax.json';
  final String pathColorMap =
      '/home/selina/Applications/MyApps/suhan/packages/lexicon/assets/colors.json';
  final String pathCategoryMap =
      '/home/selina/Applications/MyApps/suhan/packages/lexicon/assets/categories.json';
  Map<String, dynamic> synatxMap = readJSONSync(File(pathSyntaxMap))!;
  Map<String, dynamic> colorMap = readJSONSync(File(pathColorMap))!;
  Map<String, dynamic> catMap = readJSONSync(File(pathCategoryMap))!;
  Dictionary dictionary = Dictionary();
  dictionary.addSyntax(synatxMap, colorMap);
  await dictionary.read(File(pathDictionaryJSONL), categories: catMap);
  test('create dictionary of characters', () async {
    expect(dictionary.isNotEmpty, true);
    print(dictionary);
  });
}
