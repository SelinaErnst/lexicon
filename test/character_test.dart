import 'package:suhan_lexicon/src/errors.dart';
import 'package:suhan_lexicon/src/utils.dart';
import 'package:test/test.dart';
import 'package:suhan_lexicon/suhan_lexicon.dart';
import 'package:logging/logging.dart';
import 'helper.dart';

void main() {
  setUpAll(() {
    // Logger.root.clearListeners();
    Logger.root.onRecord.listen((record) {
      print('[${record.level.name}] (${record.loggerName}): ${record.message}');
    });
  });

  group('Character', () {
    late Character char;
    late Character allchar;
    late ChCharacter empty;
    late ChCharacter simple;
    late ChCharacter filled;
    late ChCharacter charA;

    setUp(() {
      Logger.root.level = Level.OFF;
      allchar = Character();
      char = Character(
        entry: {
          'simplified': '八',
          'pinyin': 'ba1',
          'english': ['8'],
          'strokes_count': 1,
          'images': {'a': 'test'},
        },
        strict: false,
        baseCategories: ['simplified', 'traditional', 'pinyin'],
      );
      empty = ChCharacter();
      simple = ChCharacter(
        entry: {
          'simplified': '八',
          'pinyin': 'bā',
          'english': ['8'],
        },
      );
      filled = ChCharacter(
        mapColor: getColors(),
        mapSyntax: getSyntax(),
        mapColorFav: getFaves(),
        categories: {
          'english': List<String>,
          'strokes_count': int,
          'images': Map<String, String>,
          'variants': List<String>,
        },
        entry: {
          'simplified': '八',
          'pinyin': 'bā',
          'english': ['8'],
          'variants': ['八 [akn] 勹', ' 八', 'scsd', ''],
          'images': {'a': 'test'},
        },
      );
      charA = ChCharacter(entry: {'simplified': 'a', 'traditional': 'x'});
    });

    test('empty Character', () {
      final emptyChar = Character();
      expect(emptyChar.baseCategories.length, 0);
      expect(emptyChar.identifier.isEmpty, true);
      expect(emptyChar.isEmpty, true);
      expect(emptyChar.isCompletelyEmpty, true);
      expect(emptyChar.uniqueID(), '0000000000');
    });

    test('empty ChCharacter', () {
      final emptyChar = ChCharacter();
      expect(emptyChar.baseCategories, ['simplified', 'traditional', 'pinyin']);
      expect(emptyChar.identifier, ['', '', '']);
      expect(emptyChar.isEmpty, true);
      expect(emptyChar.isCompletelyEmpty, true);
      expect(emptyChar.get('english'), null);
      expect(emptyChar.contains('simplified'), true);
      expect(emptyChar.uniqueID(), 'empty_char');
    });

    test('create dictionary by adding characters together', () {
      var d = empty + simple + filled + charA + allchar;
      expect(d.length, 2);
      expect(simple.exact(d[0]), true);
      expect(filled.exact(d[0]), false);
      expect(() => allchar + '', throwsA(isA<LexiconException>()));
    });

    test('comparing characters', () {
      var copy = empty.reconfigure(categories: {'test': int});
      expect(empty == copy, true);
      expect(empty.exact(copy, ignoreNull: false), false);
      expect(empty != char, true);
      expect(simple == char, true);
      expect(simple == filled, true);
      expect(filled == filled, true);
      expect(copy.isCompletelyEmpty, true);
      expect(simple.isCompletelyEmpty, false);
      expect(filled.isCompletelyEmpty, false);
    });

    test('relax character strictness', () {
      expect(allchar.strict, true);
      var relaxed1 = allchar.relax();
      var relaxed2 = allchar.relax();
      expect(relaxed1.strict, false);
      relaxed1.update({'simplified': 'test', 'pinyin': 'more'});
      relaxed2.update({'simplified': 'more', 'pinyin': 'test'});
      expect(relaxed1, relaxed2);
      expect(relaxed1.identifier, relaxed2.identifier);
      expect(relaxed1.baseCategories.isEmpty, true);
      expect(relaxed1.isEmpty, true);
      expect(relaxed1.data.isEmpty, false);

      var relaxed3 = char.relax();
      relaxed3.update({'simplified': 'test', 'pinyin': 'more'});
      expect(relaxed3.baseCategories.isEmpty, false);
      expect(relaxed3.identifier, ['test', '', 'more']);
    });

    test('predefined categories and dtypes', () {
      expect(filled.categories['simplified'], String);
      expect(filled.categories['strokes_count'], int);
      expect(filled.categories['test'], null);

      expect(filled['simplified'], '八');
      expect(filled['strokes_count'], null);
      expect(() => filled['test'], throwsA(isA<LexiconException>()));
    });
    test('cannot change category types if strict', () {
      expect(simple.strict, true);
      expect(
        () => simple.categories['simplified'] = List<String>,
        throwsA(isA<Error>()),
      );
    });

    test('not strict characters can change category dtype', () {
      expect(char.strict, false);
      expect(char['images'], {'a': 'test'});
      char.updateCategoryMap('images', {'b': 'test'});
      expect(char['images'], {'a': 'test', 'b': 'test'});
      char.categories['images'] = List<String>;
      expect(char['images'], {'a': 'test', 'b': 'test'});
      expect(char.copy().categories['images'] != List<String>, true);
      expect(char.copy()['images'], {'a': 'test', 'b': 'test'});
      expect(
        char.copyWith(merge: false, {
          'images': {'c': 'test'},
        })['images'],
        {'c': 'test'},
      );
      expect(
        char.copyWith(merge: true, {
          'images': {'c': 'test'},
        })['images'],
        {'a': 'test', 'b': 'test', 'c': 'test'},
      );
      expect(
        () => char.updateCategoryMap('images', {'c': 'test'}),
        throwsA(isA<LexiconException>()),
      );
      char['images'] = 0;
      expect(char.categories['images'], int);
      expect(char.get('images'), 0);
    });

    test('restrict character', () {
      char['images'] = 0;
      var restricted = char.restrict();
      expect(
        () => restricted['images'] = 'test',
        throwsA(isA<LexiconException>()),
      );
    });

    test('get category content', () {
      expect(filled.get('pinyin'), 'ba1');
      expect(filled.get('test'), null);
    });

    test('update category content', () {
      expect(simple == filled, true);
      simple.update({
        'english': ['eight'],
      });
      filled.update({
        'english': ['eight'],
      });
      expect(simple.exact(filled, ignoreNull: true), false);

      filled.update({'english': 'a'});
      expect(filled['english'], ['eight']);
      expect(filled['english'].runtimeType, filled.categories['english']);

      filled.update({
        'images': {'x': 'test'},
      });
      expect(
        filled['images'].runtimeType == filled.categories['images'],
        false,
      );
      expect(
        isExactType(filled['images'].runtimeType, filled.categories['images']),
        true,
      );

      filled.update({
        'images': {'y': 'test'},
      });
      expect(filled['images'], {'y': 'test'});
    });

    test('update category maps', () {
      var newFilled = filled.copyWith({
        'images': {'x': 'x'},
      });

      filled.updateCategoryMap('images', null);
      expect(filled['images'], null);
      filled.updateCategoryMap('images', {'x': 'x'});
      filled.updateCategoryMap('images', {'y': 'y'});
      expect(filled['images'], {'x': 'x', 'y': 'y'});

      newFilled.update(merge: true, {
        'images': {'y': 'y'},
      });
      expect(newFilled.images(), filled['images']);

      expect(
        () => filled.updateCategoryMap('test', {'y': 'y'}),
        throwsA(isA<LexiconException>()),
      );
      expect(
        () => filled.updateCategoryMap('english', {'y': 'y'}),
        throwsA(isA<LexiconException>()),
      );
    });

    test('set category content', () {
      filled.set('english', ['e']);
      expect(filled['english'], ['e']);
      filled.set('english', 'z');
      expect(filled['english'], ['e']);
      expect(
        () => filled.set('english', 'z', force: false),
        throwsA(isA<LexiconException>()),
      );
      expect(
        () => filled.set('test', 'z', force: false),
        throwsA(isA<LexiconException>()),
      );
    });

    test('remove category content', () {
      filled.remove('pinyin');
      expect(filled.get('pinyin'), '');
      filled.remove('english');
      expect(filled['english'], null);
      filled.remove('test');
      expect(filled.get('test'), null);
    });

    test('ChCharacter atributes', () {
      expect(filled.baseCategories, ['simplified', 'traditional', 'pinyin']);
      expect(filled.variants(), ['八', '八']);
      expect(simple.variants().isEmpty, true);
      expect(filled.images(), {'a': 'test'});
      expect(simple.images(), null);
      expect(simple.uniqueWords, ['八', '八']);
      expect(charA.uniqueWords, ['a', 'x']);
      expect(filled.filled.contains('simplified'), true);
      expect(empty.missing.contains('english'), false);
      expect(filled.missing.contains('strokes_count'), true);
      expect(filled.toMap()['strokes_count'], null);
    });

    test('uniqueID requires pinyin', () {
      expect(empty.uniqueID(method: 'unicode'), 'empty_char');
      expect(charA.uniqueID(method: 'unicode'), 'empty_char');
      expect(charA.uniqueID(method: 'symbol'), 'empty_char');
      expect(charA.uniqueID(method: 'hash'), 'empty_char');
    });

    test('pinyin conversion', () {
      expect(filled.toneMarkedPinyin, 'bā');
      expect(filled.numericPinyin, 'ba1');
      charA['pinyin'] = 'ba1ba5 shi4 wo3 de.';
      expect(charA.toneMarkedPinyin, 'bāba shì wǒ de.');
    });

    test('reconfigure character', () {
      var simpleCopy = simple.reconfigure(
        categories: {'english': int, 'test': int},
      );
      expect(simpleCopy == simple, true);
      expect(simpleCopy.exact(simple, ignoreNull: true), true);
      expect(simpleCopy.exact(simple, ignoreNull: false), false);

      allchar.update({'pinyin': 'ba1'});
      expect(allchar.get('pinyin'), null);
      var newChar = allchar.reconfigure(categories: {'pinyin': String});
      newChar.update({'pinyin': 'ba1'});
      expect(newChar.get('pinyin'), 'ba1');
    });

    test('copy with other entry', () {
      expect(simple == simple.copyWith({'pinyin': 'ba'}), false);
      var copy = filled.copyWith({
        'pinyin': 'ba',
        'images': {'b': 'test'},
        'english': ['test'],
      }, merge: true);
      expect(filled['images'], {'a': 'test'});
      expect(copy['images'], {'a': 'test', 'b': 'test'});
      expect(filled['english'], ['8']);
      expect(copy['english'], ['8', 'test']);
      expect(filled['pinyin'], 'ba1');
      expect(copy['pinyin'], 'ba');
    });

    test('create copy and compare', () {
      var filledCopy = filled.copy();
      expect(simple == filledCopy, true);
      expect(filledCopy.exact(filled, ignoreNull: false), true);
    });

    test('use text modifier', () {
      empty.update({'simplified': '八 abc'});
      expect(empty['simplified'], '八 abc');
      empty.modify('simplified').findFirstChar('chinese');
      expect(empty['simplified'], '八');
      empty.modify('simplified').findFirstChar('english');
      expect(empty['simplified'], '');

      empty.update({'pinyin': 'ba1'});
      expect(empty['pinyin'], 'ba1');
      empty.modify('pinyin', transform: false).toToneMarkedPinyin();
      expect(empty['pinyin'], 'ba1');
      empty.modify('pinyin', transform: true).toToneMarkedPinyin();
      expect(empty['pinyin'], 'bā');

      expect(empty['simplified'], '');
      empty.modify('simplified').set('HaHa').removeSyntax();
      expect(empty['simplified'], 'HaHa');
      empty.modify('simplified').replaceAll('Ha', 'X');
      expect(empty['simplified'], 'XX');

      expect(char['images']['a'], 'test');
      char.modify('images').replaceAll(r'\w+', 'X');
      expect(char['images'], {'a': 'X'});

      empty.modify('abc').replaceAll('', 'X');
      expect(empty.get('abc'), null);
      expect(() => empty['abc'], throwsA(isA<LexiconException>()));
    });

    test('use info to show character data', () {
      expect(() => filled.info(show: false), returnsNormally);
      expect(filled.toMarkdownTable().runtimeType, String);
    });

    test('base categories have to be strings', () {
      Character chartest = Character(
        baseCategories: ['test'],
        categories: {'test': int},
      );
      expect(
        () => chartest.set('test', 0, force: false),
        throwsA(isA<LexiconException>()),
      );
      expect(chartest.categories['test'], String);
      expect(Character(baseCategories: ['test'])['test'], '');
      chartest = Character(
        baseCategories: ['test'],
        categories: {'test': int},
        entry: {'test': 0},
      );
      expect(chartest['test'], '');
    });

    test('add syntax', () {
      var syntax = getSyntax();
      var colors = getColors();
      var faves = getFaves();

      expect(simple.runtimeType, ChCharacter);
      simple.addSyntax(syntax, colors, mapColorFav: faves);
      expect(simple, simple.relax());

      char.addSyntax(syntax, colors, mapColorFav: faves);
      var newChar = char.copyWith({'test': '八 [ba1]'}, merge: false);
      expect(
        newChar.modify('test', transform: true).linkPronunciation().result,
        '八 [ba1]',
      );
      expect(newChar['test'], '八 [ba1]');
    });
  });
}
