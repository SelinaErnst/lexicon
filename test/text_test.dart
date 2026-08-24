import 'package:lexicon/lexicon/text_modifier.dart';
import 'package:lexicon/lexicon/utils.dart';
import 'package:test/test.dart';
import 'dart:io';

void main() {
  final List<String> listText = ['ǜ asksnc', '，', '八 八', '八八'];
  final String pinyinNumeric = 'ba1ba5 shi4 wo3 de.';
  final String pinyinTones = 'bāba shì wǒ de.';

  final String pathSyntax = 'assets/syntax.json';
  final String pathColors = 'assets/colors.json';
  late Map<String, dynamic> colors;
  late Map<String, dynamic> syntax;

  late TextModifier mod;
  late TextModifier<String> modStr;
  late TextModifier<List<String>> modList;
  late TextModifier<String> modAct;

  final Map<String, String> favColors = {
    "blue": "Dodger Blue",
    "teal": "Strong Blue",
    "green": "Cyan Blue",
    "grey": "Light Slate Gray",
  };

  setUpAll(() {
    colors = readJSONSync(File(pathColors));
    syntax = readJSONSync(File(pathSyntax));
    mod = TextModifier('');
    modStr = TextModifier('');
    modList = TextModifier(['']);
    modAct = TextModifier('');
    modAct.addSyntax(
      mapColor: colors,
      mapSyntax: syntax,
      mapColorFav: favColors,
    );
  });

  group('TextModifier', () {
    group('convert text', () {
      test('input type has to be the same', () {
        expect(() => modList.set(''), throwsA(isA<Error>()));
        expect(() => modStr.set(['']), throwsA(isA<Error>()));

        expect(mod.set('_ a_a.').toCleanLink().result, 'a＿a');
        expect(mod.set('_ a_a.').toCleanRef().result, '＿a＿a.');
        expect(mod.set('_ a_a.').toCleanLanguage('chinese').result, '＿ a＿a。');
        expect(mod.set(['_a_a.', 'b']).toCleanLink().result, ['a＿a', 'b']);
      });

      test('find first character of language', () {
        modList.set(listText);
        expect(modList.findFirstChar('chinese').result, ['八', '八八']);
        modList.set(listText);
        expect(modList.findFirstChar('notChinese').result, ['ǜ asksnc', '，']);
        expect(modList.findFirstChar('english').result, ['asksnc']);
        expect(modStr.set('scan ackn asco').findFirstChar('any').result, 's');
      });

      test('convert pinyin', () {
        modStr.set(pinyinNumeric);
        expect(modStr.toNumericPinyin().result, 'ba1ba5 shi4 wo3 de.');
        expect(modStr.toPlainPinyin().result, 'baba shi wo de.');
        expect(modStr.toToneMarkedPinyin().result, 'baba shi wo de.');
        expect(modStr.toCleanLanguage('chinese').result, 'baba shi wo de。');
        expect(modStr.toCleanLanguage('english').result, 'baba shi wo de.');
        modStr.set(pinyinTones);
        expect(modStr.toToneMarkedPinyin().result, 'bāba shì wǒ de.');
        expect(
          modStr.toNumericPinyin().result,
          'baba1 shi4 wo3 de.',
        ); // ! PROBLEM

        String text =
            'ba4 chi1 wo3 deng1 nv3 nü3 hv0ha xx aa hao3ba4 ui2ear1 iu2';
        modStr.set(text).toToneMarkedPinyin();
        expect(modStr.result, 'bà chī wǒ dēng nǚ nǚ hüha xx aa hǎobà uíeār iú');
        modStr.toNumericPinyin();
        expect(
          modStr.result,
          'ba4 chi1 wo3 deng1 nv3 nv3 hvha xx aa haoba4 uiear1 iu2',
        ); // !Problem
        modStr.toPlainPinyin().toToneMarkedPinyin();
        expect(modStr.result, 'ba chi wo deng nv nv hvha xx aa haoba uiear iu');
      });
    });

    group('apply syntax', () {
      test('apply command from syntax', () {
        modStr.set('abc [ [list Text] a] abc');
        modList.set(['[a1a2]', 'ba4', '[chi1]']);

        expect(
          () => modStr.applySyntaxCommands(['tab']),
          throwsA(isA<Error>()),
        );

        expect(modStr.hasSyntax, false);
        modStr.addSyntax(mapSyntax: syntax, mapColor: colors);
        expect(modStr.hasSyntax, true);

        expect(
          modStr.applySyntaxCommands(['tab']).result,
          'abc [ [list Text] a] abc',
        );
        expect(modStr.linkPinyin().result, 'abc [ [list Text] a] abc');
        expect(
          modStr.set('abc [ [a1a3]]').convertPinyin().result,
          'abc [ [āǎ]]',
        );

        expect(modList.convertPinyin().result, ['[āá]', 'ba4', '[chī]']);
        modList
            .set(['a\na', 'a\n\na', '■□●○'])
            .addSyntax(mapSyntax: syntax, mapColor: colors);
        expect(modList.writeToPleco().result, ['aa', 'a a', '◼◼◼◼']);
      });

      test('remove syntax', () {
        modStr.set('abc [ [list Text] a] abc');
        expect(modStr.removeSyntax().result, 'abc [ [list Text] a] abc');
      });

      test('get command and syntax', () {
        expect(modAct.getFullCommand('normal'), null);
        expect(modAct.getFullCommand('b'), 'bold');
        expect(modAct.getSyntax(cmd: 'b'), ['', '']);
        expect(modAct.getSyntax().length, 0);
        expect(modAct.getSyntax(cmd: 'it'), ['', '']);
      });

      test('color command', () {
        modAct.set('test everything');
        modAct.color = 'green';
        expect(modAct.color, '');
        expect(
          isExactType(modAct.mapColorFav.runtimeType, Map<String, String>),
          true,
        );
        expect(modAct.result, 'test everything');
        expect(modAct.command, 'normal');
      });

      test('apply one command ', () {
        modAct.color = 'green';
        modAct.set('test test test', command: 's');
        expect(
          modAct.set('test test test', command: 's').applyCommand().result,
          'AA00test test test',
        );
        expect(
          modAct.set('test test test', command: 'color').applyCommand().result,
          'test test test',
        );
        expect(
          modAct.set('test test test', command: 'normal').applyCommand().result,
          'test test test',
        );
        modAct.replaceAll('test', 'x').replaceAll(' ', '');
        expect(modAct.result, 'xxx');
        modAct.set('test everything', command: 'tab');
        expect(modAct.applySyntax().result, 'test everything');
        modAct.set('test everything', command: 'normal');
        expect(modAct.applySyntax().result, 'test everything');
      });

      test('apply list of commands', () {
        modAct.set('test');
        expect(modAct.applySyntaxCommands(['nb', 'normal']).result, 'test');
        expect(modAct.applySyntaxCommands(['normal', 'nb']).result, 'test');

        modAct.set('test everything');
        expect(
          modAct.applySyntaxCommands(['nb', 'link', 'tab']).result,
          'test everything',
        );
        modAct.set('test everything');
        expect(modAct.applySyntaxCommands(['tab']).result, 'test everything');

        modList.set(['[a1a2]', 'ba4', '[chi1]']);
        modList.addSyntax(
          mapColor: colors,
          mapSyntax: syntax,
          mapColorFav: favColors,
        );
        expect(modList.applySyntaxCommands(['link']).result, [
          '[a1a2]',
          'ba4',
          '[chi1]',
        ]);
        modList.set(['[a1a2]', 'ba4', '[chi1]']);
        expect(modList.linkPinyin().result, ['[a1a2]', 'ba4', '[chi1]']);

        print(
          modAct.set('2', color: '').applySyntaxCommands([
            'normal',
            'normal',
            'color',
          ]).result,
        );
      });

      test('apply normal', () {
        modAct.color = 'grey';
        // modAct.color = '';
        print(
          modAct.set('2').applySyntaxCommands([
            'normal',
            'normal',
            'color',
          ]).result,
        );

        final s =
            '#C1  #NB1 ENG  #NB2  #C2 ◼ eight ◼ 8 #NL  #C1  #NB1 GER  #NB2  #C2 ◼ acht #NL  #C1  #NB1 RAD  #NB2  #C2 ◼ KangXi 12: eight #NL';
        print(s.strip('#NL'));
      });
    });
  });
}
