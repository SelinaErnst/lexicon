import 'package:lexicon/lexicon/utils.dart';
import 'package:test/test.dart';
import 'package:lexicon/lexicon.dart';

void main() {
  runCharacterTests();
}

void runCharacterTests() {
  group('Character', () {

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
    var empty = ChCharacter();
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
    test('initializing empty', () {
      expect(empty.identifier.length, 3);
      expect(empty.identifier, ['', '', '']);
      expect(empty.isEmpty, true);
      expect(empty.get('english'), null);
    }, skip: false);

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
    var copy = empty.copyWith(specs: {'english': List<String>});
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('create copy', () {

      expect(copy.exact(empty, ignoreNull: true), true);
      expect(copy.exact(empty, ignoreNull: false), false);

      copy.update({
        'english': ['eng'],
      });

      expect(copy == copy.copy(), true);
      expect(copy == empty, true);
      expect(copy.exact(empty, ignoreNull: true), false);
      expect(empty.baseCategories, copy.baseCategories);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('populate copy', () {
      var populated = empty.copyWith(
        specs: {'english': List<String>},
        entry: {
          'simplified': '八',
          'pinyin': 'bā',
          'english': ['8'],
        },
      );
      var more = populated.copyWith(entry: {'pinyin': 'ba.'});

      expect(more == populated, false);
      expect(populated.baseCategories, more.baseCategories);

      expect(populated['simplified'], '八');
      expect(more['simplified'], '八');
      expect(populated['pinyin'], 'ba1');
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
    var charE = ChCharacter(entry: {'simplified': 'a', 'traditional': 'a'});
    var charA = ChCharacter(
      entry: {'simplified': 'a', 'traditional': 'a', 'pinyin': 'a1'},
    );
    var charB = ChCharacter(
      entry: {'simplified': 'b', 'traditional': 'b', 'pinyin': 'b1'},
    );
    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('uniqueID', () {
      expect(charE.uniqueID(method: 'unicode'), 'empty_char');
      expect(charE.uniqueID(method: 'symbol'), 'empty_char');
      expect(charE.uniqueID(method: 'hash'), 'empty_char');
      expect(
        charA.uniqueID(method: 'hash').length,
        charB.uniqueID(method: 'hash').length,
      );
      expect(
        charA.uniqueID(method: 'symbol').length,
        charB.uniqueID(method: 'symbol').length,
      );
      expect(
        charA.uniqueID(method: 'unicode').length,
        charB.uniqueID(method: 'unicode').length,
      );

      try {
        charE.uniqueID(method: 'test');
      } catch (e) {
        // print(e);
        expect(isError(e.runtimeType), true);
      }
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('pinyin', () {
      expect(charA.toneMarkedPinyin, 'ā');
      expect(charA.numericPinyin, 'a1');
      charA['pinyin'] = 'ba1ba5 shi4 wo3 de.';
      expect(charA.toneMarkedPinyin, 'bāba shì wǒ de.');
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    var char = ChCharacter(
      entry: {
        'simplified': '八',
        'pinyin': 'ba1',
        'variants': ['八 [akn] 勹', ' 八', 'scsd', ''],
      },
      specs: {
        'strokes_count': int,
        'english': List<String>,
        'images': Map<String, String>,
        'variants': List<String>,
      },
    );

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    test('set, get and remove', () {
      expect(char.get('pinyin'), char['pinyin']);
      char['pinyin'] = 'bā.';
      expect(char.get('pinyin'), 'ba1.');
      char['pinyin'] = 'bā, hā';
      expect(char.get('pinyin'), 'ba1, ha1');
      char.remove('pinyin');
      expect(char.get('pinyin'), '');

      char.set('english', ['e']);
      expect(char['english'], ['e']);

      char.update({'english': 'a'});
      expect(char['english'], ['e']);
      char.set('english', 'z', force: true);
      expect(char['english'], ['e']);

      // print(char.variants);
      expect(char.variants, ['八', '八']);
    });

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */

    var one = ChCharacter(
      entry: {'simplified': '八', 'pinyin': 'ba1'},
      specs: {'images': Map<String, String>},
    );

    var weird = ChCharacter(
      entry: {
        'simplified': '八',
        'pinyin': 'ba1',
        'images': ['x', 'y'],
      },
      specs: {'images': List<String>},
    );

    var small = ChCharacter(entry: {'simplified': '八', 'pinyin': 'ba1'});

    /* –––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––– */
    
    test('images', () {

      expect(one['images'], null);
      expect(weird['images'], ['x', 'y']);
      expect(small.get('images'), null);

      expect(one.images(), null);
      expect(weird.images(), null);
      expect(small.images(), null);

      one.updateCategoryMap('images', {'x': 'x'});

      expect(
        isExactType(one['images'].runtimeType, one.categories['images']),
        true,
      );

      expect(one['images'], {'x': 'x'});
      one.updateCategoryMap('images', {'y': 'y'});
      expect(one['images'], {'x': 'x', 'y': 'y'});

      expect(
        isExactType(one.images().runtimeType, one.categories['images']),
        true,
      );

      one.remove('images');
      expect(one['images'], null);
    });
  });
}
