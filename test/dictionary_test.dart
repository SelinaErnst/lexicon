import 'package:test/test.dart';
import 'package:lexicon/lexicon.dart';
import 'package:lexicon/lexicon/dictionary.dart';
import 'package:lexicon/lexicon/rule.dart';

void main() {
  runDictionaryTests();
}

void runDictionaryTests() {
  /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
  var empty = ChCharacter();
  var char = ChCharacter(entry: {'simplified': '八', 'pinyin': 'bā'});
  var charA = ChCharacter(entry: {'simplified': 'a', 'pinyin': 'd'});
  var charB = ChCharacter(entry: {'simplified': 'b', 'pinyin': 'c'});
  var charC = ChCharacter(entry: {'simplified': 'c', 'pinyin': 'c'});
  var rule = Rule();
  /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

  // var Dictionary
  group('Dictionary', () {
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
    var d = Dictionary();
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('initializing empty', () {
      expect(d.name, '');
      expect(d.sortingKey, '');
      expect(d.sortingOrd, '');
      expect(d.characters.length, 0);
      expect(d.rules.length, 0);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
    var copy = d.copyWith(sortingKey: 'pinyin', sortingOrd: 'ascending');
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('create copy', () {
      expect(copy.sortingKey, 'pinyin');
      expect(copy.sortingOrd, 'ascending');
      expect(d == copy, true);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
    var filled = ChDictionary(
      name: 'D',
      rules: [rule],
      characters: [empty, char, charA, charC, charB],
    );
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('initializing populated', () {
      expect(filled.length, 4);
      expect(filled.createInstance().length, 0);

      expect(filled[0], filled[['八', '', 'ba1']]);
      expect(filled['c'].length, 2);
      expect(
        filled[0],
        filled[[
          ['八', '', 'ba1'],
        ]][0],
      );
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('sorting and combining', () {
      filled.sortingKey = 'pinyin';
      filled.sortingOrd = 'descending';
      expect(filled[0], filled[['a', '', 'd']]);
      expect((filled[[0, 2]] + filled[3]).length, 3);
      expect((filled[3] + filled[[0, 2]] - filled[3]).length, 2);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('search', () {
      expect(filled.search(pattern: 'c').length, 2);
      expect(filled.search(pattern: 'c', category: 'simplified').length, 1);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
  });
}
