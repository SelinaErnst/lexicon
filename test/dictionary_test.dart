import 'package:test/test.dart';
import 'package:lexicon/lexicon.dart';
import 'package:lexicon/lexicon/dictionary.dart';
import 'package:lexicon/lexicon/rule.dart';
import 'package:logging/logging.dart';

void main() {
  setUpAll(() {
    Logger.root.clearListeners();
    Logger.root.onRecord.listen((record) {
      print('[${record.level.name}] (${record.loggerName}): ${record.message}');
    });
    Logger.root.level = Level.ALL;
  });

  group('Dictionary', () {
    late Character empty;
    late ChCharacter char;
    late ChCharacter charA;
    late ChCharacter charB;
    late ChCharacter charC;
    late Rule rule;

    late Dictionary emptyD;
    late ChDictionary emptyChD;
    late ChDictionary filledChD;
    late ChDictionary filledD;

    setUp(() {
      Logger.root.level = Level.OFF;
      emptyD = Dictionary();
      emptyChD = ChDictionary();

      empty = Character();
      char = ChCharacter(entry: {'simplified': '八', 'pinyin': 'bā'});
      //   // char.copy().update(entry)
      //   char.copy;
      charA = char.copyWith({'simplified': 'a', 'pinyin': 'b'});
      charB = char.copyWith({'simplified': 'b', 'pinyin': 'c'});
      charC = char.copyWith({'simplified': 'c', 'pinyin': 'c'});

      rule = Rule();

      filledChD = ChDictionary(
        name: 'D',
        rules: [rule],
        characters: [empty, char, charA, charC, charB],
      );

      filledD = ChDictionary(
        name: 'D',
        rules: [rule],
        characters: [empty, char, charA, charC, charB],
      );
      Logger.root.level = Level.ALL;
    });

    group('Dictionary attributes', () {
      test('empty Dictionary', () {
        expect(emptyD.name, '');
        expect(emptyChD.categories.isEmpty, true);
        expect(emptyD.sortingKey, '');
        expect(emptyD.sortingOrd, '');
        expect(emptyD.characters.length, 0);
        expect(emptyD.rules.length, 0);
      });

      test('empty ChDictionary', () {
        expect(emptyChD.name, '');
        expect(emptyChD.categories.isEmpty, true);
        expect(emptyChD.sortingKey, 'pinyin');
        expect(emptyChD.sortingOrd, 'ascending');
        expect(emptyChD.characters.length, 0);
        expect(emptyChD.rules.length, 0);
      });

      test('filled ChDictionary', () {
        expect(filledChD.name, 'D');
        expect(filledChD.categories.isEmpty, true);
        expect(filledChD.sortingKey, 'pinyin');
        expect(filledChD.sortingOrd, 'ascending');
        expect(filledChD.characters.length, 4);
        expect(filledChD.rules.length, 0);

        print(filledD[0]);
      });

      group('changing attributes', () {
        test('categories', () {
          emptyD.categories = {'best': 'str'};
          expect(
            () => emptyD.categories.addAll({'test': String}),
            throwsUnsupportedError,
          );
        });
        test('characters', () {
          emptyChD.characters += [empty, char, charA, charC, charB];
          expect(emptyChD.length, 4);
          emptyChD.characters = [
            {'simplified': 'test'},
          ];
          expect(emptyChD.length, 1);
          var testchar = emptyChD[0]!;
          expect(testchar.runtimeType, ChCharacter);
          // print(testchar.uniqueID());
        });
      });
    });

    // test('create copy', () {
    //   var copy = emptyChD.copyWith(name: 'Test');
    //   expect(copy.name, 'Test');
    //   expect(emptyChD == copy, false);
    // });

    // test('initializing populated', () {
    //   expect(filledChD.length, 4);
    //   // expect(filled.createInstance().length, 0);

    //   expect(filledChD[0], filledChD[['a', '', 'b']]);
    //   expect(
    //     filledChD.search(pattern: 'c', categories: ['simplified']).length,
    //     1,
    //   );
    // });

    // test('Mixed character types are not possible for ChDictionary', () {
    //   expect(filledChD.length, 4);
    //   filledChD.add(empty.copyWith({'simplified': 'test'}));
    //   expect(filledChD.length, 4);
    // });

    // test('Mixed character types for Dictionary', () {
    //   expect(emptyD.length, 0);
    //   emptyD.add(char);
    //   expect(emptyD.length, 1);
    //   var emptyRelaxed = empty.relax().copyWith({'simplified': 'test'});
    //   emptyD.add(emptyRelaxed);
    //   expect(emptyRelaxed.isEmpty, true);
    //   expect(emptyD.length, 1);

    //   expect(char.runtimeType, ChCharacter);
    //   expect(() => char['test'] = null, throwsArgumentError);

    //   var charRelaxed = char.relax();
    //   emptyD.add(charRelaxed);
    //   expect(emptyD.length, 1);

    //   expect(charRelaxed.runtimeType, Character);
    //   charRelaxed['test'] = null;
    //   expect(charRelaxed.categories.containsKey('test'), true);
    // });

    // test('sorting and combining', () {
    //   filledChD.sortingKey = 'pinyin';
    //   filledChD.sortingOrd = 'descending';
    //   expect(filledChD[3], filledChD[['a', '', 'b']]);
    //   print(filledChD.search(pattern: "c"));
    //   expect((filledChD.getSubset([0, 2]) + filledChD[3]).length, 3);
    //   expect(
    //     (filledChD[3]! + filledChD.getSubset([0, 2]) - filledChD[3]).length,
    //     2,
    //   );
    // });

    // test('search', () {
    //   expect(filledChD.search(pattern: 'c').length, 2);
    //   expect(
    //     filledChD.search(pattern: 'c', categories: ['simplified']).length,
    //     1,
    //   );
    // });
  });
}
