import 'package:suhan_lexicon/src/sentence.dart';
import 'package:suhan_lexicon/src/text_modifier.dart';
import 'package:suhan_lexicon/src/utils.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'package:logging/logging.dart';

void main() {
  group('Sentence', () {
    late Sentence s;
    late Sentence empty;
    late TextModifier<String> mod;
    setUpAll(() {
      Logger.root.clearListeners();
      Logger.root.onRecord.listen((record) {
        print(
          '[${record.level.name}] (${record.loggerName}): ${record.message}',
        );
      });

      final String pathSyntax = 'assets/syntax.json';
      final String pathColors = 'assets/colors.json';
      Map<String, dynamic> colors = readJSONSync(File(pathColors));
      Map<String, dynamic> syntax = readJSONSync(File(pathSyntax));
      Map<String, String> favColors = {
        "blue": "Dodger Blue",
        "teal": "Strong Blue",
        "green": "Cyan Blue",
        "grey": "Light Slate Gray",
      };
      mod = TextModifier('');
      mod.addSyntax(
        mapSyntax: syntax,
        mapColor: colors,
        mapColorFav: favColors,
      );
    });

    setUp(() {
      s = Sentence(text: 'abac.', pinyin: 'a1ba3c.', translation: 'abac.');
      empty = Sentence();
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('Sentence attributes', () {
      expect(empty.isEmpty, true);
      expect(s.text, 'abac。');
      expect(s.pinyin, 'ābǎc.');
      expect(s.isEmpty, false);
      expect(s.toString(), 'Sentence: abac。');
      expect(s.toMap().length, 3);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('write with syntax', () {
      final s = Sentence(text: 'abac.', translation: 'abac.');
      s.addSyntax(
        mapSyntax: mod.mapSyntax,
        mapColor: mod.mapColor,
        mapColorFav: mod.mapColorFav,
      );
      expect(s.applySyntax(), 'abac。abac.');
      final sts = Sentence(
        mod: mod,
        text: 'abac.',
        pinyin: 'a1ba3c.',
        translation: 'abac.',
      );
      expect(sts.applySyntax(), 'abac。ābǎc.abac.');
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
  });
}
