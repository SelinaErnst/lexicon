import 'package:suhan_lexicon/src/dictionary.dart';
import 'package:suhan_lexicon/src/rule.dart';
import 'package:suhan_lexicon/src/errors.dart';
import 'package:suhan_lexicon/src/character.dart';
import 'package:suhan_lexicon/src/sentence.dart';
import 'package:suhan_lexicon/src/text_modifier.dart';
import 'package:test/test.dart';
import 'package:logging/logging.dart';
import 'package:collection/collection.dart';
import 'helper.dart';

void main() {
  /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

  group('Rule', () {
    late ChRule empty;
    late ChRule filled;
    late ChRule rule;
    late TextModifier<dynamic> modText;

    setUpAll(() {
      Logger.root.clearListeners();
      Logger.root.onRecord.listen((record) {
        print(
          '[${record.level.name}] (${record.loggerName}): ${record.message}',
        );
      });

      final syntax = getSyntax();
      final colors = getColors();
      final favColors = getFaves();
      modText = TextModifier('');
      modText.addSyntax(
        mapSyntax: syntax,
        mapColor: colors,
        mapColorFav: favColors,
      );
    });

    setUp(() {
      Logger.root.level = Level.OFF;
      empty = ChRule();
      rule = ChRule(
        entry: {
          'title': ' ABER ich Mag Dich  ',
          'subtitle': ' a ',
          'sentences': [
            {'text': ' 我去学校. ', 'pinyin': 'wo3'},
            {'sc': 's'},
          ],
          'characters': [
            {'simplified': '_x_x'},
            {'pinyin': 'y'},
            {'sc': 'y'},
          ],
          'charactersOpp': [
            {'simplified': 'a', 'pinyin': 'b'},
          ],
        },
      );
      filled = ChRule(
        entry: {
          'level': '',
          'title': '',
          'subtitle': '',
          'sentences': [
            {'text': ''},
            {'sc': 's'},
          ],
          'characters': [
            {'simplified': '', 'pinyin': '', 'test': 'a'},
          ],
        },
      );
    });

    group('Rule attributes', () {
      test('Rule', () {
        final entry = {
          'level': 'A1',
          'title': 'Test',
          'subtitle': '',
          'sentences': [
            {'text': ' 我去学校. ', 'pinyin': 'wo3'},
            {'text': ''},
          ],
          'characters': [
            {'simplified': '我', 'pinyin': 'wo3', 'test': 'a'},
          ],
        };
        Rule r = Rule(
          connection: Character(baseCategories: ['ID'], entry: {'ID': 'test'}),
        );
        r = Rule(
          connection: Character(
            baseCategories: ['simplified', 'traditional', 'pinyin'],
          ),
          entry: entry,
        );
        r = Rule(connection: ChCharacter(entry: {'simplified': '学'}));
        r = ChRule(
          connection: ChCharacter(entry: {'simplified': '学'}),
          entry: entry,
        );
        expect(r.characters.runtimeType, ChDictionary);
      });
      test('empty Rule', () {
        expect(filled.isEmpty, true);
        expect(empty.isEmpty, true);
        expect(empty.strict, true);
        expect(empty.title, '');
        expect(empty.tags.runtimeType, List<String>);

        expect(empty.categories['characters'], ChDictionary);
        expect(empty.characters.runtimeType, ChDictionary);
        expect(empty.data['characters'].runtimeType, ChDictionary);
        expect(empty['characters'].runtimeType, ChDictionary);
        expect(empty['characters'].name, 'ruleCharacters');
        expect(empty.characters.baseCategories, [
          'simplified',
          'traditional',
          'pinyin',
        ]);
        expect(rule.toMap()['characters'] is List, true);

        expect(empty.baseCategories, ['level', 'title', 'subtitle']);
      });

      test('clear Rule', () {
        expect(rule.isEmpty, false);
        rule.clear();
        expect(rule.isEmpty, true);
      });

      test('filled Rule', () {
        expect(identical(rule.characters.rules[0], rule), true);
        expect(rule.isEmpty, false);

        expect(rule.sentences.length, 1);
        expect(rule.sentences[0].runtimeType, Sentence);

        expect(rule.characters.length, 2);
        expect(rule.characters[0].runtimeType, ChCharacter);
        expect(rule.charactersOpp.length, 1);
        expect(rule.charactersOpp[0].runtimeType, ChCharacter);
        expect(rule.charactersAll.length, 3);

        expect(rule.references.length != rule.characters.length, true);
        expect(rule.references, ['＿x＿x']);
        expect(rule.title, 'ABER ich Mag Dich');
        expect(rule.sentences[0].text, '我去学校。');

        expect(rule.uniqueID(), '_AiMD_a');
        expect(rule.uniqueID(method: 'hash'), '_1822514334');

        expect(rule.get('test'), null);
        // print(rule.toMarkdownTable());
        expect(identical(rule.characters.rules[0], rule), true);
      });
    });

    group('changing attributes', () {
      test('link rule to rules in characters', () {
        empty['level'] = 'C1';
        filled['title'] = 'ABC';
        rule['title'] = 'TEST';
        expect(identical(empty.characters.rules[0], empty), true);
        print([empty, empty.characters.rules[0]]);
        expect(identical(filled.characters.rules[0], filled), true);
        expect(identical(rule.characters.rules[0], rule), true);
        expect(
          identityHashCode(rule.characters.rules.first),
          identityHashCode(rule),
        );

        final copyCharacters = empty.characters.copy();
        expect(
          identityHashCode(empty.characters.rules.first),
          identityHashCode(empty),
        );

        expect(
          identityHashCode(copyCharacters.rules.first),
          identityHashCode(empty),
        );
      });
      test('editiong attributes directly will affect internal data', () {
        empty.tags.add('x');
        expect(empty.tags, ['x']);
        Logger.root.level = Level.ALL;
        expect(empty.isEmpty, true);
        Logger.root.level = Level.OFF;
        empty.set('tags', null);
        expect(empty.tags.isEmpty, true);
        expect(empty.isEmpty, true);
        empty['tags'] = null;
        expect(empty.isEmpty, true);
        expect(empty['tags'], equals(empty.tags));
        expect(
          ListEquality<String>().equals(
            empty['tags'] as List<String>,
            empty.tags,
          ),
          true,
        );
      });

      test('cannot change categories', () {
        expect(() => rule.categories['level'] = int, throwsA(isA<Error>()));
      });

      test('add characters', () {
        expect(rule.characters.length, 2);
        rule.data['characters'] += ChCharacter(entry: {'traditional': 'b'});
        expect(rule.characters.length, 3);
        rule.data['characters'] += Dictionary('D', characters: [rule]);
        expect(rule.characters.length, 3);
      });

      test('cannot create a dictionary by addition', () {
        expect(() => rule + filled, throwsA(isA<LexiconException>()));
      });
    });

    group('create new instance', () {
      test('simple copy', () {
        final copyA = filled.copy();
        expect(copyA == filled, true);
        final copyB = filled.copyWith({'explanation': 'test'});
        expect(copyB == filled, true);
        expect(filled.exact(copyB), false);
        final copyC = filled.copyWith({'test': 'test'});
        expect(filled.exact(copyC), true);
      });

      test('Rule type is pretty restrictive', () {
        expect(filled.strict, true);
        expect(filled.relax().strict == false, false);
        expect(filled.baseCategories, ['level', 'title', 'subtitle']);
        expect(
          filled.reconfigure(baseCategories: ['id']).baseCategories == ['id'],
          false,
        );
        expect(
          filled.copyWith({
            'tags': ['t'],
          }).tags,
          ['t'],
        );
      });
      test('does not change type', () {
        expect(filled.copy().runtimeType, ChRule);
        expect(
          filled.copyWith({
            'tags': ['t'],
          }).runtimeType,
          ChRule,
        );
        expect(filled.reconfigure(baseCategories: ['id']).runtimeType, ChRule);
        expect(filled.restrict().runtimeType, ChRule);
        expect(filled.relax().runtimeType, ChRule);
      });
    });

    test('write with syntax', () {
      expect(filled.applySyntaxToCharacters().length, 0);
      expect(
        () => rule.applySyntaxToCharacters(),
        throwsA(isA<LexiconException>()),
      );
      rule.addSyntax(getSyntax(), getColors(), mapColorFav: getFaves());
      final syntaxed = rule.applySyntaxToCharacters();
      expect(
        syntaxed[0]['other_characters'][0] ==
            rule.charactersOpp[0]['simplified'],
        true,
      );
    });

    test('modify category content', () {
      expect(rule.title, 'ABER ich Mag Dich');
      rule.modify('title').replaceAll('ABER', 'aber');
      expect(rule.title, 'aber ich Mag Dich');

      expect(rule['sentences'][0].pinyin, 'wǒ');
      rule.modify('sentences').toNumericPinyin();
      expect(rule['sentences'][0].pinyin, 'wǒ');
    });
  });
}
