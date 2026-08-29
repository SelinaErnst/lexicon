import 'package:lexicon/src/errors.dart';
import 'package:logging/logging.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'character.dart';
import 'rule.dart';
import 'utils.dart';
import 'text_modifier.dart';

final Logger _log = Logger('DictionaryLog');

/* ================================================================ */
/*                           CONFIGURATION                          */
/* ================================================================ */

/// Maps string aliases to their corresponding Dart types.
final Map<String, Type> _mapTypes = {
  'list': List<String>,
  'str': String,
  'int': int,
  'dict': Map<String, String>,
};

/* ================================================================ */
/*                      FILE AND FORMAT HELPERS                     */
/* ================================================================ */

/// Provides an indexed string representation of a list.
///
/// Each element is placed on a separate line and prefixed with its
/// corresponding list index.
extension LexiconListExtension on List<Character> {
  /// Returns the element type of the list as a string.
  String get elementType =>
      runtimeType.toString().replaceFirst('List<', '').replaceFirst('>', '');

  /// Returns the list as a string with each character on a separate line
  /// and prefixed by its index.
  String get idxStr {
    final list = List.generate(
      length,
      (index) => '$index: ${this[index]}',
    ).join('\n');
    return list;
  }

  /// Converts the list to a Markdown table with indexed characters.
  String toMarkdownTable() {
    final rows = List.generate(
      length,
      (index) =>
          // ignore: unnecessary_string_escapes
          '| $index | ${this[index].toString().replaceAll(r'|', '\\\|')} |',
    );

    return '| # | $elementType |\n'
        '|---:|:---|\n'
        '${rows.join('\n')}';
  }
}

/* ================================================================ */
/*                            DICTIONARY                            */
/* ================================================================ */

/// A collection of [Character] objects and their associated [Rule] objects.
///
/// [Dictionary] implements [Iterable], allowing its characters to be
/// iterated directly.
class Dictionary<C extends Character, R extends Rule> extends Iterable<C> {
  /* ––––––––––––––––––––– sorting configuration –––––––––––––––––––– */

  /// Categories that can be used for sorting.
  Set<String> get _sortKeys => const {};

  /// Supported sorting directions.
  Set<String> get _sortOrder => const {'ascending', 'descending'};

  /// The category currently used for sorting.
  String get sortingKey => _sortKey;
  late String _sortKey;

  /// The current sorting direction.
  String get sortingOrd => _sortOrd;
  late String _sortOrd;

  /* ––––––––––––––––––––– syntax configuration ––––––––––––––––––––– */

  /// Syntax configuration used when rendering dictionary content.
  late Map<String, dynamic>? _mapSyntax;

  /// Color configuration used when rendering dictionary contents.
  late Map<String, dynamic>? _mapColor;

  /// Optional named color configurations used during rendering.
  late Map<String, dynamic>? _mapColorFav;

  /* –––––––––––––––––––––––– representation –––––––––––––––––––––––– */

  /// Returns the sanitized name of the dictionary.
  String get name => _name;
  String _name;

  /// Returns a short summary containing the dictionary name and character count.
  String get headString => '$runtimeType "$name": ${characters.length} (depth)';

  /* –––––––––––––––––––––––––– categories –––––––––––––––––––––––––– */

  /// Identifying categories shared by entries in this dictionary.
  final List<String> baseCategories;

  /// Maps category names to their expected value types.
  Map<String, Type> _categories = {};

  /// Returns an unmodifiable view of the dictionary's category schema.
  Map<String, Type> get categories => Map.unmodifiable(_categories);

  /* –––––––––––––––––––––––––– characters –––––––––––––––––––––––––– */

  /// The characters contained in this dictionary.
  late List<C> _characters;

  /// Returns the characters contained in this dictionary.
  ///
  /// The list contains only [Character] objects and does not include
  /// [Rule] objects.
  List<C> get characters => _characters;

  /// Returns the unique identifiers of all characters in the dictionary.
  Set<dynamic> get _charactersID =>
      characters.map((char) => char.identifier).toSet();

  /* ––––––––––––––––––––––––––––– rules –––––––––––––––––––––––––––– */

  /// The rules associated with this dictionary.
  List<R> _rules;

  /// Returns the rules associated with this dictionary.
  ///
  /// Rules are stored separately from [characters] and are therefore
  /// not included when the dictionary is iterated.
  List<R> get rules => _rules;

  /// Returns the unique rules currently associated with the dictionary.
  Set<dynamic> get _rulesID => rules.toSet();

  /* ================================================================ */
  /*                            CONSTRUCTOR                           */
  /* ================================================================ */

  /// Creates a dictionary with the given [name].
  ///
  /// [characters] and [rules] can be supplied as initial contents.
  /// [categories] defines the category schema used by the dictionary.
  /// [baseCategories] defines the identifying categories shared by
  /// its entries.
  ///
  /// [sortingKey] and [sortingOrd] optionally define the initial
  /// sorting configuration.
  Dictionary(
    String name, {
    dynamic characters,
    dynamic rules,
    Map<String, dynamic> categories = const {},
    List<String>? baseCategories,
    String? sortingKey,
    String? sortingOrd,
  }) : _name = "",
       _rules = [],
       baseCategories = baseCategories ?? [],
       _sortKey = sortingKey ?? '',
       _sortOrd = sortingOrd ?? '' {
    this.name = name;
    this.categories = categories;
    addSyntax(null, null);
    _setCharacters(characters);
    _setRules(rules);
    reorder();

    _log.info(
      'Successfully created: Dict <$name>: ${this.characters.length} (depth)',
    );
  }

  /// Returns an iterator over the characters in this dictionary.
  @override
  Iterator<C> get iterator => characters.iterator;

  /* ––––––––––––––––––––––– name sanitization –––––––––––––––––––––– */

  /// Sets the dictionary name after sanitizing it.
  ///
  /// The name is cleaned using [TextModifier.cleanName]. A warning is logged
  /// when sanitization changes the provided name.
  ///
  /// Throws [ArgumentError] if sanitization results in an empty name.
  set name(String name) {
    final String newName = TextModifier<String>(name).cleanName().result;
    if (name != newName) {
      _log.warning('Name of Dictionary was changed from $name to $newName');
    }
    if (newName != "") {
      _name = newName;
    } else {
      _log.shout('Invalid name for Dictionary: $name');
      throw ArgumentError(
        'The dictionary name is invalid: cleaning the provided name resulted in an empty string.',
        'name',
      );
    }
  }

  /// Renames the dictionary using the same sanitization as [name].
  void rename(String name) {
    this.name = name;
  }

  /* –––––––––––––––––––––– identity & equality ––––––––––––––––––––– */

  /// Computes a hash code from the dictionary [name], [characters], and [rules].
  ///
  /// Character and rule collections are treated as unordered, so their order
  /// does not affect the resulting hash code.
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

  /// Returns the hash code as a zero-padded 10-character string.
  String get hashCodeFormatted => hashCode.toString().padLeft(10, '0');

  /// Checks whether [other] has the same name, characters, and rules.
  ///
  /// Character and rule collections are compared without considering their
  /// order.
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

  /* ––––––––––––––––––––– collection operations –––––––––––––––––––– */

  /// Returns a copy of this dictionary with [other] removed.
  ///
  /// [other] may be a [Character] or another [Dictionary].
  ///
  /// Throws [UnsupportedLexiconOperationException] if [other] is not a supported type.
  Dictionary operator -(dynamic other) {
    _log.fine('Substract ${other.runtimeType} from Dictionary $headString');

    if (other is! Character && other is! Dictionary) {
      _log.shout('Subtraction is not supported for type ${other.runtimeType}');
      throw UnsupportedOperationException('-', inputType: other.runtimeType);
    }

    var copyDict = copy();
    copyDict.remove(other);
    return copyDict;
  }

  /// Returns a copy of this dictionary with [other] added.
  ///
  /// [other] may be a [Character] or another [Dictionary].
  ///
  /// Throws [UnsupportedOperationException] if [other] is not a supported type.
  Dictionary operator +(dynamic other) {
    _log.fine('Add ${other.runtimeType} to Dictionary $headString');

    if (other is! Character && other is! Dictionary) {
      _log.shout('Addition is not supported for type ${other.runtimeType}');
      throw UnsupportedOperationException('+', inputType: other.runtimeType);
    }

    var copyDict = copy();
    copyDict.add(other, ordered: false);
    return copyDict;
  }

  /* –––––––––––––––––––––––– representation –––––––––––––––––––––––– */

  /// Returns a formatted representation of the dictionary.
  ///
  /// Each character is displayed on a separate line with its index.
  @override
  String toString() {
    return '$headString\n'
        '  baseCategories: $baseCategories\n'
        '  categories: ${categories.length}\n'
        '  characters: ${characters.length}\n'
        '  rules: ${rules.length}';
    // final header = headString;
    // final String subhead =
    // if (characters.isEmpty) return header;

    // final buffer = StringBuffer('$header\n');
    // for (var i = 0; i < characters.length; i++) {
    //   final number = i.toString().padLeft(4);
    //   buffer.write('$number: ${characters[i]}\n');
    // }
    // return buffer.toString();
  }

  /// Converts the dictionary's characters to a list representation.
  ///
  /// [growable] is reserved for controlling whether the returned list can be
  /// modified and is currently passed through to the conversion helper.
  List<dynamic> toMapList({bool growable = true}) {
    return convertMixedList(characters);
  }

  /* –––––––––––––––––––––––––––– subsets ––––––––––––––––––––––––––– */

  /// Returns a subset of this dictionary within the given index range.
  ///
  /// [start] defaults to the first character and [stop] defaults to the
  /// dictionary length. The character at [stop] is not included.
  ///
  /// Throws [RangeError] if the requested range is invalid.
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
    throw RangeError('Dictionary slice range indices are out of bounds.');
  }

  /// Returns a new dictionary containing copies of the characters identified
  /// by [identifier].
  ///
  /// Identifiers that cannot be found are skipped.
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

  /* –––––––––––––––––––––––––––– lookup –––––––––––––––––––––––––––– */

  /// Returns the character identified by [identifier].
  ///
  /// The identifier may be an index, a [Character], or a list of identifier
  /// values supported by the dictionary lookup.
  C operator [](dynamic identifier) {
    return getCharacter(identifier);
  }

  /// Returns the character identified by [identifier].
  ///
  /// An integer is interpreted as a character index. A [Character] is matched
  /// by structural equality, while a list of strings is matched against the
  /// character's identifier.
  ///
  /// Throws [ArgumentError] if [identifier] has an unsupported type.
  /// Throws [StateError] if a list-based identifier does not match a character.
  C getCharacter(dynamic identifier) {
    _log.finer(
      'Lookup character by identifier $identifier (Type: ${identifier.runtimeType}).',
    );

    if (identifier is int) return elementAt(identifier);
    if (identifier is Character) {
      if (!contains(identifier)) {
        throw CharacterNotFoundException(identifier);
      }
      return characters.firstWhere((char) => char == identifier);
    }
    if (identifier is List<String>) {
      const listEquality = ListEquality<dynamic>();
      for (final char in characters) {
        if (listEquality.equals(char.identifier, identifier)) return char;
      }
      throw CharacterNotFoundException(identifier);
    }

    _log.shout(
      'Invalid Type of identifier used for indexing: ${identifier.runtimeType}',
    );
    throw CharacterNotFoundException(identifier);
  }

  /* ––––––––––––––––––––– syntax configuration ––––––––––––––––––––– */

  /// Sets the syntax and color configuration used by the dictionary.
  ///
  /// Existing configurations are replaced when the corresponding argument
  /// is provided. A `null` argument leaves the current configuration unchanged.
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

  /* –––––––––––––––––––––––– category schema ––––––––––––––––––––––– */

  /// Sets the category schema used by the dictionary.
  ///
  /// String type aliases such as `str` and `int` are converted to their
  /// corresponding Dart [Type]. Values that are already [Type] objects are
  /// kept unchanged. Unrecognized type descriptors default to [dynamic].
  set categories(Map<String, dynamic> newCategories) {
    if (newCategories.isNotEmpty) {
      _log.finest(
        'Add categories to Dictionary: ${newCategories.keys.join(', ')}',
      );
    }
    Map<String, Type> finalCategories = {};
    finalCategories.addAll({
      for (final category in baseCategories) category: String,
    });
    // finalCategories.addAll({
    //   for (final entry in categories.entries)
    //     if (!baseCategories.contains(entry.key)) entry.key: entry.value,
    // });
    finalCategories.addAll(
      newCategories.map((key, value) {
        if (value is String && _mapTypes.containsKey(value.toLowerCase())) {
          return MapEntry(key, _mapTypes[value.toLowerCase()] as Type);
        }
        if (value is Type) {
          return MapEntry(key, value);
        }
        return MapEntry(key, dynamic);
      }),
    );
    _categories = finalCategories;
    // _categories = newCategories.map((key, value) {
    //   if (value is String && _mapTypes.containsKey(value.toLowerCase())) {
    //     return MapEntry(key, _mapTypes[value.toLowerCase()] as Type);
    //   }
    //   if (value is Type) {
    //     return MapEntry(key, value);
    //   }
    //   return MapEntry(key, dynamic);
    // });
    // print(['#',_categories, categories]);
  }

  /* ================================================================ */
  /*                        CHARACTERS & RULES                        */
  /* ================================================================ */

  /// Sets the characters contained in the dictionary.
  ///
  /// The supplied value is converted into the dictionary's character type
  /// and the resulting collection is reordered afterwards.
  set characters(dynamic value) {
    _setCharacters(value);
    reorder();
  }

  /// Sets the rules associated with the dictionary.
  set rules(dynamic value) => _setRules(value);

  /* –––––––––––––––––––––––– initialization –––––––––––––––––––––––– */

  /// Converts [charList] into the dictionary's character type.
  ///
  /// Supported input includes character lists, dictionaries, individual
  /// characters, and `null`. Rules are excluded from the character collection.
  ///
  /// Throws [InvalidDictionaryDataException] if [charList] has an unsupported format.
  void _setCharacters(dynamic charList) {
    _log.finest('Add characters to Dictionary: ${charList.runtimeType}');
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
            addCharacter(item);
          }
        }
      }
    } else if (charList is Dictionary) {
      charList = List<Character>.from(charList.characters);
      _characters = charList.map((char) => _convertListItem(char)).toList();
    } else if (charList is C) {
      if (charList.isNotEmpty) {
        _characters = [charList.reconfigure(categories: categories) as C];
      }
    } else if (charList == null) {
      _characters = [];
    } else {
      _log.shout(
        'Unsupported type for dictionary characters: ${charList.runtimeType}',
      );
      throw InvalidDictionaryDataException('characters', charList.runtimeType);
    }

    _log.fine('Successfully created Character List of Dictionary $headString.');
  }

  /// Replaces the current rules with the supplied [rule].
  void setLinkedRule(R rule) {
    _rules.clear();
    _rules.add(rule);
  }

  /// Converts [ruleList] into the dictionary's rule type.
  ///
  /// Supported input includes rule lists, individual rules, dictionaries,
  /// and `null`. Character objects are not added to the rule collection.
  ///
  /// Throws [InvalidDictionaryDataException] if [ruleList] has an unsupported format.
  void _setRules(dynamic ruleList) {
    _log.finest('Add rules to Dictionary $headString: ${ruleList.runtimeType}');
    if (ruleList is List) {
      try {
        ruleList = List<R>.from(ruleList);
        _rules = ruleList
            .whereType<R>()
            .toSet()
            .where((rule) => rule.isNotEmpty)
            .toList();
      } catch (e) {
        if (ruleList is Iterable) {
          _log.finest('Use List of Maps to define rules.');
          _rules = [];
          for (final item in ruleList) {
            addRule(item as Map<String, dynamic>);
          }
        }
      }
    } else if (ruleList is Rule) {
      if (ruleList.isNotEmpty) {
        _rules = [ruleList as R];
      }
    } else if (ruleList is Dictionary) {
      _rules = List.from(ruleList.rules);
    } else if (ruleList == null) {
      _rules = [];
    } else {
      _log.shout(
        'Unsupported type for dictionary characters: ${ruleList.runtimeType}',
      );
      throw InvalidDictionaryDataException('rules', ruleList.runtimeType);
    }
  }

  /* –––––––––––––––––––––– collection element –––––––––––––––––––––– */

  /// Creates a character of type [C] from [entry].
  ///
  /// The dictionary's category and syntax configurations are applied to the
  /// new character.
  C _listItem({Map<String, dynamic> entry = const {}}) {
    return Character(
          strict: false,
          baseCategories: baseCategories,
          categories: categories,
          entry: entry,
          mapSyntax: _mapSyntax,
          mapColor: _mapColor,
          mapColorFav: _mapColorFav,
        )
        as C;
  }

  /// Creates a rule of type [R] from [entry].
  ///
  /// The dictionary's syntax configuration is applied to the new rule.
  R _ruleItem({Map<String, dynamic> entry = const {}}) {
    return Rule(
          entry: entry,
          mapSyntax: _mapSyntax,
          mapColor: _mapColor,
          mapColorFav: _mapColorFav,
        )
        as R;
  }

  /// Converts [entry] into the dictionary's character type [C].
  ///
  /// A map is converted into a new character. An existing [Character] is
  /// reconfigured to use this dictionary's category schema when possible.
  C _convertListItem(dynamic entry) {
    C character;
    if (entry is Map<String, dynamic>) {
      character = _listItem(entry: _updateEntry(entry));
    } else if (entry is Character) {
      try {
        character = entry.reconfigure(categories: categories) as C;
      } catch (e) {
        character = _listItem(entry: entry.data);
      }
    } else {
      _log.shout(
        '$runtimeType cannot convert $entry to $C. Unsupported type: ${entry.runtimeType}',
      );
      throw InvalidDictionaryDataException('character', entry.runtimeType);
    }
    return character;
  }

  /// Converts [entry] into the dictionary's rule type [R].
  ///
  /// A map is converted into a new rule, while an existing [R] instance is
  /// returned directly.
  R _convertRuleItem(dynamic entry) {
    R rule;
    if (entry is Map<String, dynamic>) {
      rule = _ruleItem(entry: _updateEntry(entry));
    } else if (entry is R) {
      rule = entry;
    } else {
      _log.shout(
        'Cannot convert $entry to Rule. Unsupported type: ${entry.runtimeType}',
      );
      throw InvalidDictionaryDataException('rule', entry.runtimeType);
    }
    return rule;
  }

  /// Allows subclasses to transform an entry before it is added to the
  /// dictionary.
  ///
  /// The default implementation returns [entry] unchanged.
  Map<String, dynamic> _updateEntry(Map<String, dynamic> entry) {
    return entry;
  }

  /* –––––––––––––––––––– collection modification ––––––––––––––––––– */

  /// Removes all rules from the dictionary.
  void emptyRules() {
    _rules = [];
  }

  /// Removes all characters from the dictionary.
  void emptyCharacters() {
    _characters = [];
  }

  /// Removes all characters from the dictionary.
  ///
  /// When [keepRules] is `false`, the dictionary's rules are removed as well.
  void empty({bool keepRules = true}) {
    _log.fine('Empty Dictionary $headString of all characters.');

    _characters = [];
    emptyCharacters();

    if (!keepRules) {
      _log.fine('Empty Dictionary $headString of all rules.');
      emptyRules();
    }
  }

  /// Adds [other] to the dictionary.
  ///
  /// [other] may be a character, rule, dictionary, or list of character data.
  /// Duplicate or empty entries are ignored.
  ///
  /// When [ordered] is `true`, the dictionary is reordered after the addition.
  void add(dynamic other, {bool ordered = true}) {
    _log.finer('Add ${other.runtimeType} to Dictionary $headString');

    if (other is Rule) {
      addRule(other);
    } else if (other is Character) {
      addCharacter(other);
    } else if (other is Dictionary) {
      if (other.isEmpty) return;
      for (final char in other.characters) {
        addCharacter(char);
      }
    } else if (other is List) {
      final cached = _characters;
      _setCharacters(other);
      _characters += cached;
    } else {
      addCharacter(other);
    }
    if (ordered) reorder();
  }

  /// Adds a character to the dictionary if it is valid and not already present.
  void addCharacter(dynamic entry) {
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

  /// Adds a rule to the dictionary if it is valid and not already present.
  void addRule(dynamic entry) {
    R rule = _convertRuleItem(entry);
    if (rule.isNotEmpty && !_rulesID.containsElement(rule)) {
      _rules.add(rule);
    } else {
      _log.finest(
        'Addition Ignored: Rule $entry is either empty or exists already.',
      );
    }
  }

  /// Removes [other] from the dictionary.
  ///
  /// [other] may be a character, rule, or dictionary. Entries that do not
  /// exist are ignored.
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

  /// Removes a character matching [entry] from the dictionary.
  ///
  /// Invalid, empty, or unknown characters are ignored.
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

  /// Removes a rule matching [entry] from the dictionary.
  ///
  /// Invalid, empty, or unknown rules are ignored.
  void _rmRule(dynamic entry) {
    R rule = _convertRuleItem(entry);
    if (rule.isNotEmpty && _rulesID.containsElement(rule)) {
      _rules.remove(rule);
    } else {
      _log.finest(
        'Remove Ignored: Rule $entry is either empty or exists already.',
      );
    }
  }

  /* ––––––––––––––––––– copy and reconfiguration ––––––––––––––––––– */

  /// Creates a new dictionary instance using the provided values or the
  /// corresponding configuration and contents of this dictionary.
  ///
  /// This method is protected so subclasses can create instances of their
  /// own dictionary type.
  @protected
  Dictionary<C, R> createInstance({
    String? name,
    dynamic characters,
    dynamic rules,
    Map<String, Type>? categories,
    List<String>? baseCategories,
    String? sortingKey,
    String? sortingOrd,
  }) {
    _log.finer(
      'Create instance of Dictionary $headString with other characters.',
    );
    return Dictionary(
      name ?? this.name,
      rules: rules ?? List<R>.from(this.rules),
      characters:
          characters ?? this.characters.map((C char) => char.copy()).toList(),
      // characters: characters ?? List<C>.from(this.characters),
      // rules: rules ?? this.rules.map((rule) => rule.copy()).toList(),
      categories: categories ?? Map<String, Type>.from(_categories),
      baseCategories: baseCategories ?? List<String>.from(this.baseCategories),
      sortingKey: sortingKey ?? _sortKey,
      sortingOrd: sortingOrd ?? _sortOrd,
    );
  }

  /// Creates an independent copy of this dictionary.
  ///
  /// Characters are copied individually so the returned dictionary does not
  /// share character instances with the original.
  Dictionary<C, R> copy() {
    _log.finest('Copy Dictionary $headString.');
    return createInstance();
  }

  /// Creates a copy of this dictionary with the specified configuration.
  ///
  /// [name], [categories], and [baseCategories] replace the corresponding
  /// configuration of the copy when provided. The existing characters and
  /// rules are retained.
  Dictionary<C, R> reconfigure({
    String? name,
    Map<String, Type>? categories,
    List<String>? baseCategories,
  }) {
    _log.finest('Copy Dictionary $headString with different configuration.');
    return createInstance(
      name: name,
      categories: categories,
      baseCategories: baseCategories,
    );
  }

  /// Creates a copy of this dictionary with optionally replaced characters
  /// and rules.
  ///
  /// When [merge] is `true`, the supplied characters and rules are added to
  /// copies of the existing collections. Otherwise, they replace them.
  Dictionary copyWith({dynamic characters, dynamic rules, bool merge = false}) {
    _log.finest(
      'Copy Dictionary $headString with different characters / rules.',
    );
    if (merge) {
      final mergedDict = createInstance();
      if (characters != null) mergedDict.add(characters, ordered: false);
      if (rules != null) mergedDict.add(rules, ordered: false);
      mergedDict.reorder();
      return mergedDict;
    }
    return createInstance(characters: characters, rules: rules);
  }

  /* ================================================================ */
  /*                              SORTING                             */
  /* ================================================================ */

  /// Sets the active sorting category and reorders the characters.
  ///
  /// When sorting categories are defined, [key] must be one of the supported
  /// sorting categories.
  set sortingKey(String key) {
    _log.config('Set sorting key to $key');
    if (_sortKeys.isNotEmpty) {
      isValid(key, _sortKeys, funcName: 'set sortingKey', argName: 'key');
    }
    key = key.toLowerCase();
    reorder(sortingKey: key);
  }

  /// Returns an independently sorted copy of this dictionary.
  ///
  /// [sortingKey] and [sortingOrd] optionally override the current sorting
  /// configuration of the copy.
  set sortingOrd(String order) {
    _log.config('Set sorting order to $order');
    isValid(order, _sortOrder, funcName: 'set sortingOrd', argName: 'order');
    order = order.toLowerCase();
    reorder(sortingOrd: order);
  }

  /// Returns an independently sorted copy of this dictionary.
  ///
  /// [sortingKey] and [sortingOrd] optionally override the current sorting
  /// configuration of the copy.
  Dictionary<C, R> sort({String? sortingKey, String? sortingOrd}) {
    _log.fine('Create sorted Dictionary by $sortingKey in $sortingOrd order');
    var sorted = copy();
    sorted.reorder(sortingKey: sortingKey, sortingOrd: sortingOrd);
    return sorted;
  }

  /// Reorders the characters in this dictionary in place.
  ///
  /// When [sortingKey] or [sortingOrd] is omitted, the current configuration
  /// is used. Both values are validated before the characters are sorted.
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
        if (resolvedOrd == 'ascending') {
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

  /// Returns a dictionary containing characters whose selected categories
  /// match [pattern].
  ///
  /// [searchCategories] defines the categories to search. When [exact] is
  /// `true`, the pattern must match a complete word; otherwise, substring
  /// matching is used.
  Dictionary<C, R> searchCategory({
    String pattern = "",
    List<String> searchCategories = const [],
    bool exact = true,
  }) {
    _log.fine(
      'Search Dictionary categories "$searchCategories" for pattern: $pattern',
    );

    /// Checks whether [content] contains [pattern] according to the
    /// selected matching mode.
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

    /// Checks whether a character contains [pattern] in the specified
    /// category or nested category structure.
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
}

/* ================================================================ */
/*                        CHINESE DICTIONARY                        */
/* ================================================================ */

/// A specialized Chinese implementation of the dictionary engine.
///
/// Binds the dictionary to [ChCharacter] and [ChRule] and provides
/// Chinese-specific sorting based on simplified characters, traditional
/// characters, and Pinyin.
class ChDictionary extends Dictionary<ChCharacter, ChRule> {
  @override
  Set<String> get _sortKeys => const {'simplified', 'traditional', 'pinyin'};
  @override
  Set<String> get _sortOrder => const {'ascending', 'descending'};

  @override
  List<String> get baseCategories => ['simplified', 'traditional', 'pinyin'];

  /// Creates a [ChDictionary] with Pinyin sorting in ascending order
  /// by default.
  ChDictionary(
    super.name, {
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
    List<String>? baseCategories,
  }) {
    _log.finer(
      'Create instance of ChDictionary $headString with other characters.',
    );
    return ChDictionary(
      name ?? this.name,
      characters: characters ?? List<ChCharacter>.from(this.characters),
      rules: rules ?? List<ChRule>.from(this.rules),
      // characters:
      // characters ?? this.characters.map((char) => char.copy()).toList(),
      // rules: rules ?? this.rules.map((rule) => rule.copy()).toList(),
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

    /// Returns the category priority hierarchy for [currentKey].
    List<String> getPriority(String currentKey) {
      return switch (currentKey) {
        'simplified' => ['simplified', 'traditional', 'pinyin'],
        // 'traditional' => ['traditional', 'pinyin', 'simplified'],
        'traditional' => ['traditional', 'simplified', 'pinyin'],
        'pinyin' => ['pinyin', 'simplified', 'traditional'],
        _ => ['pinyin', 'simplified', 'traditional'],
      };
    }

    /// Returns the string value of a character at the given priority level.
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

  /// Searches the Chinese dictionary by character, Pinyin, or variant forms.
  ///
  /// When [categories] is provided, the search is delegated to
  /// [searchCategory]. Otherwise, the search automatically considers
  /// the character's identifying forms, Pinyin variants, and Chinese
  /// character variants.
  ChDictionary search({
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
          )
          as ChDictionary;
    }

    final mod = TextModifier<String>('');

    /// Generates the Pinyin representations used for searching.
    List<String> getPinyinOptions(String pinyin) {
      final pinyinAccented = mod.set(pinyin).toToneMarkedPinyin().result;
      final pinyinNumeric = mod.toNumericPinyin().result;
      final pinyinPlain = mod.toPlainPinyin().result;
      if (!exact) return [pinyinPlain];
      return [pinyinNumeric, pinyinAccented];
    }

    /// Checks whether [char] contains any of the given search patterns.
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
        relevant.addAll(char.variants());
      }

      final cleanRelevant = relevant
          .map((String word) => word.replaceAll(' ', ''))
          .toList();
      return cleanRelevant.any(
        (String word) =>
            patterns.any((String pattern) => word.contains(pattern)),
      );
    }

    final String cleanPattern = pattern.toLowerCase().replaceAll(' ', '');
    final List<String> listPattern = getPinyinOptions(cleanPattern);
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

  /* –––––––––––––––––––––– collection element –––––––––––––––––––––– */

  @override
  ChCharacter _convertListItem(dynamic entry) {
    if (entry is List<dynamic> && entry.length == 3) {
      final Map<String, dynamic> update = {
        'simplified': entry[0],
        'traditional': entry[1],
        'pinyin': entry[2],
      };
      return super._convertListItem(update);
    }
    return super._convertListItem(entry);
  }

  @override
  ChCharacter _listItem({Map<String, dynamic> entry = const {}}) {
    return ChCharacter(
      entry: entry,
      categories: categories,
      mapSyntax: _mapSyntax,
      mapColor: _mapColor,
      mapColorFav: _mapColorFav,
    );
  }

  @override
  ChRule _ruleItem({Map<String, dynamic> entry = const {}}) {
    return ChRule(
      entry: entry,
      mapSyntax: _mapSyntax,
      mapColor: _mapColor,
      mapColorFav: _mapColorFav,
    );
  }

  @override
  Map<String, dynamic> _updateEntry(Map<String, dynamic> entry) {
    _log.finest(
      'Entry is changed (during reading of file). ${entry.keys.toList()}',
    );
    if (entry.containsKey('simple')) entry['simplified'] = entry['simple'];
    if (entry.containsKey('pronunciation')) {
      entry['pinyin'] = entry['pronunciation'];
    }
    if (entry.containsKey('opposite_structures')) {
      entry['structuresOpp'] = entry['structures_opposite'];
    }
    if (entry.containsKey('opposite_characters')) {
      entry['charactersOpp'] = entry['characters_opposite'];
    }
    for (final item in entry.entries) {
      final mod = TextModifier(item.value).trim(ignoreEmpty: true);
      entry[item.key] = mod.result;
    }

    return entry;
  }
}
