import 'package:lexicon/src/dictionary.dart';
import 'package:lexicon/src/errors.dart';
import 'package:lexicon/src/template_renderer.dart';
import 'package:lexicon/src/text_modifier.dart';
import 'package:test/test.dart';
import "package:logging/logging.dart";
import "dart:io";
import 'helper.dart';

void main() async {
  late Map<String, dynamic> mapSyntax;
  late Map<String, dynamic> mapColor;
  late Map<String, dynamic> mapColorFav;
  late Dictionary dict;
  final TextModifier<String> mod = TextModifier('');
  // String container = 'H:[nb|grey|available]:CLASSIFIER: ';
  // String container = 'H:[nb|grey|available]:CLASSIFIER: ';

  setUpAll(() async {
    Logger.root.level = Level.OFF;
    Logger.root.onRecord.listen((record) {
      print('[${record.level.name}] (${record.loggerName}): ${record.message}');
    });

    mapSyntax = getSyntax();
    mapColor = getColors();
    mapColorFav = getFaves();
    dict = await getExample();
    mod.addSyntax(
      mapSyntax: mapSyntax,
      mapColor: mapColor,
      mapColorFav: mapColorFav,
    );
  });

  test('container specs', () {
    final good = {
      'type': 'H',
      'specs': ['nb', 'grey', 'available'],
      'data': 'CLASSIFIER: ',
    };
    final bad = {
      'type': 'H',
      'specs': ['normal', 'normal', 'normal'],
      'data': 'PLACEHOLDER ',
    };
    String container = 'H:[nb|grey|available]:CLASSIFIER: ';
    expect(getContSpecs(container, 'H'), good);
    container = '<H:[nb|grey|available]:CLASSIFIER: >';
    expect(getContSpecs(container, 'H'), good);
    container = 'H:[nb|grey|available]:CLASSIFIER: >';
    expect(getContSpecs(container, 'H'), good);
    container = '<H:[nb|grey|available]:CLASSIFIER: ';
    expect(getContSpecs(container, 'H'), good);
    container = 'H:[nb|grey|available]:CLASSIFIER: ';
    expect(getContSpecs(container, 'H'), good);
    container = '<H[nb|grey|available]:CLASSIFIER: ';
    expect(getContSpecs(container, 'H'), bad);
    container = '<H[nb|grey|avail]:CLASSIFIER: ';
    expect(getContSpecs(container, 'H'), bad);
    container = '<H[nb|grey|avail] ';
    expect(getContSpecs(container, 'H'), bad);
    container = '<H:[]:PLACEHOLDER > <H:[nb|grey|available]:CLASSIFIER: ';
    expect(getContSpecs(container, 'H'), bad);
  });

  group('Content Controller', () {
    test('head', () {
      String cont = '';
      ContentController cc1 = ContentController(cont, mod);
      expect(cc1.writeContent('xxx'), 'PLACEHOLDER xxx');

      cont = 'H:[nb|grey|available]:CLASSIFIER: ';
      ContentController cc2 = ContentController(cont, mod);
      expect(cc2.writeContent('xxx'), 'CLASSIFIER: xxx');

      expect(
        () => ContentController(cont, TextModifier('')),
        throwsA(isA<LexiconException>()),
      );
    });

    test('write list content', () {
      Content cont;
      cont = Content('<L:[dot|l|normal]:english>', dict[0], mod);
      expect(cont.writeContent(), 'eight · 8');
      cont = Content('<L:[point|nl|normal]:english>', dict[0], mod);
      expect(cont.writeContent(), '◼ eight◼ 8');
      cont = Content('<L:[point|l|normal]:english>', dict[0], mod);
      expect(cont.writeContent(), '◼ eight ◼ 8');
      cont = Content('<L:[point|normal|normal]:english>', dict[0], mod);
      expect(cont.writeContent(), '◼ eight ◼ 8');
      cont = Content('<T:[point|normal|normal]:english>', dict[0], mod);
      expect(cont.writeContent(), '◼[eight, 8]');
      cont = Content('', dict[0], mod);
      expect(cont.writeContent(), '');
      cont = Content('<I:[]:english>', dict[0], mod);
      expect(cont.writeContent(), '[eight, 8]');
    });

    test('write string content', () {
      Content cont;
      cont = Content('<T:[point|normal|normal]:simplified>', dict[0], mod);
      expect(cont.writeContent(), '◼八');
      cont = Content('<T:[big|normal|normal]:simplified>', dict[0], mod);
      expect(cont.writeContent(), 'AA10八');
      cont = Content('<>', dict[0], mod);
      expect(cont.writeContent(), '');
      cont = Content('<L:[]:simplified>', dict[0], mod);
      expect(cont.writeContent(), '八');
      cont = Content('<L:[dot|nl|normal]:simplified>', dict[0], mod);
      expect(cont.writeContent(), '八');
    });

    test('block', () {
      ContentBlock cb;
      cb = ContentBlock(dict[0], cmd: 'LEFT', mod: mod);
      expect(cb.writeBlock('###'), '1A0A###');
      cb = ContentBlock(dict[0], cmd: 'abc', mod: mod);
      expect(cb.writeBlock('###'), '###');
      cb = ContentBlock(dict[0], cmd: 'INDENT', mod: mod);
      expect(cb.writeBlock('###'), '1A0P###');
      cb = ContentBlock(dict[0], cmd: 'IND', mod: mod);
      expect(cb.writeBlock('###'), '1A0P###');
    });
    test('writer', () {
      String path ='assets/pleco.chd';

      final Writer w = Writer(mod, tmplFile: File(path));
      expect(w.compile(dict[1]).result.isNotEmpty, true);
      expect(w.compile(dict[2]).result.isNotEmpty, true);
      expect(w.compile(dict[3]).result.isNotEmpty, true);
      expect(w.character == dict[3], true);
      expect(w.text != w.result, true);
    });
  });
}
