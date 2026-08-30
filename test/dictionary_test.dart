import 'package:test/test.dart';
import 'package:lexicon/lexicon.dart';
import 'package:lexicon/src/errors.dart';
import 'package:logging/logging.dart';
import 'dart:io';
import 'helper.dart';

void main() {
  setUpAll(() {
    Logger.root.clearListeners();
    Logger.root.onRecord.listen((record) {
      print('[${record.level.name}] (${record.loggerName}): ${record.message}');
    });
  });

  group('Dictionary', () {
    late Character empty;
    late ChCharacter char;
    late ChCharacter charA;
    late ChCharacter charB;
    late ChCharacter charC;
    late ChRule rule;

    late Dictionary emptyD;
    late ChDictionary emptyChD;
    late ChDictionary filledChD;
    late ChDictionary exampleChD;
    late Dictionary filledD;

    setUp(() async {
      Logger.root.level = Level.OFF;
      emptyD = Dictionary('emptyD');
      emptyChD = ChDictionary('emptyChD');
      exampleChD = ChDictionary('exampleChD');

      empty = Character(strict: false);
      char = ChCharacter(entry: {'simplified': '八', 'pinyin': 'bā'});

      charA = char.copyWith({'simplified': 'a', 'pinyin': 'b'});
      charB = char.copyWith({
        'simplified': 'b',
        'pinyin': 'c',
        'traditional': '八',
      });
      charC = char.copyWith({'simplified': 'c', 'pinyin': 'c'});

      rule = ChRule(connection: ChCharacter());

      filledChD = ChDictionary(
        'D',
        rules: [rule],
        characters: [empty, char, charA, charC, charB],
      );

      filledD = Dictionary(
        'D',
        rules: [rule],
        characters: [empty, char, charA, charC, charB],
      );

      exampleChD = await getExample() as ChDictionary;
    });

    group('Dictionary attributes', () {
      test('empty Dictionary', () {
        expect(emptyD.name, 'emptyD');
        expect(emptyD.categories.isEmpty, true);
        expect(emptyD.sortingKey, '');
        expect(emptyD.sortingOrd, '');
        expect(emptyD.characters.length, 0);
        expect(emptyD.rules.length, 0);
        expect(
          emptyD.toString().startsWith(
            'Dictionary<Character, Rule> "emptyD": 0 (depth)',
          ),
          true,
        );
      });

      test('empty ChDictionary', () {
        expect(emptyChD.name, 'emptyChD');
        expect(emptyChD.categories.isEmpty, false);
        expect(emptyChD.sortingKey, 'pinyin');
        expect(emptyChD.sortingOrd, 'ascending');
        expect(emptyChD.characters.length, 0);
        expect(emptyChD.rules.length, 0);
      });

      test('filled ChDictionary', () {
        expect(filledChD.name, 'D');
        expect(filledChD.toString().startsWith('ChDictionary "D"'), true);
        expect(filledChD.categories.isEmpty, false);
        expect(filledChD.sortingKey, 'pinyin');
        expect(filledChD.sortingOrd, 'ascending');
        expect(filledChD.characters.length, 4);
        expect(filledChD.rules.length, 0);
        expect(
          filledChD.hashCodeFormatted.length,
          emptyChD.hashCodeFormatted.length,
        );
      });
    });

    group('changing attributes', () {
      test('rename dictionary', () {
        emptyD.name = 'test';
        expect(emptyD.name, 'test');
        emptyD.rename('emptyD');
        expect(emptyD.name, 'emptyD');
        emptyD.name = 'test__t';
        expect(emptyD.name, 'test_t');
        expect(() => emptyD.name = 'ÄÄÄ', throwsA(isA<Error>()));
        expect(() => emptyD.name = '', throwsA(isA<Error>()));
      });
      test('categories', () {
        emptyD.categories = {'best': 'str'};
        expect(
          () => emptyD.categories.addAll({'test': String}),
          throwsA(isA<Error>()),
        );
      });

      test('rules', () {
        rule.update({'level': 'A1'});
        var newRule = rule.copyWith({'level': 'B1'});
        emptyD.rules += [rule, rule, newRule];
        expect(emptyD.rules.length, 2);
        emptyD.rules = [
          {'level': 'A1'},
          {'level': 'A2'},
          {'level': 'C1'},
          {'level': 'C2'},
        ];
        emptyD.add(newRule);
        var copy = emptyD.copy();
        expect(emptyD.rules.length, 5);
        emptyD.rules = newRule;
        expect(emptyD.rules.length, 1);
        expect(emptyD.copyWith(rules: copy).rules.length, 5);
        expect(emptyD.copyWith(rules: emptyD).rules.length, 1);

        emptyD.rules = copy;
        expect(emptyD.rules.length, 5);
        emptyD.rules = null;
        expect(emptyD.rules.length, 0);
        expect(() => emptyChD.rules = 0, throwsA(isA<LexiconException>()));
      });

      test('characters', () {
        emptyD.characters += [
          empty, // Character
          charA,
          charC,
          charB,
          rule.copyWith({'level': 'TEST'}),
        ];
        emptyD.add(char);
        expect(emptyD.length, 4);
        expect(emptyD[0].runtimeType, ChCharacter);

        emptyChD.characters = [
          {'simplified': 'test'},
        ];
        expect(emptyChD.length, 1);
        expect(emptyChD[0].runtimeType, ChCharacter);

        emptyChD.characters = [
          {'simplified': 'test'},
        ];
        expect(emptyChD.length, 1);
        expect(emptyChD[0].runtimeType, ChCharacter);

        emptyD.characters = emptyChD;
        expect(emptyD[0].runtimeType, ChCharacter);
        expect(emptyChD.length, 1);

        emptyD.add({'id': 'A'});
        Dictionary reconfig = emptyD.reconfigure(baseCategories: ['id']);
        reconfig.add({'id': 'B'});
        reconfig.add([
          {'id': 'C'},
          {'id': 'D'},
        ]);
        expect(reconfig.length, 4);

        emptyChD.characters = null;
        expect(emptyChD.length, 0);

        expect(() => emptyChD.characters = 0, throwsA(isA<LexiconException>()));
        expect(
          () => emptyChD.characters = [
            {'simplified': 'test'},
            0,
          ],
          throwsA(isA<LexiconException>()),
        );
      });
    });

    group('type switching', () {
      ChCharacter chC = ChCharacter();
      Character sC = Character(strict: true, baseCategories: ['id']);
      Character nC = Character(strict: false);
      ChDictionary chD = ChDictionary('ChD');
      Dictionary nD = Dictionary('nD');

      test('ChDictionary will only have ChCharacter', () {
        final exampleCharacters = [
          chC,
          chC.copyWith({'simplified': 'a'}), // #stays
          chC.copyWith({
            'simplified': 'a',
            'images': {'i': 'i'},
          }),
          chC.copyWith({'simplified': 'a', 'pinyin': 'a'}), // #stays
          nC,
          sC.copyWith({'id': 'A'}),
          nC.copyWith({'id': 'B'}),
          nC.reconfigure(baseCategories: ['id']).copyWith({'id': 'C'}),
        ];
        chD.characters = exampleCharacters;
        nD.characters = exampleCharacters;
        expect(chD.length, 2);
        expect(nD.length, 4);

        emptyD.add(chD);
        expect(emptyD.length, 2);
        emptyD.add(nD);
        expect(emptyD.length, 4);
        emptyChD.add(nD);
        expect(emptyChD.length, 2);
      });

      test('ChDictionary will create ChCharacter', () {
        final exampleCharacters = [
          {'id': 'A'},
          {'simplified': 'a'}, // #stays
          {'simplified': 'b', 'pinyin': 'b'}, // #stays
          sC.copyWith({'id': 'B'}),
        ];
        chD.characters = exampleCharacters;
        nD.characters = exampleCharacters;
        expect(chD.length, 2);
        expect(nD.length, 1);
      });

      test('Dictionaries assigned to characters', () {
        // expect(emptyChD.copyWith(characters: emptyD).length, 2);
        // expect(
        //   emptyChD
        //       .copyWith(characters: emptyD)
        //       .map((e) => e.runtimeType)
        //       .toList(),
        //   [ChCharacter, ChCharacter],
        // );
        // expect(
        //   emptyD
        //       .copyWith(characters: emptyD)
        //       .map((e) => e.runtimeType)
        //       .toList(),
        //   [ChCharacter, Character],
        // );
        // expect(
        //   emptyD
        //       .copyWith(characters: emptyChD)
        //       .map((e) => e.runtimeType)
        //       .toList(),
        //   [ChCharacter],
        // );
        // expect(emptyChD.copyWith(characters: emptyD)[1].runtimeType, Character);
      });
    });

    group('comparisons', () {
      test('compare empty dictionaries', () {
        String name = 'ÄtestÄ';
        expect(emptyChD == emptyChD, true);
        expect(emptyChD == emptyD, false);
        expect(emptyChD == filledChD, false);
        emptyChD.name = name;
        emptyD.name = name;
        expect(emptyChD.name, '_test_');
        expect(emptyChD == emptyD, true);

        filledChD.empty(keepRules: false);
        filledChD.rename(name);
        expect(emptyChD == filledChD, true);
      });

      test('compare dictionaries with different names', () {
        var reconfigured = filledChD.reconfigure(
          name: 'reconfigured',
          categories: {'test': String},
        );
        expect(filledChD == reconfigured, false);
        expect(filledChD.characters == filledChD.characters, true);
        var test = filledD.reconfigure(
          categories: {
            'simplified': String,
            'traditional': String,
            'pinyin': String,
          },
        );
        expect(test == filledD, true);
      });
    });

    group('subsetting and selecting', () {
      test('get character by identifier', () {
        expect(
          filledChD[0] ==
              filledD.sort(sortingKey: 'pinyin', sortingOrd: 'ascending')[0],
          true,
        );
        expect(
          filledChD[0],
          filledD.sort(sortingKey: 'pinyin', sortingOrd: 'ascending')[0],
        );
        expect(filledChD[['a', '', 'b']], filledD[['a', '', 'b']]);
        expect(filledChD[filledD[1]].identifier, ['a', '', 'b']);

        expect(() => emptyChD[100], throwsA(isA<Error>()));
        expect(() => emptyChD[['x', '', '']], throwsA(isA<LexiconException>()));
        expect(() => emptyChD[null], throwsA(isA<LexiconException>()));
      });

      test('get dictionary from list of identifiers', () {
        expect(
          filledChD.getSubset([
            ['a', '', 'b'],
            ['b', '', 'c'],
            1,
            100,
          ]).length,
          2,
        );
        expect(filledChD.getSubset([3]), filledChD.getSlice(start: 3, stop: 4));
      });

      test('get dictionary from slice', () {
        expect(filledChD.getSlice(start: 3).length, 1);
        expect(filledChD.getSlice(start: 4, stop: 4).length, 0);
        expect(filledChD.getSlice(stop: 1).length, 1);
        expect(() => filledChD.getSlice(stop: 5), throwsA(isA<Error>()));
      });

      test('get dictionary by searching', () {
        var test = Character(
          entry: {
            'simplified': 'x',
            'pinyin': 'x',
            'images': {'x': 'x'},
          },
          baseCategories: ['images'],
          strict: false,
        );
        filledD.add(test);
        expect(
          filledD
              .searchCategory(pattern: 'x', searchCategories: ['images'])
              .length,
          1,
        );
        expect(
          filledChD.search(categories: ['pinyin'], pattern: 'c').length,
          2,
        );
      });
    });

    group('+ / - operators', () {
      test('addition and subtraction of characters', () {
        var combo1 = filledD[3] + filledD.getSlice(start: 1, stop: 2);
        var combo2 = filledD.getSlice(start: 1, stop: 2) + filledD[3];
        expect(combo1, combo2);
        var combo =
            filledD[3] + filledD.getSlice(stop: 2) + filledD[['八', '', 'ba1']];
        expect(combo.length, 3);
        expect((combo - filledD[0]).length, 2);

        expect((filledD + emptyChD).length, filledD.length);
        expect((filledD - combo1).length, 2);

        exampleChD.getSlice(start: 10, stop: 13);
        expect(
          (filledD + exampleChD.getSlice(start: 10, stop: 13)).length,
          filledD.length + 3,
        );
        expect(
          (exampleChD.getSlice(start: 10, stop: 13) + combo1 + filledD).length,
          filledD.length + 3,
        );

        expect(
          () => filledD + ['a', '', 'a'],
          throwsA(isA<LexiconException>()),
        );
        expect(
          () => filledD - ['a', '', 'a'],
          throwsA(isA<LexiconException>()),
        );

        expect(() => filledD.add(0), throwsA(isA<LexiconException>()));
        expect(() => filledD.remove(0), throwsA(isA<LexiconException>()));
      });
      test('addition and subtraction of rules', () {
        filledChD.rules = [
          {'level': 'A1'},
          {'level': 'A2'},
          {'level': 'C1'},
          {'level': 'C2'},
        ];
        expect((filledChD + ChRule(entry: {'level': 'B1'})).rules.length, 5);
        expect((filledChD - ChRule(entry: {'level': 'A1'})).rules.length, 3);
      });
    });

    group('copy', () {
      test('copy should unlink characters', () {
        filledChD.rules = [
          {'level': 'A1'},
          {'level': 'A2'},
          {'level': 'C1'},
          {'level': 'C2'},
        ];
        final copied = filledChD.copy();
        expect(copied.characters.first.exact(filledChD.characters.first), true);
        expect(copied.rules.first.exact(filledChD.rules.first), true);
        expect(
          identical(copied.characters.first, filledChD.characters.first),
          false,
        );
        expect(
          identityHashCode(copied.characters.first) ==
              identityHashCode(filledChD.characters.first),
          false,
        );
        expect(
          identical(copied.rules.first, filledChD.rules.first),
          true, // ! Is actually a problem
        );
      });
    });

    group('sorting', () {
      test('sort characters by key and order', () {
        ChCharacter interest = filledChD[['b', '八', 'c']];
        filledChD.sortingKey = 'pinyin';
        expect(filledChD.characters.indexOf(interest), 2);
        filledChD.sortingKey = 'simplified';
        expect(filledChD.characters.indexOf(interest), 1);
        filledChD.sortingKey = 'traditional';
        expect(filledChD.characters.indexOf(interest), 3);
        filledChD.sortingOrd = 'descending';
        expect(filledChD.characters.indexOf(interest), 0);
        expect(
          () => filledChD.sortingKey = 'test',
          throwsA(isA<LexiconException>()),
        );
        expect(
          () => filledChD.sortingOrd = 'test',
          throwsA(isA<LexiconException>()),
        );

        var test1 = filledD.sort(sortingKey: 'pinyin', sortingOrd: 'ascending');
        var test2 = filledD.sort(
          sortingKey: 'simplified',
          sortingOrd: 'ascending',
        );

        expect(
          () => filledD.reorder(sortingKey: 'abc', sortingOrd: 'ascending'),
          throwsA(isA<LexiconException>()),
        );

        expect(test1.characters.indexOf(interest), 3);
        expect(test2.characters.indexOf(interest), 1);
      });

      group('reading / writing ', () {
        test('read dict jsonl', () async {
          ChDictionary chd = ChDictionary('chd');
          final categories = getCategories();

          await chd.read(File('assets/MCD.jsonl'), categories: categories);
        });

        test('read rule jsonl', () async {
          ChDictionary chd = ChDictionary('chd');
          await chd.readRules(File('assets/grammar.jsonl'));
          print(chd.rules);
        });

        test('write txt', () {
          final tmpl = 'assets/pleco.chd';
          exampleChD.write(
            File('assets/example.txt'),
            mod: TextModifier<String>(
              '',
              mapSyntax: getSyntax(),
              mapColor: getColors(),
              mapColorFav: getFaves(),
            ),
            template: File(tmpl),
          );
        });

        test('write jsonl', () {
          exampleChD
              .reconfigure(
                categories: {'english': List<String>, 'german': List<String>},
              )
              .write(File('assets/example.jsonl'));
        });

        test('write db', () {
          expect(
            () => exampleChD.write(File('assets/example.db')),
            throwsA(isA<LexiconException>()),
          );
        });
      });

      test('example dictionary', () {
        // exampleChD.reorder(sortingKey: 'traditional', sortingOrd: 'descending');
        // exampleChD.reorder(sortingKey: 'traditional', sortingOrd: 'ascending');
        // exampleChD.reorder(sortingKey: 'simplified', sortingOrd: 'ascending');
        exampleChD.reorder(sortingKey: 'pinyin', sortingOrd: 'ascending');

        expect(exampleChD[0]['english'], ['eight', '8']);
        expect(
          exampleChD
              .search(pattern: "eight", exact: true, categories: ['english'])
              .length,
          1,
        );
        expect(exampleChD.search(pattern: "ba1", exact: true).length, 2);
        expect(exampleChD.search(pattern: "gan1", exact: true).length, 2);
        expect(exampleChD.search(pattern: "gan1", exact: false).length, 3);
      });
    });
  });
}
