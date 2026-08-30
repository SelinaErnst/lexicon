import 'package:suhan_lexicon/suhan_lexicon.dart';
import 'dart:io';

import '../test/helper.dart';

void main() async {
  /* ––––––––––––––––––––––– create dictionary –––––––––––––––––––––– */
  Dictionary dictionary = Dictionary(
    'Lexicon',
    baseCategories: ['word'],
    categories: {'translation': 'list'},
    characters: [
      {
        'word': 'test',
        'translation': ['Test'],
      },
      {
        'word': 'best',
        'translation': ['am besten', 'best', 'der/die/das Beste'],
      },
      {'word': 'dictionary', 'translation': 'Wörterbuch'},
    ],
    rules: [
      {'level': 'A1', 'title': 'Test WO', 'subtitle': 'rule about word order'},
      {
        'level': 'A1',
        'title': 'Test Verbs',
        'subtitle': 'rule about verb conjugation',
      },
    ],
  );
  /* ––––––––––––––––––––––– create dictionary –––––––––––––––––––––– */

  print(dictionary);
  print(dictionary.categories);
  print(dictionary.characters.toMarkdownTable());
  print(dictionary.rules.toMarkdownTable());

  /* ––––––––––––––––––––––––– config files ––––––––––––––––––––––––– */
  final categories = File('assets/categories.json');
  final dictFile = File('assets/MCD.jsonl');
  final ruleFile = File('assets/grammar.jsonl');
  /* ––––––––––––––––––––––––– config files ––––––––––––––––––––––––– */

  /* ––––––––––––––––––––– read dictionary file ––––––––––––––––––––– */
  ChDictionary chDictionary = ChDictionary('MCD');
  await chDictionary.readCategories(categories);
  await chDictionary.read(dictFile);
  await chDictionary.readRules(ruleFile);
  /* ––––––––––––––––––––– read dictionary file ––––––––––––––––––––– */

  print(chDictionary);
  print(chDictionary.getSlice(stop: 10).characters.toMarkdownTable());
  final char = chDictionary.search(pattern: 'ri').first;
  print(char);
  print(
    'Pinyin: ${char.toneMarkedPinyin}'
    '\nNumeric Pinyin: ${char.numericPinyin}',
  );
  print(char.toMarkdownTable());

  /* ––––––––––––––––––––––––– pleco format ––––––––––––––––––––––––– */
  TextModifier<String> mod = TextModifier(
    '',
    mapSyntax: getSyntax(),
    mapColor: getColors(),
    mapColorFav: getFaves(),
  );
  chDictionary.write(File('assets/MCD.txt'), mod: mod, template: File('assets/pleco.chd'));
  /* ––––––––––––––––––––––––– pleco format ––––––––––––––––––––––––– */
}
