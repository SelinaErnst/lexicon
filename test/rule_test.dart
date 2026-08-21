import 'package:lexicon/lexicon/dictionary.dart';
import 'package:lexicon/lexicon/rule.dart';
import 'package:lexicon/lexicon/character.dart';
// import 'package:lexicon/lexicon/sentence.dart';
import 'package:lexicon/lexicon/text_modifier.dart';
import 'package:test/test.dart';
import 'package:logging/logging.dart';

import 'helper.dart';

void main() {
  /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

  group('Rule', () {
    late Rule empty;
    late Rule filled;
    late Rule rule;
    late TextModifier modText;

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
      modText.addAction(syntax, colors, mapColorFav: favColors);
    });

    setUp(() {
      Logger.root.level = Level.OFF;
      empty = Rule();
      rule = Rule(
        entry: {
          'mod': modText,
          'title': 'ABER ich Mag Dich  ',
          'subtitle': 'a',
          'sentences': [
            {'text': '我去学校.'},
            {'sc': 's'},
          ],
          'characters': [
            {'simplified': '_x_x'},
            {'pinyin': 'y'},
            {'sc': 'y'},
          ],
          'charactersOpp': [
            {'simplified': 'x', 'pinyin': 'y'},
          ],
        },
      );

      filled = Rule(
        entry: {
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
      Logger.root.level = Level.ALL;
    });

    test('initializing empty', () {
      expect(filled.isEmpty, true);
      expect(empty.isEmpty, true);
      expect(empty.title, '');
      empty.tags.add('x');
      expect(empty.tags, ['x']);
      expect(empty.tags.runtimeType, List<String>);
      expect(empty.isEmpty, false);

      expect(empty.categories['characters'], Dictionary);
      expect(empty.characters.runtimeType, Dictionary);
      expect(empty.data['characters'].runtimeType, Dictionary);
      expect(empty['characters'].runtimeType, Dictionary);
    });

    test('copy', () {
      final Rule copy = rule.copy();
      final Rule other = rule.copyWith({
        'sentences': [
          {'text': 'abc'},
        ],
      }, merge: true);
      expect(copy.data, rule.data);
      expect(other.data == rule.data, false);
      expect(rule.sentences.length, 1);
      expect(other.sentences.length, 2);
    });

    test('add characters', () {
      expect(rule.characters.length, 2);
      rule.characters += ChCharacter(entry: {'traditional': 'b'});
      expect(rule.characters.length, 3);
      rule.characters += Dictionary(characters: [rule]);
      expect(rule.characters.length, 4);
    });

    test('cannot change categories', () {
      expect(
        () => rule.reconfigure(specs: {'test': String}),
        throwsUnsupportedError,
      );
      expect(() => rule.categories['level'] = int, throwsUnsupportedError);
    });

    test('initializing populated', () {
      expect(rule.isEmpty, false);
      expect(rule.characters.length, 2);
      expect(rule.charactersOpp.length, 1);

      expect(rule.charactersAll.length, 3);
      expect(rule.references, ['＿x＿x']);
      expect(rule['title'], 'ABER ich Mag Dich');
      expect(rule.get('test'), null);
      expect(rule.sentences[0].text, '我去学校。');

      expect(rule.uniqueID(), '_AiMD_a');
      expect(rule.uniqueID(method: 'hash'), '_1822514334');

      rule.set('tags', ['tag']);
      expect(rule['tags'] == rule.tags, true);

      expect(rule.toMap()['characters'] is List, true);
    });
  });
}
