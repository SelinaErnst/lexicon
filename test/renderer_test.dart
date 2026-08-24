import 'package:lexicon/lexicon/dictionary.dart';
import 'package:lexicon/lexicon/template_renderer.dart';
import 'package:lexicon/lexicon/text_modifier.dart';
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
    String container = 'H:[nb|grey|available]:CLASSIFIER: ';
    print(getContSpecs(container));
    container = '<H:[nb|grey|available]:CLASSIFIER: >';
    print(getContSpecs(container));
    container = 'H:[nb|grey|available]:CLASSIFIER: >';
    print(getContSpecs(container));
    container = '<H:[nb|grey|available]:CLASSIFIER: ';
    print(getContSpecs(container));
    container = '<H[nb|grey|available]:CLASSIFIER: ';
    print(getContSpecs(container));
    container = '<L:[]:L> <H:[nb|grey|available]:CLASSIFIER: ';
    print(getContSpecs(container));
  });

  group('Content Controller', () {
    test('head', () {
      ContentController cc1 = ContentController(
        'H:[nb|grey|available]:CLASSIFIER: ',
        mod,
      );
      // ContentController cc2 = ContentController(
      //   'H:[nb|grey|availablee]:CLASSIFIER: ',
      //   mod,
      // );
      // ContentController cc3 = ContentController(
      //   'H:[nb|greyy|available]:CLASSIFIER: ',
      //   mod,
      // );
      print(cc1.writeHead);
    });
    test('content', () {
      String container;
      container = '<L:[dot|l|normal]:english>';
      container = '<L:[point|nl|normal]:english>';
      Content cont = Content(container, dict[0], mod);
      print(cont.writeContent());
    });

    test('block', () {
      mod.command = 'LEFT';
      ContentBlock cb = ContentBlock(dict[0], cmd: 'LEFT', mod: mod);
      print(cb.writeBlock('###'));
    });
    test('writer', () {
      String path =
          '/home/selina/Applications/MyApps/suhan/packages/lexicon/assets/pleco.chd';

      final Writer w = Writer(mod, tmplFile: File(path));
      // print(w.compile(dict[0]).result);
      // expect(w.character!=null,true);
      // print(['Data',dict[1].data]);
      print(w.compile(dict[1]).result);
      // print(['Data',dict[2].data]);
      print(w.compile(dict[2]).result);
      // print(['Data',dict[3].data]);
      print(w.compile(dict[3]).result);
    });
  });
}
