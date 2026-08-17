import 'package:lexicon/lexicon/dictionary.dart';
import 'package:lexicon/lexicon/utils.dart';
import 'package:test/test.dart';
import 'dart:io';

void main() async {
  final synatxMap = readJSONSync(File('assets/syntax.json'))!;
  final colorMap = readJSONSync(File('assets/colors.json'))!;
  final catMap = readJSONSync(File('assets/categories.json'))!;
  Dictionary dictionary = Dictionary();
  dictionary.addSyntax(synatxMap, colorMap);
  await dictionary.read(File('assets/MCD.jsonl'), categories: catMap);
  test('create dictionary of characters', () async {
    expect(dictionary.isNotEmpty, true);
    List<int> numbers = List.generate(10, (index) => index);
    print(dictionary[List.generate(10, (index) => index)]);
  });

  test('examine character in dictionary', () async {
    print(dictionary['ri4'][0].info());
  });
}
