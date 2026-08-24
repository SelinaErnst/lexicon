import 'package:lexicon/lexicon/template_renderer.dart';
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

final Logger _log = Logger('DictionaryLog');

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
/*                         SUBSETTING ENGINE                        */
/* ================================================================ */

// mixin SubsetEngine<C extends Character, T extends Dictionary<C>> on Dictionary<C> {}

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

// class Dictionary extends Iterable<Character> {
class Dictionary<C extends Character> extends Iterable<C> {
  late String name;

  late List<C> _characters;
  List<Rule> _rules;

  Set<String> get _sortKeys => const {};
  Set<String> get _sortOrder => const {'ascending', 'descending'};

  late String _sortKey;
  late String _sortOrd;

  late Map<String, dynamic>? _mapSyntax;
  late Map<String, dynamic>? _mapColor;
  late Map<String, dynamic>? _mapColorFav;

  List<String> baseCategories;

  Map<String, Type> _categories = {};

  /* ================================================================ */
  /*                          IMPLEMENTATION                          */
  /* ================================================================ */

  Dictionary({
    String? name,
    dynamic characters,
    dynamic rules,
    Map<String, Type> categories = const {},
    List<String>? baseCategories,
    String? sortingKey,
    String? sortingOrd,
  }) : name = name ?? '',
       _rules = [],
       baseCategories = baseCategories ?? [],
       _sortKey = sortingKey ?? '',
       _sortOrd = sortingOrd ?? '' {
    this.categories = categories;
    addSyntax(null, null);
    _setCharacters(characters);
    _setRules(rules);
    reorder();

    _log.info(
      'Successfully created: Dict <$name>: ${this.characters.length} (depth)',
    );
  }

  void rename(String name) {
    this.name = name;
  }

  /* ================================================================ */
  /*                           BASIC METHODS                          */
  /* ================================================================ */

  String get headString => 'Dict <$name>: ${characters.length} (depth)';

  @override
  Iterator<C> get iterator => characters.iterator;

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

  String get hashCodeFormatted {
    return hashCode.toString().padLeft(10, '0');
  }

  @override
  bool operator ==(Object other) {
    _log.finer('Compare Dictionary $headString to ${other.runtimeType}');
    if (identical(this, other)) return true;
    if (other is! Dictionary) return false;
    const charEquality = UnorderedIterableEquality<Character>();
    const ruleEquality = UnorderedIterableEquality<Rule>();
    return name == other.name &&
        ruleEquality.equals(rules, other.rules) &&
        charEquality.equals(characters, other.characters);
  }

  C operator [](dynamic identifier) {
    return getCharacter(identifier);
  }

  Dictionary operator -(dynamic other) {
    _log.fine('Substract ${other.runtimeType} from Dictionary $headString');

    if (other is! Character && other is! Dictionary) {
      _log.shout('Subtraction is not supported for type ${other.runtimeType}');
      throw Error();
    }

    var copyDict = copy();
    copyDict.remove(other);
    return copyDict;
  }

  Dictionary operator +(dynamic other) {
    _log.fine('Add ${other.runtimeType} to Dictionary $headString');

    if (other is! Character && other is! Dictionary) {
      _log.shout('Addition is not supported for type ${other.runtimeType}');
      throw Error();
    }

    var copyDict = copy();
    copyDict.add(other, ordered: false);
    return copyDict;
  }

  @override
  String toString() {
    final header = headString;
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

  Dictionary getSlice({int? start, int? stop}) {
    int startInt = start ?? 0;
    int stopInt = stop ?? length;
    if (stopInt <= length && startInt <= stopInt) {
      return getSubset(
        List.generate((stopInt - startInt), (i) => startInt + i),
      );
    }
    _log.shout(
      'Dictionary $headString cannot be sliced by index [$startInt,$stopInt].',
    );
    throw Error();
  }

  Dictionary getSubset(List<dynamic> identifier) {
    _log.fine('Create Subset of Dictionary $headString.');
    final List<Character> matchingCharacters = [];
    for (final id in identifier) {
      try {
        matchingCharacters.add(getCharacter(id).copy());
      } catch (e) {
        _log.finest('Character identifier not found in Dictionary: $id');
      }
    }
    return createInstance(characters: matchingCharacters);
  }

  C getCharacter(dynamic identifier) {
    _log.finer(
      'Lookup character by identifier $identifier (Type: ${identifier.runtimeType}).',
    );

    if (identifier is int) return elementAt(identifier);
    if (identifier is Character && contains(identifier)) {
      return characters.firstWhere((char) => char == identifier);
    }
    if (identifier is List<String>) {
      const listEquality = ListEquality<dynamic>();
      if (!_charactersID.containsElement(identifier)) {
        _log.shout('Character was not found based on identifer: $identifier.');
        throw Error();
      }
      for (final char in characters) {
        if (listEquality.equals(char.identifier, identifier)) return char;
      }
    }
    // return null;
    _log.shout(
      'Invalid Type of identifier used for indexing: ${identifier.runtimeType}',
    );
    throw Error();
  }

  /* ================================================================ */
  /*                              SYNTAX                              */
  /* ================================================================ */

  void addSyntax(
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor, {
    Map<String, dynamic>? mapColorFav,
  }) {
    if (mapSyntax != null) _log.finest('Add command syntax to Dictionary');
    if (mapColor != null) _log.finest('Add colors to Dictionary.');
    if (mapColorFav != null) _log.finest('Add favourite colors to Dictionary.');

    _mapColor = mapColor;
    _mapSyntax = mapSyntax;
    _mapColorFav = mapColorFav;
  }

  /* ================================================================ */
  /*                            CATEGORIES                            */
  /* ================================================================ */

  Map<String, Type> get categories => Map.unmodifiable(_categories);

  set categories(Map<String, dynamic> newCategories) {
    if (newCategories.isNotEmpty) {
      _log.finest(
        'Add categories to Dictionary: ${newCategories.keys.join(', ')}',
      );
    }
    _categories = newCategories.map((key, value) {
      if (value is String && _mapTypes.containsKey(value.toLowerCase())) {
        return MapEntry(key, _mapTypes[value.toLowerCase()] as Type);
      }
      if (value is Type) {
        return MapEntry(key, value);
      }
      return MapEntry(key, dynamic);
    });
  }

  /* ================================================================ */
  /*                        CHARACTERS & RULES                        */
  /* ================================================================ */

  List<C> get characters => _characters;

  List<Rule> get rules => _rules;

  Set<dynamic> get _charactersID =>
      characters.map((char) => char.identifier).toSet();

  Set<dynamic> get _rulesID => rules.toSet();

  set characters(dynamic value) {
    _setCharacters(value);
    reorder();
  }

  set rules(dynamic value) => _setRules(value);

  C _listItem({Map<String, dynamic> entry = const {}}) {
    // final chCat = ['simplified', 'traditional', 'pinyin'];

    return Character(
          strict: false,
          baseCategories: baseCategories,
          specs: categories,
          entry: entry,
          mapSyntax: _mapSyntax,
          mapColor: _mapColor,
          mapColorFav: _mapColorFav,
        )
        as C;
  }

  C _convertListItem(dynamic entry) {
    C character;
    if (entry is Map<String, dynamic>) {
      character = _listItem(entry: entry);
    } else if (entry is Character) {
      try {
        character = entry.reconfigure(specs: categories) as C;
      } catch (e) {
        character = _listItem(entry: entry.data);
      }
    } else {
      _log.shout(
        'Cannot convert $entry to $C. Unsupported type: ${entry.runtimeType}',
      );
      throw Error();
    }
    return character;
  }

  Rule _convertRuleItem(dynamic entry) {
    Rule rule;
    if (entry is Map<String, dynamic>) {
      rule = Rule(
        entry: entry,
        mapSyntax: _mapSyntax,
        mapColor: _mapColor,
        mapColorFav: _mapColorFav,
      );
    } else if (entry is Rule) {
      rule = entry;
    } else {
      _log.shout(
        'Cannot convert $entry to Rule. Unsupported type: ${entry.runtimeType}',
      );
      throw Error();
    }
    return rule;
  }

  void _addCharacter(dynamic entry) {
    final C character = _convertListItem(entry);
    if (character.isNotEmpty &&
        !_charactersID.containsElement(character.identifier)) {
      characters.add(character);
    } else {
      _log.finest(
        'Addition Ignored: Character $character is either empty or exists already.',
      );
    }
  }

  void _rmCharacter(dynamic entry) {
    final C character = _convertListItem(entry);
    final listEquality = ListEquality<dynamic>();
    if (character.isNotEmpty &&
        _charactersID.containsElement(character.identifier)) {
      characters.removeWhere(
        (C char) => listEquality.equals(char.identifier, character.identifier),
      );
    } else {
      _log.finest(
        'Remove Ignored: Character $character is either empty or does not exist.',
      );
    }
  }

  void _addRule(dynamic entry) {
    Rule rule = _convertRuleItem(entry);
    if (!rule.isEmpty && !_rulesID.containsElement(rule)) {
      _rules.add(rule);
    } else {
      _log.finest(
        'Addition Ignored: Rule $entry is either empty or exists already.',
      );
    }
  }

  void _rmRule(dynamic entry) {
    Rule rule = _convertRuleItem(entry);
    if (!rule.isEmpty && _rulesID.containsElement(rule)) {
      _rules.remove(rule);
    } else {
      _log.finest(
        'Remove Ignored: Rule $entry is either empty or exists already.',
      );
    }
  }

  void _setCharacters(dynamic charList) {
    _log.finest(
      'Add characters to Dictionary: ${charList.runtimeType}',
    );
    if (charList is List) {
      try {
        charList = List<Character>.from(charList);
        _characters = charList
            .map((char) => _convertListItem(char))
            .whereType<C>()
            .toSet()
            .where((char) => char.isNotEmpty && char is! Rule)
            .toList();
      } catch (e) {
        if (charList is Iterable) {
          _characters = [];
          for (var item in charList) {
            _addCharacter(item);
          }
        }
      }
    } else if (charList is Dictionary) {
      // print(charList is Dictionary<C>);
      // charList.characters.map((char) => );
      // print(charList.characters);
      // _characters = List.from(charList.characters);
      charList = List<Character>.from(charList.characters);
      _characters = charList.map((char) => _convertListItem(char)).toList();
    } else if (charList is C && charList.isNotEmpty) {
      _characters = [charList.reconfigure(specs: categories) as C];
    } else if (charList == null) {
      _characters = [];
    } else {
      _log.shout(
        'Unsupported type for dictionary characters: ${charList.runtimeType}',
      );
      throw Error();
    }

    _log.fine('Successfully created Character List of Dictionary $headString.');
  }

  void setLinkedRule(Rule rule) => _rules = [rule];

  void _setRules(dynamic ruleList) {
    _log.finest('Add rules to Dictionary $headString: ${ruleList.runtimeType}');
    if (ruleList is List) {
      try {
        ruleList = List<Rule>.from(ruleList);
        _rules = ruleList
            .whereType<Rule>()
            .toSet()
            .where((rule) => !rule.isEmpty)
            .toList();
      } catch (e) {
        if (ruleList is Iterable) {
          _log.finest('Use List of Maps to define rules.');
          _rules = [];
          for (final item in ruleList) {
            _addRule(item as Map<String, dynamic>);
          }
        }
      }
    } else if (ruleList is Rule) {
      _rules = [ruleList];
    } else if (ruleList is Dictionary) {
      _rules = List.from(ruleList.rules);
    } else if (ruleList == null) {
      _rules = [];
    } else {
      _log.shout(
        'Unsupported type for dictionary characters: ${ruleList.runtimeType}',
      );
      throw Error();
    }
  }

  void remove(dynamic other) {
    _log.finer('Remove ${other.runtimeType} from Dictionary $headString');
    if (other is Rule) {
      _rmRule(other);
    } else if (other is Character) {
      _rmCharacter(other);
    } else if (other is Dictionary) {
      if (other.isEmpty) return;
      final otherIDs = other.characters.map((c) => c.identifier).toList();
      characters.removeWhere(
        (C char) => otherIDs.containsElement(char.identifier),
      );
      // rules.removeWhere((rule) => other.rules.contains(rule));
    } else {
      _rmCharacter(other);
    }
  }

  void add(dynamic other, {bool ordered = true}) {
    _log.finer('Add ${other.runtimeType} to Dictionary $headString');
    // adds to current dictionary
    // but without creating a new instance and without sorting

    if (other is Rule) {
      if (other.isEmpty || _rulesID.containsElement(other)) {
        _log.finer(
          'Addition Ignored: Rule $other is either empty or exists already.',
        );
      } else {
        _addRule(other);
      }
    } else if (other is Character) {
      _addCharacter(other);
    } else if (other is Dictionary) {
      if (other.isEmpty) return;
      for (final char in other.characters) {
        _addCharacter(char);
      }
    } else if (other is List) {
      final cached = _characters;
      _setCharacters(other);
      _characters += cached;
    } else {
      _addCharacter(other);
    }
    if (ordered) reorder();
  }

  /* ================================================================ */
  /*                               COPY                               */
  /* ================================================================ */

  @protected
  Dictionary createInstance({
    String? name,
    dynamic characters,
    dynamic rules,
    Map<String, Type>? categories,
    String? sortingKey,
    String? sortingOrd,
  }) {
    _log.finer(
      'Create instance of Dictionary $headString with other characters.',
    );
    return Dictionary(
      name: name ?? this.name,
      characters:
          characters ?? this.characters.map((C char) => char.copy()).toList(),
      rules: rules ?? this.rules.map((rule) => rule.copy()).toList(),
      categories: categories ?? Map<String, Type>.from(_categories),
      sortingKey: sortingKey ?? _sortKey,
      sortingOrd: sortingOrd ?? _sortOrd,
    );
  }

  Dictionary copy() {
    _log.finest('Copy Dictionary $headString.');
    return createInstance();
  }

  Dictionary reconfigure({String? name, Map<String, Type>? categories}) {
    _log.finest('Copy Dictionary $headString with different configuration.');
    return createInstance(
      name: name ?? this.name,
      categories: categories ?? Map<String, Type>.from(_categories),
    );
  }

  Dictionary copyWith({dynamic characters, dynamic rules, bool merge = false}) {
    _log.finest(
      'Copy Dictionary $headString with different characters / rules.',
    );
    return createInstance(characters: characters, rules: rules);
  }

  void empty({bool keepRules = true}) {
    _log.fine('Empty Dictionary $headString of all characters.');
    _characters = [];
    if (!keepRules) {
      _log.fine('Empty Dictionary $headString of all rules.');
      _rules = [];
    }
  }

  /* ================================================================ */
  /*                              SORTING                             */
  /* ================================================================ */

  String get sortingKey => _sortKey;
  String get sortingOrd => _sortOrd;

  set sortingKey(String key) {
    _log.config('Set sorting key to $key');
    if (_sortKeys.isNotEmpty) {
      isValid(key, _sortKeys, funcName: 'set sortingKey', argName: 'key');
    }
    key = key.toLowerCase();
    reorder(sortingKey: key);
  }

  set sortingOrd(String order) {
    _log.config('Set sorting order to $order');
    isValid(order, _sortOrder, funcName: 'set sortingOrd', argName: 'order');
    order = order.toLowerCase();
    reorder(sortingOrd: order);
  }

  Dictionary sort({String? sortingKey, String? sortingOrd}) {
    _log.fine('Create sorted Dictionary by $sortingKey in $sortingOrd order');
    var sorted = copy();
    sorted.reorder(sortingKey: sortingKey, sortingOrd: sortingOrd);
    return sorted;
  }

  void reorder({String? sortingKey, String? sortingOrd}) {
    _log.fine('Sort Dictionary by $sortingKey in $sortingOrd order');
    final resolvedKey = (sortingKey == null || sortingKey.isEmpty)
        ? _sortKey
        : sortingKey.toLowerCase();
    final resolvedOrd = (sortingOrd == null || sortingOrd.isEmpty)
        ? _sortOrd
        : sortingOrd.toLowerCase();

    if (resolvedKey.isNotEmpty && resolvedOrd.isNotEmpty) {
      if (_sortKeys.isNotEmpty) {
        isValid(
          resolvedKey,
          _sortKeys,
          funcName: 'sort',
          argName: 'sortingKey',
        );
      }

      isValid(resolvedOrd, _sortOrder, funcName: 'sort', argName: 'sortingOrd');
      _sortKey = resolvedKey;
      _sortOrd = resolvedOrd;

      characters.sort((firstChar, secondChar) {
        final first = firstChar[resolvedKey] as String;
        final second = secondChar[resolvedKey] as String;
        if (sortingOrd == 'ascending') {
          return first.compareTo(second);
        } else {
          return second.compareTo(first);
        }
      });
    }
  }

  /* ================================================================ */
  /*                              SEARCH                              */
  /* ================================================================ */

  Dictionary searchCategory({
    String pattern = "",
    List<String> searchCategories = const [],
    bool exact = true,
  }) {
    _log.fine(
      'Search Dictionary categories "$searchCategories" for pattern: $pattern',
    );

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

    final matches = _characters
        .where(
          (Character char) => categoryContains(pattern, searchCategories, char),
        )
        .toList();

    return createInstance(characters: matches);
  }

  /* ================================================================ */
  /*                             READ SYNC                            */
  /* ================================================================ */

  Dictionary readSync(File file) {
    if (!file.existsSync()) {
      // throw FileSystemException('Dictionary file does not exist', file.path);
      _log.shout('Dictionary file does not exist.');
      throw Error();
    }
    return this;
  }

  /* ================================================================ */
  /*                            READ ASYNC                            */
  /* ================================================================ */

  Map<String, dynamic> _updateEntry(Map<String, dynamic> entry) {
    return entry;
  }

  Future<void> read(
    File file, {
    bool add = true,
    Map<String, dynamic>? categories,
    String? format,
    String? name,
    String? template,
  }) async {
    _log.fine('Read file: ${getFileName(file)}');

    if (categories != null) this.categories = categories;

    final String directory = getDirectory(file);
    final String filename = getFileName(file);
    final String ext = getExtension(file);

    if (ext.isNotEmpty) format = ext;
    String? fileFormat = getExt(format);

    if (fileFormat == null) {
      if (format != null) {
        isValid(format, _expOptions, funcName: 'read', argName: 'format');
      }
      _log.shout(
        'A valid file format is required. The options are: ${_extOptions.keys.toList()}',
      );
      throw Error();
    }

    File targetFile = File(p.join(directory, '$filename$fileFormat'));
    if (!targetFile.existsSync()) {
      _log.shout('File does not exist.');
      throw Error();
    }

    final success = switch (fileFormat) {
      '.txt' => await () async {
        return await _readTXT(targetFile, template: template ?? '', add: add);
      }(),
      '.jsonl' => await _readJSONL(targetFile, add: add),
      '.db' => await () async {
        return await _readDB(targetFile, name: name, add: add);
      }(),
      _ => false,
    };
    if (success == false) {
      _log.shout('Unsuccessful attempt at reading file to dictionary.');
      throw Error();
    }
  }

  Future<bool> _readTXT(
    File file, {
    String template = '',
    bool add = true,
  }) async {
    _log.fine('Read .txt file.');
    return false;
  }

  Future<bool> _readJSONL(File file, {bool add = true}) async {
    _log.fine('Read .jsonl file.');
    try {
      if (!add) empty();
      final List<Character> jsonlCharacters = [];

      final stream = file
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final String line in stream) {
        // Fast check for empty or whitespace-only lines without creating a new string via .trim()
        if (line.isEmpty ||
            line.runes.every((r) => r == 32 || r == 9 || r == 10 || r == 13)) {
          continue;
        }
        final Map<String, dynamic> entry =
            json.decode(line) as Map<String, dynamic>;
        jsonlCharacters.add(_listItem(entry: _updateEntry(entry)));
      }
      // final lines = await file.readAsLines();
      // for (String line in lines) {
      //   if (line.trim().isEmpty) continue;
      //   Map<String, dynamic> entry = json.decode(line) as Map<String, dynamic>;
      //   jsonlCharacters.add(_listItem(entry: _updateEntry(entry)));
      // }

      _setCharacters(jsonlCharacters);
      reorder();
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _readDB(File file, {String? name, bool add = true}) async {
    _log.fine('Read .db file.');
    return false;
  }

  /* ================================================================ */
  /*                               WRITE                              */
  /* ================================================================ */

  void write(
    File file, {
    String? format,
    bool overwrite = true,
    File? template,
    List<String>? categories,
    TextModifier<String>? mod,
  }) async {
    _log.fine('Write to file: ${getFileName(file)}');

    final String directory = getDirectory(file);
    final String filename = getFileName(file);
    final String ext = getExtension(file);

    final List<String>? selectedCategories = categories;

    if (ext.isNotEmpty) format = ext;
    String? fileFormat = getExt(format);

    if (fileFormat == null) {
      format = format ?? 'none';
      isValid(format, _expOptions, funcName: 'write', argName: 'format');
    }

    File targetFile = File(p.join(directory, '$filename$fileFormat'));

    final success = switch (fileFormat) {
      '.txt' => await () async {
        isArgument(template, File, argName: 'template', funcName: 'write');
        isArgument(
          mod,
          TextModifier<String>,
          argName: 'mod',
          funcName: 'write',
        );
        return await _toTXT(targetFile, template!, selectedCategories, mod!);
      }(),
      '.jsonl' => await _toJSONL(targetFile),
      '.db' => await _toDB(targetFile, overwrite: overwrite),
      _ => false,
    };
    if (success == false) {
      _log.shout('Unsuccessful attempt at writing a dictionary to file.');
      throw Error();
    }
  }

  Future<bool> _toTXT(
    File file,
    File template,
    List<String>? categories,
    TextModifier<String> mod,
  ) async {
    _log.fine('Write to .txt file.');

    if (getExtension(file) != '.txt') {
      _log.warning('File is in the incorrect format: ${getExtension(file)}');
      return false;
    }
    Writer w = Writer(mod, tmplFile: template);
    final lines = characters.map((char) => w.compile(char).result).toList();
    try {
      writeListToFile(lines, file);
      return true;
    } catch (e) {
      _log.warning(e);
      return false;
    }
  }

  Future<bool> _toJSONL(File file) async {
    _log.fine('Write to .jsonl file.');

    final lines = characters.map((char) => char.toMap()).toList();
    // print(lines);
    try {
      final IOSink sink = file.openWrite(mode: FileMode.write, encoding: utf8);
      final int len = lines.length;
      for (int i = 0; i < len; i++) {
        sink.write('${json.encode(lines[i]).toString()}\n');
      }
      await sink.flush();
      await sink.close();
      return true;
    } catch (e) {
      _log.warning(e);
      return false;
    }
  }

  Future<bool> _toDB(File file, {bool overwrite = true}) async {
    _log.fine('Write to .db file.');

    return false;
  }
}

class ChDictionary extends Dictionary<ChCharacter> {
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
    _log.finer(
      'Create instance of ChDictionary $headString with other characters.',
    );
    return ChDictionary(
      name: name ?? this.name,
      characters:
          characters ?? this.characters.map((char) => char.copy()).toList(),
      rules: rules ?? this.rules.map((rule) => rule.copy()).toList(),
      categories: categories ?? Map<String, Type>.from(_categories),
      sortingKey: sortingKey ?? _sortKey,
      sortingOrd: sortingOrd ?? _sortOrd,
    );
  }

  /* ================================================================ */
  /*                              SORTING                             */
  /* ================================================================ */

  @override
  void reorder({String? sortingKey, String? sortingOrd}) {
    _log.fine('Sort ChDictionary by $sortingKey in $sortingOrd order');

    final resolvedKey = (sortingKey == null || sortingKey.isEmpty)
        ? _sortKey
        : sortingKey.toLowerCase();
    final resolvedOrd = (sortingOrd == null || sortingOrd.isEmpty)
        ? _sortOrd
        : sortingOrd.toLowerCase();

    List<String> getPriority(String currentKey) {
      List<String> priorities;
      switch (currentKey) {
        case 'simplified':
          priorities = ['simplified', 'traditional', 'pinyin'];
        case 'traditional':
          // priorities = ['traditional', 'simplified', 'pinyin'];
          priorities = ['traditional', 'pinyin', 'simplified'];
        case 'pinyin':
          priorities = ['pinyin', 'simplified', 'traditional'];
        default:
          priorities = ['pinyin', 'simplified', 'traditional'];
      }
      return priorities;
    }

    String getPriorityValue(Character char, int priority) {
      final priorities = getPriority(resolvedKey);
      var value = char[priorities[priority]];
      if (value is String) return value;
      return "";
    }

    if (resolvedKey.isNotEmpty && resolvedOrd.isNotEmpty) {
      isValid(resolvedKey, _sortKeys, funcName: 'sort', argName: 'sortingKey');
      isValid(resolvedOrd, _sortOrder, funcName: 'sort', argName: 'sortingOrd');
      _sortKey = resolvedKey;
      _sortOrd = resolvedOrd;

      _log.fine(
        'Sorting the ChDictionary $headString based on key "$resolvedKey", and order "$resolvedOrd".',
      );

      characters.sort((firstChar, secondChar) {
        return compareMultiple<Character>(
          firstChar,
          secondChar,
          reverse: resolvedOrd == 'descending',
          [
            (a, b) => getPriorityValue(a, 0).compareTo(getPriorityValue(b, 0)),
            (a, b) => getPriorityValue(a, 1).compareTo(getPriorityValue(b, 1)),
            (a, b) => getPriorityValue(a, 2).compareTo(getPriorityValue(b, 2)),
          ],
        );
      });
    }
  }

  /* ================================================================ */
  /*                              SEARCH                              */
  /* ================================================================ */

  Dictionary search({
    String pattern = "",
    List<String> categories = const [],
    bool exact = true,
  }) {
    _log.fine('Search ChDictionary for pattern: $pattern');

    if (categories.isNotEmpty) {
      return searchCategory(
        pattern: pattern,
        searchCategories: categories,
        exact: exact,
      );
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
        .where(
          (ChCharacter char) =>
              isMatch(char, listPattern, ignoreVariants: false),
        )
        .toList();
    return createInstance(characters: matches);
  }

  /* ================================================================ */
  /*                               READ                               */
  /* ================================================================ */

  @override
  ChCharacter _listItem({Map<String, dynamic> entry = const {}}) {
    return ChCharacter(
      entry: entry,
      specs: categories,
      mapSyntax: _mapSyntax,
      mapColor: _mapColor,
      mapColorFav: _mapColorFav,
    );
  }

  @override
  Map<String, dynamic> _updateEntry(Map<String, dynamic> entry) {
    _log.finest('Character entry is changed (during reading of file).');
    if (entry.containsKey('simple')) entry['simplified'] = entry['simple'];
    if (entry.containsKey('pronunciation')) {
      entry['pinyin'] = entry['pronunciation'];
    }
    return entry;
  }
}
