import 'package:lexicon/lexicon.dart';
import 'package:lexicon/lexicon/rule.dart';
import 'package:lexicon/lexicon/text_modifier.dart';
import 'package:lexicon/lexicon/utils.dart';
import 'dart:io';
import 'package:test/test.dart';

final String pathSyntax =
    '/home/selina/Applications/MyApps/suhan/packages/lexicon/assets/syntax.json';
final String pathColors =
    '/home/selina/Applications/MyApps/suhan/packages/lexicon/assets/colors.json';

Map<String, dynamic> colors = readJSONSync(File(pathColors))!;
Map<String, dynamic> data = readJSONSync(File(pathSyntax))!;

final Map<String, String> favColors = {
  "blue": "Dodger Blue",
  "teal": "Strong Blue",
  "green": "Cyan Blue",
  "grey": "Light Slate Gray",
};

void main() {
  runRuleTest();
}

void runRuleTest() {

  /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

  final modText = TextModifier('');
  modText.addAction(data, colors, mapColorFav: favColors);

  /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

  group('Rule', () {

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    final rule1 = Rule();
    final rule2 = Rule(
      title: '',
      subtitle: '',
      sentences: [
        {'text': ''},
        {'sc': 's'},
      ],
      characters: [
        {'simplified': '', 'pinyin': '', 'test': 'a'},
      ],
      charactersOpp: [],
    );

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('initializing empty', () {

      expect(rule1.isEmpty, true);
      expect(rule2.isEmpty, true);

      expect(rule1.title, '');
      rule1.tags.add('x');
      expect(rule1.tags, ['x']);
      expect(rule1.tags.runtimeType, List<String>);
      expect(rule1.isEmpty, false);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    final rule = Rule(
      mod: modText,
      title: 'ABER ich Mag Dich  ',
      subtitle: 'a',
      sentences: [
        {'text': 'a A'},
        {'sc': 's'},
      ],
      characters: [
        {'simplified': '_x_x'},
        {'pinyin': 'y'},
        {'sc': 'y'},
      ],
      charactersOpp: [
        {'simplified': 'x', 'pinyin': 'y'},
      ],
    );

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('initializing populated', () {
      // print(rule.characters);
      expect(rule.characters.length, 2);
      expect(rule.charactersOpp.length, 1);

      Rule copy = rule.copy();
      rule.characters += ChCharacter(entry: {'traditional': 'b'});

      expect(rule.characters.length != copy.characters.length, true);
      expect(rule.charactersAll.length, 4);
      expect(rule.references, ['＿x＿x']);
      expect(rule['title'], 'ABER ich Mag Dich');
      expect(rule.get('test'), null);

      expect(rule.uniqueID(), '_AiMD_a');
      expect(rule.uniqueID(method: 'hash'), '_1822514334');

      
      rule.set('tags', ['tag']);
      expect(rule['tags'] == rule.tags, true);

      expect(rule.toMap()['characters'] is List, true);
      // rule.applySyntaxToCharacters();
    });
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
  });
}
