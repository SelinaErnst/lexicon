import 'package:logging/logging.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'character.dart';
import 'rule.dart';
import 'utils.dart';
import 'text_modifier.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as p;

final Logger _log = Logger('DictionaryEngine');

/* ================================================================ */
/*                           CONFIGURATION                          */
/* ================================================================ */

final Map<String, Type> _mapTypes = {
  'list': List<String>,
  'str': String,
  'int': int,
  'dict': Map<String, String>,
};

const Map<String, Set<String>> _extOptions = {
  '.txt': {'pleco', 'txt', '.txt', 'all'},
  '.jsonl': {'chd', 'jsonl', '.jsonl', 'all'},
  '.db': {'db', '.db', 'sql', 'base', 'all'},
};
final Set<String> _expOptions = _extOptions.values.expand((set) => set).toSet();

/* ================================================================ */
/*                              HELPERS                             */
/* ================================================================ */

String? getExt(
  String? choice, {
  Map<String, Set<String>> extOpt = _extOptions,
}) {
  if (choice == null) return null;

  final matchEntry = extOpt.entries.firstWhereOrNull(
    (entry) => entry.value.contains(choice),
  );

  return matchEntry!.key;
}

class Dictionary extends Iterable<Character> {
  late String name;
  late List<Character> _characters;
  late List<Rule> _rules;

  Set<String> get _sortKeys => const {};
  Set<String> get _sortOrder => const {'ascending'};

  late String _sortKey;
  late String _sortOrd;

  late Map<String, dynamic>? _mapSyntax;
  late Map<String, dynamic>? _mapColor;
  late Map<String, dynamic>? _mapColorFav;

  late Map<String, Type> categories;

  Dictionary({
    String? name,
    dynamic characters,
    dynamic rules,
    Map<String, Type>? categories,
    String? sortingKey,
    String? sortingOrd,
  }) : name = name ?? '' {
    _setCharacters(characters);
    _setRules(rules);

    this.categories = categories ?? {};
    _sortKey = sortingKey ?? '';
    _sortOrd = sortingOrd ?? '';

    sort();
  }

  @protected
  Dictionary createInstance({
    String? name,
    dynamic characters,
    dynamic rules,
    Map<String, Type>? categories,
    String? sortingKey,
    String? sortingOrd,
  }) {
    return Dictionary(
      name: name ?? '',
      characters: characters,
      rules: rules,
      categories: categories ?? {},
      sortingKey: sortingKey ?? _sortKey,
      sortingOrd: sortingOrd ?? _sortOrd,
    );
  }

  Dictionary rename(String name) {
    this.name = name;
    return this;
  }

  Dictionary copy() {
    return createInstance(
      name: name,
      characters: characters.map((char) => char.copy()).toList(),
      rules: rules.map((rule) => rule.copy()).toList(),
      categories: Map<String, Type>.from(categories),
      sortingKey: _sortKey,
      sortingOrd: _sortOrd,
    );
  }

  Dictionary copyWith({
    String? name,
    dynamic characters,
    dynamic rules,
    Map<String, Type>? categories,
    String? sortingKey,
    String? sortingOrd,
  }) {
    return createInstance(
      name: name ?? this.name,
      characters:
          characters ?? this.characters.map((char) => char.copy()).toList(),
      rules: rules ?? this.rules.map((rule) => rule.copy()).toList(),
      categories: categories ?? Map<String, Type>.from(this.categories),
      sortingKey: sortingKey ?? _sortKey,
      sortingOrd: sortingOrd ?? _sortOrd,
    );
  }

  Dictionary empty({bool keepRules = true}) {
    _characters = [];
    if (!keepRules) _rules = [];
    return this;
  }

  List<Character> get characters => _characters;
  set characters(dynamic value) {
    _setCharacters(value);
    sort();
  }

  void _setCharacters(dynamic charList) {
    if (charList is List) {
      try {
        charList = List<Character>.from(charList);
        _characters = charList
            .whereType<Character>()
            .toSet()
            .where((char) => !char.isEmpty)
            .toList();
      } catch (e) {
        if (charList is Iterable) {
          _characters = [];
          for (final item in charList) {
            final char = item as Map<String, dynamic>;
            // print(Character(specs: {'simplified':String,'traditional':String,'pinyin':String}, entry: char));
            final character = ChCharacter(entry: char);
            if (!character.isEmpty) _characters.add(character);
          }
        }
      }
    } else if (charList is Dictionary) {
      _characters = List.from(charList.characters);
    } else if (charList is Character && !charList.isEmpty) {
      _characters = [charList];
    } else {
      _characters = [];
    }
  }

  List<Rule> get rules => _rules;
  set rules(dynamic value) {
    _setRules(value);
  }

  void _setRules(dynamic ruleList) {
    if (ruleList is List) {
      _rules = ruleList
          .whereType<Rule>()
          .toSet()
          .where((rule) => !rule.isEmpty)
          .toList();
    } else if (ruleList is Rule) {
      _rules = [ruleList];
    } else {
      _rules = [];
    }
  }

  /* ================================================================ */
  /*                           BASIC METHODS                          */
  /* ================================================================ */

  /* ––––––––––––––––––– operators / magic methods –––––––––––––––––– */

  @override
  String toString() {
    final header = 'Dict <$name>: ${characters.length} (depth)';
    if (characters.isEmpty) return header;

    final buffer = StringBuffer('$header\n');
    for (var i = 0; i < characters.length; i++) {
      final number = i.toString().padLeft(4);
      buffer.write('$number: ${characters[i]}\n');
    }
    return buffer.toString();
  }

  List<dynamic> toMapList({bool growable = true}) {
    return convertMixedList(characters);
  }

  @override
  Iterator<Character> get iterator => characters.iterator;

  @override
  int get hashCode {
    const charEquality = UnorderedIterableEquality<Character>();
    const ruleEquality = UnorderedIterableEquality<Rule>();
    return Object.hash(
      name,
      ruleEquality.hash(rules),
      charEquality.hash(characters),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Dictionary) return false;
    const charEquality = UnorderedIterableEquality<Character>();
    const ruleEquality = UnorderedIterableEquality<Rule>();

    return name == other.name &&
        ruleEquality.equals(rules, other.rules) &&
        charEquality.equals(characters, characters);
  }

  dynamic operator [](dynamic identifier) {
    if (identifier is int) {
      return getCharacter(identifier);
    }
    if (identifier is String) {
      return getSubset(identifier);
    }
    if (identifier is List && identifier.length == 3) {
      try {
        return getCharacter(
          convertListToType(identifier, List<String>) as List<String>,
        );
      } catch (e) {
        _log.finer('');
      }
    }
    if (identifier is List) {
      return getSubset(identifier);
    }

    return null;
  }

  Dictionary? getSubset(dynamic identifier) {
    final List<Character> matchingCharacters = [];
    if (identifier is List) {
      for (final id in identifier) {
        final Character? char = getCharacter(id);
        if (char != null) matchingCharacters.add(char.copy());
      }
    } else if (identifier is String) {
      final List<List<String>> charactersIDList =
          _charactersID.toList() as List<List<String>>;
      for (final List<String> charID in charactersIDList) {
        if (charID.contains(identifier)) {
          final Character? char = getCharacter(charID);
          if (char != null) matchingCharacters.add(char.copy());
        }
      }
    }
    return copyWith(name: name, characters: matchingCharacters);
  }

  Character? getCharacter(dynamic identifier) {
    if (identifier == null) return null;
    if (identifier is int) {
      if (identifier >= 0 && identifier < characters.length) {
        return characters[identifier];
      }
    }
    if (identifier is Character) identifier = identifier.identifier;
    if (identifier is List) {
      const listEquality = ListEquality<dynamic>();
      if (!_charactersID.containsElement(identifier)) return null;
      for (final char in characters) {
        if (listEquality.equals(char.identifier, identifier)) return char;
      }
    }
    return null;
  }

  Dictionary operator -(dynamic other) {
    final remainCharacters = List<Character>.from(characters);
    final remainRules = List<Rule>.from(rules);

    const listEquality = ListEquality<dynamic>();
    final Set<dynamic> charactersIDSet = _charactersID;
    final Set<Rule> rulesIDSet = rules.toSet();

    if (other is Character && !other.isEmpty) {
      if (charactersIDSet.containsElement(other.identifier)) {
        remainCharacters.removeWhere(
          (Character char) =>
              listEquality.equals(char.identifier, other.identifier),
        );
      }
    } else if (other is Rule && !other.isEmpty) {
      if (rulesIDSet.containsElement(other)) {
        remainRules.remove(other);
      }
    } else if (other is Dictionary) {
      final otherIDs = other.characters.map((c) => c.identifier).toList();
      remainCharacters.removeWhere(
        (Character char) => otherIDs.containsElement(char.identifier),
      );
      remainRules.removeWhere((rule) => other.rules.contains(rule));
    } else {
      _log.warning(
        'Subtraction Ignored: Unsupported type ${other.runtimeType}',
      );
    }
    return copyWith(characters: remainCharacters, rules: remainRules);
  }

  Dictionary operator +(dynamic other) {
    final comboCharacters = List<Character>.from(characters);
    final comboRules = List<Rule>.from(rules);

    final Set<dynamic> charactersIDSet = _charactersID;
    final Set<Rule> rulesIDSet = rules.toSet();

    if (other is Character && !other.isEmpty) {
      if (!charactersIDSet.containsElement(other.identifier)) {
        comboCharacters.add(other);
      } else {
        _log.finer(
          'Add Ignored: Character $other is either empty or exists already.',
        );
      }
    } else if (other is Rule && !other.isEmpty) {
      if (!rulesIDSet.containsElement(other)) {
        comboRules.add(other);
      } else {
        _log.finer(
          'Addition Ignored: Rule $other is either empty or exists already.',
        );
      }
    } else if (other is Dictionary) {
      for (final char in other.characters) {
        if (charactersIDSet.add(char.identifier) && !char.isEmpty) {
          comboCharacters.add(char);
        } else {
          _log.finer(
            'Addition Ignored: Character $char is either empty or exists already.',
          );
        }
      }
      for (final rule in other.rules) {
        if (rulesIDSet.add(rule) && !rule.isEmpty) {
          comboRules.add(rule);
        } else {
          _log.finer(
            'Addition Ignored: Rule $rule is either empty or exists already.',
          );
        }
      }
    } else {
      _log.warning('Addition Ignored: Unsupported type ${other.runtimeType}');
    }
    return copyWith(characters: comboCharacters, rules: comboRules);
  }

  Dictionary add(dynamic other) {
    // adds to current dictionary
    final Set<dynamic> charactersIDSet = _charactersID;
    final Set<Rule> rulesIDSet = rules.toSet();

    if (other is Character && !other.isEmpty) {
      if (!charactersIDSet.containsElement(other.identifier)) {
        characters.add(other);
      } else {
        _log.finer(
          'Add Ignored: Character $other is either empty or exists already.',
        );
      }
    } else if (other is Rule && !other.isEmpty) {
      if (!rulesIDSet.containsElement(other)) {
        rules.add(other);
      } else {
        _log.finer(
          'Addition Ignored: Rule $other is either empty or exists already.',
        );
      }
    } else if (other is Dictionary) {
      for (final char in other.characters) {
        if (charactersIDSet.add(char.identifier) && !char.isEmpty) {
          characters.add(char);
        } else {
          _log.finer(
            'Addition Ignored: Character $char is either empty or exists already.',
          );
        }
      }
      for (final rule in other.rules) {
        if (rulesIDSet.add(rule) && !rule.isEmpty) {
          rules.add(rule);
        } else {
          _log.finer(
            'Addition Ignored: Rule $rule is either empty or exists already.',
          );
        }
      }
    } else {
      _log.warning('Addition Ignored: Unsupported type ${other.runtimeType}');
    }
    return this;
  }

  Set<dynamic> get _charactersID =>
      characters.map((char) => char.identifier).toSet();

  /* ================================================================ */
  /*                              SORTING                             */
  /* ================================================================ */

  String get sortingKey => _sortKey;
  String get sortingOrd => _sortOrd;

  set sortingKey(String key) {
    key = key.toLowerCase();
    isValid(key, _sortKeys, funcName: 'sortingKey', argName: 'key');
    _sortKey = key;
    sort();
  }

  set sortingOrd(String order) {
    order = order.toLowerCase();
    isValid(order, _sortOrder, funcName: 'sortingOrd', argName: 'order');
    _sortOrd = order;
    sort();
  }

  Dictionary sort({String? sortingKey, String? sortingOrd}) {
    if (sortingKey != null && sortingOrd != null) {
      characters.sort((firstChar, secondChar) {
        final first = firstChar[sortingKey] as String;
        final second = secondChar[sortingKey] as String;
        if (sortingOrd == 'ascending') {
          return first.compareTo(second);
        } else {
          return second.compareTo(first);
        }
      });
      return this;
    }
    return this;
  }

  Dictionary reorder(String sortingKey, String sortingOrd) {
    if (sortingKey != _sortKey || sortingOrd != _sortOrd) {
      isValid(sortingKey, _sortKeys, funcName: 'sort', argName: 'sortingKey');
      isValid(sortingOrd, _sortOrder, funcName: 'sort', argName: 'sortingOrd');
      _sortKey = sortingKey;
      _sortOrd = sortingOrd;
      sort();
    }
    return this;
  }

  /* ================================================================ */
  /*                              SEARCH                              */
  /* ================================================================ */

  Dictionary searchCategory({
    String pattern = "",
    String category = "",
    bool exact = true,
  }) {
    bool contentContains(String pattern, String content) {
      String cleanPattern = pattern.toLowerCase();
      String cleanContent = content.toLowerCase();
      if (exact) {
        for (final t in ['(', ')', '.', '[', ']', '"', ',', ':']) {
          cleanContent = cleanContent.replaceAll(t, '');
        }
        final tokens = cleanContent
            .split(' ')
            .map((t) => t.trim().toLowerCase())
            .where((t) => t.isNotEmpty);
        return tokens.containsElement(cleanPattern);
      } else {
        return cleanContent.contains(cleanPattern);
      }
    }

    bool categoryContains(String pattern, dynamic catList, Character char) {
      if (catList is List) {
        return catList.any((cat) => categoryContains(pattern, cat, char));
      }
      final String category = catList.toString();

      if (char.categories.containsKey(category)) {
        final dynamic catContent = char[category];
        if (catContent == null) return false;
        if (catContent is String) {
          return contentContains(pattern, catContent);
        } else if (catContent is List) {
          return catContent.any(
            (element) => contentContains(pattern, element.toString()),
          );
        } else if (catContent is Map) {
          return catContent.values.any(
            (element) => contentContains(pattern, element.toString()),
          );
        }
      }
      return false;
    }

    _log.finer('Search dictionary category "$category" for pattern: $pattern');

    final matches = _characters
        .where((Character char) => categoryContains(pattern, category, char))
        .toList();

    return copyWith(characters: matches);
  }

  /* ================================================================ */
  /*                             READ SYNC                            */
  /* ================================================================ */

  Dictionary readSync(File file) {
    if (!file.existsSync()) {
      throw FileSystemException('Dictionary file does not exist', file.path);
    }
    return this;
  }

  /* ================================================================ */
  /*                            READ ASYNC                            */
  /* ================================================================ */

  void addSyntax(
    Map<String, dynamic> mapSyntax,
    Map<String, dynamic> mapColor, {
    Map<String, dynamic>? mapColorFav,
  }) {
    _mapColor = mapColor;
    _mapSyntax = mapSyntax;
    _mapColorFav = mapColorFav;
  }

  Future<bool> read(
    File file, {
    bool add = true,
    Map<String, dynamic>? categories,
    String? format,
    String? name,
    String? template,
  }) async {
    Map<String, Type> catTypeMap = {};
    if (categories != null) {
      catTypeMap = categories.map((key, value) {
        if (value is String && _mapTypes.containsKey(value)) {
          return MapEntry(key, _mapTypes[value] as Type);
        }
        if (value is Type) {
          return MapEntry(key, value);
        }
        return MapEntry(key, dynamic);
      });
    }

    String directory = getDirectory(file);
    String filename = getFileName(file);
    String ext = getExtension(file);

    if (ext.isNotEmpty) format = ext;
    String? fileFormat = getExt(format);

    if (fileFormat == null) {
      if (format != null) {
        isValid(format, _expOptions, funcName: 'read', argName: 'format');
      }
      return false;
    }

    File targetFile = File(p.join(directory, '$filename$fileFormat'));
    if (!targetFile.existsSync()) return false;

    final success = switch (fileFormat) {
      '.txt' => await () async {
        return await _readTXT(
          targetFile,
          categories: catTypeMap,
          template: template ?? '',
          add: add,
        );
      }(),
      '.jsonl' => await _readJSONL(
        targetFile,
        categories: catTypeMap,
        add: add,
      ),
      '.db' => await () async {
        return await _readDB(
          targetFile,
          categories: catTypeMap,
          name: name,
          add: add,
        );
      }(),
      _ => false,
    };
    return success;
  }

  Future<bool> _readTXT(
    File file, {
    Map<String, Type> categories = const {},
    String template = '',
    bool add = true,
  }) async {
    return false;
  }

  Future<bool> _readJSONL(
    File file, {
    Map<String, Type> categories = const {},
    bool add = true,
  }) async {
    try {
      if (!add) empty();
      final List<Character> jsonlCharacters = [];

      final lines = await file.readAsLines();
      for (String line in lines) {
        if (line.trim().isEmpty) continue;
        Map<String, dynamic> entry = json.decode(line) as Map<String, dynamic>;
        // entry['simplified']
        if (entry.containsKey('simple')) entry['simplified'] = entry['simple'];
        if (entry.containsKey('pronunciation')) {
          entry['pinyin'] = entry['pronunciation'];
        }
        ChCharacter char = ChCharacter(specs: categories, entry: entry, mapSyntax: _mapSyntax, mapColor: _mapColor, mapColorFav: _mapColorFav);
        jsonlCharacters.add(char);
      }
      _setCharacters(jsonlCharacters);
      sort();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _readDB(
    File file, {
    Map<String, Type> categories = const {},
    String? name,
    bool add = true,
  }) async {
    return false;
  }
}

class ChDictionary extends Dictionary {
  @override
  Set<String> get _sortKeys => const {'simplified', 'traditional', 'pinyin'};
  @override
  Set<String> get _sortOrder => const {'ascending', 'descending'};

  ChDictionary({
    super.name,
    super.characters,
    super.rules,
    super.categories,
    String sortingKey = 'pinyin',
    String sortingOrd = 'ascending',
  }) : super(sortingKey: sortingKey, sortingOrd: sortingOrd);

  @override
  ChDictionary createInstance({
    String? name,
    dynamic characters,
    dynamic rules,
    Map<String, Type>? categories,
    String? sortingKey,
    String? sortingOrd,
  }) {
    return ChDictionary(
      name: name ?? '',
      characters: characters,
      rules: rules,
      categories: categories ?? {},
      sortingKey: sortingKey ?? _sortKey,
      sortingOrd: sortingOrd ?? _sortOrd,
    );
  }

  /* ================================================================ */
  /*                              SORTING                             */
  /* ================================================================ */

  @override
  Dictionary sort({String? sortingKey, String? sortingOrd}) {
    if (_sortKey.isEmpty || _sortOrd.isEmpty) return this;

    final resolvedKey = (sortingKey == null || sortingKey.isEmpty)
        ? _sortKey
        : sortingKey.toLowerCase();
    final resolvedOrd = (sortingOrd == null || sortingOrd.isEmpty)
        ? _sortOrd
        : sortingOrd.toLowerCase();

    String getNextKey(Character char, String currentKey) {
      List<String> nextKeys;
      switch (currentKey) {
        case 'simplified':
          nextKeys = ['simplified', 'traditional', 'pinyin'];
          break;
        case 'traditional':
          nextKeys = ['traditional', 'pinyin', 'simplified'];
          break;
        case 'pinyin':
          nextKeys = ['pinyin', 'simplified', 'traditional'];
          break;
        default:
          nextKeys = ['pinyin', 'simplified', 'traditional'];
      }
      for (final key in nextKeys) {
        final value = char[key] as String;
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    isValid(resolvedKey, _sortKeys, funcName: 'sort', argName: 'sortingKey');
    isValid(resolvedOrd, _sortOrder, funcName: 'sort', argName: 'sortingOrd');

    characters.sort((firstChar, secondChar) {
      final first = TextModifier(
        getNextKey(firstChar, resolvedKey),
      ).toNumericPinyin().result;
      final second = TextModifier(
        getNextKey(secondChar, resolvedKey),
      ).toNumericPinyin().result;
      if (resolvedOrd == 'ascending') {
        return first.compareTo(second);
      } else {
        return second.compareTo(first);
      }
    });
    return this;
  }

  /* ================================================================ */
  /*                              SEARCH                              */
  /* ================================================================ */

  Dictionary search({
    String pattern = "",
    String category = "",
    bool exact = true,
  }) {
    if (category.isNotEmpty) {
      return searchCategory(pattern: pattern, category: category, exact: exact);
    }

    List<String> getPinyinOptions(String pinyin) {
      // final mod =_modString.set(pinyin);
      final mod = TextModifier<String>(pinyin);
      final pinyinAccented = mod.toToneMarkedPinyin().result;
      final pinyinNumeric = mod.toNumericPinyin().result;
      final pinyinPlain = mod.toPlainPinyin().result;
      if (!exact) return [pinyinPlain];
      return [pinyinNumeric, pinyinAccented];
    }

    List<String> updatePattern(String pattern) {
      final String cleanPattern = pattern.toLowerCase().replaceAll(' ', '');
      return getPinyinOptions(cleanPattern);
    }

    bool isMatch(
      ChCharacter char,
      List<String> patterns, {
      bool ignoreVariants = false,
    }) {
      final String pinyin = char['pinyin'] as String;
      final List<String> pinyinOptions = getPinyinOptions(pinyin);

      List<String> relevant = char.uniqueWords;
      relevant.addAll(pinyinOptions);

      if (!ignoreVariants) {
        relevant.addAll(char.variants);
      }

      final cleanRelevant = relevant
          .map((String word) => word.replaceAll(' ', ''))
          .toList();
      return cleanRelevant.any(
        (String word) =>
            patterns.any((String pattern) => word.contains(pattern)),
      );
    }

    final List<String> listPattern = updatePattern(pattern);
    _log.finer('Search dictionary with patterns: ${listPattern.join(', ')}');

    final chCharacters = List<ChCharacter>.from(_characters);
    final matches = chCharacters
        .where((ChCharacter char) => isMatch(char, listPattern))
        .toList();

    return copyWith(characters: matches);
  }
}
