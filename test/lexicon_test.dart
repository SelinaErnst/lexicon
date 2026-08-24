import 'package:lexicon/lexicon/dictionary.dart';
import 'package:lexicon/lexicon/utils.dart';
import 'package:test/test.dart';
import 'dart:io';
import 'package:logging/logging.dart';

import 'helper.dart';

void main() async {
  Logger.root.clearListeners();
  Logger.root.onRecord.listen((record) {
    print('[${record.level.name}] (${record.loggerName}): ${record.message}');
  });

  final synatxMap = readJSONSync<Map<String, dynamic>>(
    File('assets/syntax.json'),
  );
  final colorMap = readJSONSync<Map<String, dynamic>>(
    File('assets/colors.json'),
  );

  test('create dictionary of characters', () async {
    final catMap = readJSONSync<Map<String, dynamic>>(
      File('assets/categories.json'),
    );
    Dictionary dictionary = ChDictionary();
    dictionary.addSyntax(synatxMap, colorMap);
    await dictionary.read(File('assets/MCD.jsonl'), categories: catMap);
    expect(dictionary.isNotEmpty, true);
  });

  test('test', () async {
    var d = await getExample();
    expect(d.isNotEmpty,true);
  });
}
