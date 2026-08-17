import 'package:lexicon/lexicon/text_modifier.dart';
import 'package:lexicon/lexicon/utils.dart';
import 'package:lexicon/lexicon/text_action.dart';
import 'package:test/test.dart';
import 'dart:io';

void main() {
  runTextModifier();
  runTextAction();
}

void runTextModifier() {
  /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

  final List<String> listText = ['ǜ asksnc', '，', '八 八', '八八'];
  final String pinyinNumeric = 'ba1ba5 shi4 wo3 de.';
  final String pinyinTones = 'bāba shì wǒ de.';

  final String pathSyntax = 'assets/syntax.json';
  final String pathColors = 'assets/colors.json';
  Map<String, dynamic> colors = readJSONSync(File(pathColors))!;
  Map<String, dynamic> data = readJSONSync(File(pathSyntax))!;

  /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

  group('TextModifier', () {
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    final mod = TextModifier(listText);

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('find first character of language', () {
      expect(mod.findFirstChar('chinese').result, ['八', '八八']);
      expect(mod.set(listText).findFirstChar('notChinese').result, [
        'ǜ asksnc',
        '，',
      ]);
      expect(mod.findFirstChar('english').result, ['asksnc']);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    final modA = TextModifier(pinyinNumeric);
    final modB = TextModifier(pinyinTones);

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('convert pinyin', () {
      expect(modA.toNumericPinyin().result, 'ba1ba5 shi4 wo3 de.');
      expect(modA.toPlainPinyin().result, 'baba shi wo de.');
      expect(modA.toToneMarkedPinyin().result, 'baba shi wo de.');
      expect(modA.toCleanLanguage('chinese').result, 'baba shi wo de。');
      expect(modA.toCleanLanguage('english').result, 'baba shi wo de.');
      expect(modB.toToneMarkedPinyin().result, 'bāba shì wǒ de.');
      expect(modB.toNumericPinyin().result, 'baba1 shi4 wo3 de.'); // ! PROBLEM
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    final modStr = TextModifier('abc [ [list Text] a] abc');
    final modList = TextModifier(['[a1a2]', 'ba4', '[chi1]']);

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('apply command from syntax', () {
      modStr.addAction(data, colors);
      expect(
        modStr.act.applySyntaxCommands(['tab']).result,
        'abc [ [list Text] a] abc',
      );
      expect(modStr.linkPinyin().result, 'abc [ [list Text] a] abc');
      expect(modStr.set('abc [ [a1a3]]').convertPinyin().result, 'abc [ [āǎ]]');

      expect(modList.convertPinyin().result, ['[āá]', 'ba4', '[chī]']);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('remove syntax', () {
      modStr.set('abc [ [list Text] a] abc');
      expect(modStr.removeSyntax().result, 'abc [ [list Text] a] abc');
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
  });
}

void runTextAction() {
  group('TextAction', () {
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    final String pathSyntax = 'assets/syntax.json';
    final String pathColors = 'assets/colors.json';

    Map<String, dynamic> colors = readJSONSync(File(pathColors))!;
    Map<String, dynamic> data = readJSONSync(File(pathSyntax))!;
    Map<String, dynamic>? dataAsync;

    setUp(() async {
      dataAsync = await readJSON(File(pathSyntax));
    });

    final Map<String, String> favColors = {
      "blue": "Dodger Blue",
      "teal": "Strong Blue",
      "green": "Cyan Blue",
      "grey": "Light Slate Gray",
    };
    final actStr = TextAction(
      'test everything',
      mapColorFav: favColors,
      mapColor: colors,
      mapSyntax: data,
    );
    final actList = TextAction(
      [''],
      mapColorFav: favColors,
      mapColor: colors,
      mapSyntax: data,
    );

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
    test('syntax json map', () {
      expect(data, dataAsync);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('initializing', () {
      actStr.color = 'green';
      expect(
        isExactType(actStr.mapColorFav.runtimeType, Map<String, String>),
        true,
      );
      expect(actStr.result, 'test everything');
      expect(actStr.color, '');
      expect(actStr.command, null);
      actList.result = ['ab [] abd', 'skncs as'];
      // print(actList.applySyntax(commandList: ['tab']));
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('get command and syntax', () {
      expect(actStr.getFullCommand('normal'), 'normal');
      expect(actStr.getFullCommand('b'), 'bold');
      expect(actStr.getSyntax(cmd: 'b'), ['', '']);
      expect(actStr.getSyntax().length, 0);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('apply one command ', () {
      actStr.color = 'green';
      actStr.set('test test test', command: 's');
      expect(
        actStr.set('test test test', command: 's').applyCommand().result,
        'AA00test test test',
      );
      expect(
        actStr.set('test test test', command: 'color').applyCommand().result,
        'test test test',
      );
      expect(
        actStr.set('test test test', command: 'normal').applyCommand().result,
        'test test test',
      );

      actStr.set('test everything', command: 'tab');
      expect(actStr.applySyntax().result, 'test everything');
      actStr.set('test everything', command: 'normal');
      expect(actStr.applySyntax().result, 'test everything');
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('apply list of commands', () {
      actStr.set('test');
      expect(actStr.applySyntaxCommands(['nb', 'normal']).result, 'test');
      expect(actStr.applySyntaxCommands(['normal', 'nb']).result, 'test');

      actStr.set('test everything');
      expect(
        actStr.applySyntaxCommands(['nb', 'link', 'tab']).result,
        'test everything',
      );
      actStr.set('test everything');
      expect(actStr.applySyntaxCommands(['tab']).result, 'test everything');
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
  });
}
