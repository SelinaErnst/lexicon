import 'package:lexicon/lexicon/sentence.dart';
import 'package:lexicon/lexicon/text_modifier.dart';
import 'package:lexicon/lexicon/utils.dart';
import 'package:test/test.dart';
import 'dart:io';

void main() {
  runSentence();
}

void runSentence() {
  /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
  final String pathSyntax =
      '/home/selina/Applications/MyApps/suhan/packages/lexicon/assets/syntax.json';
  final String pathColors =
      '/home/selina/Applications/MyApps/suhan/packages/lexicon/assets/colors.json';
  Map<String, dynamic> colors = readJSONSync(File(pathColors))!;
  Map<String, dynamic> data = readJSONSync(File(pathSyntax))!;
  Map<String, String> favColors = {
    "blue": "Dodger Blue",
    "teal": "Strong Blue",
    "green": "Cyan Blue",
    "grey": "Light Slate Gray",
  };
  /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

  group('Sentence', () {

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    final mod = TextModifier('');
    mod.addAction(data, colors, mapColorFav: favColors);
    
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
    
    test('initializing', () {
      final s = Sentence(
        mod: mod,
        text: 'abac.',
        pinyin: 'a1ba3c.',
        translation: 'abac.',
      );
      expect(s.text, 'abac。');
      expect(s.pinyin, 'ābǎc.');
      expect(s.toString(), 'Sentence: abac。');
      expect(s.toMap().length,3);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('write with syntax', () {
      final s = Sentence(mod: mod, text: 'abac.', translation: 'abac.');
      expect(s.applySyntax(),'abac。abac.');
      final sts = Sentence(
        mod: mod,
        text: 'abac.',
        pinyin: 'a1ba3c.',
        translation: 'abac.',
      );
      expect(sts.applySyntax(),'abac。ābǎc.abac.');
    });
    
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
  });
}
