import 'package:suhan_lexicon/src/errors.dart';
import 'package:logging/logging.dart';
import 'package:collection/collection.dart';
import 'text_modifier.dart';
import 'utils.dart';
import 'dictionary.dart';

final Logger _log = Logger('CharacterLog');

/* ================================================================ */
/*                           CONFIGURATION                          */
/* ================================================================ */

final Set<String> _idMethods = {
  'unicode',
  'symbol',
  'hash',
}; // uniqueID : method

/* ================================================================ */
/*                       THE MIXIN COPY ENGINE                      */
/* ================================================================ */

/// Provides copy and reconfiguration operations for [Character] subclasses.
///
/// The mixin delegates object creation to [createInstance], allowing each
/// subclass to return its own concrete type while reusing the common
/// copy/reconfiguration API.
mixin CopyEngine<T extends Character> on Character {
  @override
  T createInstance({
    Map<String, Type>? categories,
    Map<String, dynamic>? entry,
    List<String>? baseCategories,
    bool? strict,
  });

  @override
  T copy() {
    return createInstance();
  }

  @override
  T reconfigure({Map<String, Type>? categories, List<String>? baseCategories}) {
    return createInstance(
      categories: categories,
      baseCategories: baseCategories,
    );
  }

  @override
  T copyWith(Map<String, dynamic> updates, {bool merge = false}) {
    return createInstance(entry: _updateDataWith(updates, merge: merge));
  }

  @override
  T relax() => createInstance(strict: false);

  @override
  T restrict() => createInstance(strict: true);
}

/* ================================================================ */
/*                             CHARACTER                            */
/* ================================================================ */

/// Represents a structured language object whose values are stored in named
/// categories.
///
/// [categories] defines the expected type of each category, while [data]
/// contains the current values. [baseCategories] identify the object and are
/// required when a character is created.
class Character {
  /* ––––––––––––––––––––– categories and values –––––––––––––––––––– */
  /// Stores the values belonging to this character.
  ///
  /// Keys correspond to the categories defined in [categories].
  final Map<String, dynamic> data = {};

  /// Defines the expected runtime type for each category.
  ///
  /// The map acts as the schema for [data]. Each category name is associated
  /// with the type of value that may be stored under that category.
  ///
  late final Map<String, Type> categories;

  /// Categories that uniquely identify this character.
  ///
  /// The values of these categories are used to construct [identifier] and
  /// therefore participate in character equality and dictionary deduplication.
  final List<String> baseCategories;

  /// Whether this character enforces its category schema.
  ///
  /// In strict mode, categories must be defined in [categories] and assigned
  /// values must match their configured types. Relaxed characters can accept
  /// dynamically inferred categories and types.
  final bool strict;

  /// Values of the identifying categories in [baseCategories] order.
  ///
  /// The returned list is used as the character's identifier for equality,
  /// hashing, and other operations that need to identify the character.
  List<String> get identifier => [
    for (String i in baseCategories) data[i].toString(),
  ];

  /// Returns the categories whose current value is not `null`.
  List<String> get filled {
    return [
      for (final catgegory in data.keys)
        if (data[catgegory] != null) catgegory,
    ];
  }

  /// Returns the categories whose current value is `null`.
  List<String> get missing {
    return [
      for (final catgegory in data.keys)
        if (data[catgegory] == null) catgegory,
    ];
  }

  /* ––––––––––––––––––––– syntax configuration ––––––––––––––––––––– */
  /// Syntax definitions used when formatting text.
  ///
  /// The map associates syntax commands with their corresponding formatting
  /// definitions.
  Map<String, dynamic>? mapSyntax;

  /// Color definitions used when formatting text.
  ///
  /// These definitions are used together with [mapSyntax] when formatted text
  /// is generated.
  Map<String, dynamic>? mapColor;

  /// Optional favorite color definitions used when formatting text.
  ///
  /// Favorite colors provide named color configurations that can be reused by
  /// syntax formatting operations.
  Map<String, dynamic>? mapColorFav;

  /// Reusable modifier for transforming individual string values.
  ///
  /// This modifier is shared by operations that repeatedly process strings,
  /// avoiding the need to create a new [TextModifier] for every operation.
  final TextModifier<String> _modString = TextModifier('');

  /// Reusable modifier for transforming lists of strings.
  ///
  /// This modifier is used when a character operation needs to process a
  /// collection of string values.
  final TextModifier<List<String>> _modListStr = TextModifier(['']);

  /// Reusable modifier for transforming string values from a map.
  ///
  /// The modifier operates on the map's string values while preserving the
  /// map structure. It is used by character operations that need to apply
  /// text transformations to a `Map<dynamic, String>`.
  final TextModifier<Map<dynamic, String>> _modMapStr = TextModifier(
    <String, String>{},
  );

  /* ================================================================ */
  /*                            CONSTRUCTOR                           */
  /* ================================================================ */

  /// Creates a character from a category schema and optional initial data.
  ///
  /// [categories] defines additional categories and their expected runtime types.
  /// [entry] supplies initial values. [baseCategories] identifies the
  /// character and is checked after initialization.
  ///
  /// [entry] provides the initial values for these categories. Each value is
  /// passed through [set], so the normal category validation and normalization
  /// rules are applied.
  ///
  /// In [strict] mode, the category schema is fixed,
  /// meaning the category map is unmodifiable.
  /// In relaxed mode, assigning a value can add or redefine a category's runtime type.
  ///
  /// [mapSyntax], [mapColor], and [mapColorFav] configure the text-formatting
  /// behavior used by this character.
  ///
  /// Every category listed in [baseCategories] is required to have a `String` value.
  Character({
    Map<String, Type> categories = const {},
    Map<String, dynamic> entry = const {},
    this.strict = true,
    List<String>? baseCategories,
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) : baseCategories = baseCategories ?? [] {
    Map<String, Type> finalCategories = {};
    if (mapColor != null && mapSyntax != null) {
      addSyntax(mapSyntax, mapColor, mapColorFav: mapColorFav);
    }

    finalCategories.addAll({
      for (final category in this.baseCategories) category: String,
    });
    finalCategories.addAll({
      for (final entry in categories.entries)
        if (!this.baseCategories.contains(entry.key)) entry.key: entry.value,
    });

    if (strict) {
      this.categories = Map.unmodifiable(finalCategories);
    } else {
      this.categories = finalCategories;
    }

    finalCategories.forEach((category, type) {
      _modifyCategory(null, category);
    });

    entry.forEach((category, value) {
      set(category, value);
    });

    _log.info('Successfully created character: ${toString()}');
  }

  /* ––––––––––––––––––––––––––––– copy ––––––––––––––––––––––––––––– */

  /// Creates a new [Character] using the supplied data and configuration.
  Character createInstance({
    Map<String, Type>? categories,
    Map<String, dynamic>? entry,
    List<String>? baseCategories,
    bool? strict,
  }) {
    _log.finer('Create instance of Character.');
    if (!hasSyntax) {
      _log.finest('Instance is missing syntax maps.');
    }
    return Character(
      categories: categories ?? Map<String, Type>.from(this.categories),
      entry: entry ?? data.deepCopy(),
      strict: strict ?? this.strict,
      baseCategories: baseCategories ?? this.baseCategories,
      mapSyntax: mapSyntax,
      mapColor: mapColor,
      mapColorFav: mapColorFav,
    );
  }

  /// Returns an independent copy of this character.
  ///
  /// The copy retains the current schema, identifiers, strictness, data, and
  /// syntax configuration.
  Character copy() {
    _log.finest('Copy Character ${toString()}.');
    return createInstance();
  }

  /// Returns a copy with a different category schema or identifier configuration.
  Character reconfigure({
    Map<String, Type>? categories,
    List<String>? baseCategories,
  }) {
    _log.finest('Copy Character ${toString()} with different configuration.');
    return createInstance(
      categories: categories,
      baseCategories: baseCategories,
    );
  }

  /// Creates a copy of this character with updated category values.
  ///
  /// By default, [updates] replaces the character's existing data.
  /// When [merge] is `true`, the updates are merged with the existing data.
  Character copyWith(Map<String, dynamic> updates, {bool merge = false}) {
    _log.finest('Update Character ${toString()} with $updates.');
    return createInstance(entry: _updateDataWith(updates, merge: merge));
  }

  /// Creates a non-strict copy of this character.
  ///
  /// In the returned character, the category schema can be modified after
  /// construction. The original character is not modified.
  Character relax() {
    return createInstance(strict: false);
  }

  /// Creates a strict copy of this character.
  ///
  /// In the returned character, the category schema is protected from
  /// modification after construction. The original character is not modified.
  Character restrict() {
    return createInstance(strict: true);
  }

  /* –––––––––––––––––––––––––– combination ––––––––––––––––––––––––– */

  /// Combines this character with another character or dictionary.
  ///
  /// When [other] is a [Character], a new [Dictionary] containing copies of
  /// both characters is returned. The current character is always copied, so
  /// modifying the returned dictionary does not modify this character.
  ///
  /// When [other] is a [Dictionary], the dictionary is reconfigured to use this
  /// character's category schema before the two collections are combined.
  ///
  /// Throws [UnsupportedLexiconOperationException] if [other] is neither a
  /// [Character] nor a [Dictionary].
  Dictionary operator +(dynamic other) {
    _log.fine('Addition of Character and ${other.runtimeType}.');
    final comboCategories = Map<String, Type>.from(categories);
    final List<Character> comboCharacters = [createInstance()];

    if (other is Character) {
      if (other.isNotEmpty && this != other) {
        comboCharacters.add(other.createInstance());
      }
    } else if (other is Dictionary) {
      return other.reconfigure(categories: comboCategories) + this;
    } else {
      _log.shout('Addition Failed: Unsupported type ${other.runtimeType}');
      throw UnsupportedOperationException('+', inputType: other.runtimeType);
    }
    return Dictionary(
      'dictionary',
      categories: comboCategories,
      characters: comboCharacters,
    );
  }

  /* –––––––––––––––––––––––– category access ––––––––––––––––––––––– */

  /// Returns the value stored under [category].
  ///
  /// Unlike [get], this operator treats an unknown category as an error instead
  /// of returning `null`.
  ///
  /// Throws [UnknownCategoryException] when [category] is not defined for this
  /// character.
  dynamic operator [](String category) {
    _log.finest('Lookup value of category "$category".');
    // different from get which can return null instead of error
    if (!data.containsKey(category)) {
      _log.shout('Category "$category" does not exist.');
      throw UnknownCategoryException(category);
    }
    return data[category];
  }

  /// Sets the value of [category].
  ///
  /// This uses strict validation and therefore reports invalid assignments
  /// instead of silently ignoring them.
  void operator []=(String category, dynamic value) {
    set(category, value, force: false);
  }

  /// Returns the value stored under [category].
  ///
  /// Returns `null` when the category is not defined or has no value.
  dynamic get(String category) {
    _log.finer('Lookup value of category $category.');
    if (!categories.containsKey(category)) {
      _log.warning('Lookup Ignored: category "$category" does not exist.');
      return null; // Return null instead of crashing if a field doesn't exist
    }
    return data[category];
  }

  /// Returns whether [category] is defined for this character.
  ///
  /// This checks the category schema, not whether the category currently
  /// contains a non-null value.
  bool contains(String category) {
    return categories.containsKey(category);
  }

  /* –––––––––––––––––––––– identity & equality ––––––––––––––––––––– */

  /// Compares this character with [other] using its identifying categories.
  ///
  /// Two characters are considered equal when they are both [Character]
  /// instances and their [identifier] values are equal in the same order.
  ///
  /// Equality does not compare the complete contents of [data]. Use [exact]
  /// when the complete character data should be compared.
  @override
  bool operator ==(Object other) {
    _log.finest('Compare Character ${toString()} to ${other.toString()}');
    if (identical(this, other)) return true;
    if (other is! Character) return false;
    return const ListEquality<String>().equals(identifier, other.identifier);
  }

  /// Returns a hash based on the character's identifying categories.
  ///
  /// The hash is consistent with [operator ==]: characters with equal
  /// identifiers produce the same hash code.
  @override
  int get hashCode => const ListEquality<String>().hash(identifier);

  /// Returns the character's hash code as a zero-padded string.
  ///
  /// The formatted value is used by [uniqueID] and is useful when a stable,
  /// fixed-width identifier is required.
  String get hashCodeFormatted => hashCode.toString().padLeft(10, '0');

  /// Returns a unique identifier based on the character's hash code.
  String uniqueID() => hashCodeFormatted;

  /* –––––––––––––––––––––––––– comparison –––––––––––––––––––––––––– */

  /// Compares the complete data of this character with [other].
  ///
  /// Unlike [operator ==], which compares only the identifying categories,
  /// this method compares the complete contents of [data].
  ///
  /// When [ignoreNull] is `true`, categories whose value is `null` are removed
  /// from both objects before comparison.
  bool exact(Character other, {bool ignoreNull = false}) {
    if (this != other) return false;
    _log.fine(
      'Compare exact Character data of ${toString()} and ${other.toString()}',
    );
    if (ignoreNull) {
      final Map<String, dynamic> cleanThis = Map.from(data)
        ..removeWhere((category, value) => value == null);
      final Map<String, dynamic> cleanOther = Map.from(other.data)
        ..removeWhere((category, value) => value == null);
      return const DeepCollectionEquality().equals(cleanThis, cleanOther);
    }
    return const DeepCollectionEquality().equals(data, other.data);
  }

  /* ––––––––––––––––––––––––––––– state –––––––––––––––––––––––––––– */

  /// Whether all identifying categories are empty.
  ///
  /// This is based on [identifier], rather than checking every category in
  /// [data].
  bool get isEmpty => identifier.every((slot) => slot.isEmpty);

  /// Whether at least one identifying category contains a value.
  bool get isNotEmpty => !isEmpty;

  /// Whether all data is empty
  ///
  /// This checks content of all categories in [data], rather than only values in [identifier].
  bool get isCompletelyEmpty => isMapCompletelyEmpty(toMap());

  /* –––––––––––––––––––––––– representation –––––––––––––––––––––––– */

  /// Returns a human-readable representation of the character.
  ///
  /// The values of [baseCategories] are displayed in their configured order
  /// and separated by `|`.
  @override
  String toString() {
    List<String> values = [for (var i in baseCategories) data[i].toString()];
    String repr = values.join(' | ');
    return '〔 $repr 〕';
  }

  /// Converts the character's data into a map representation.
  ///
  /// Nested library objects are converted into values suitable for structured
  /// output by [convertMixedMap].
  Map<String, dynamic> toMap() {
    return convertMixedMap(data);
  }

  /// Converts the character data into a Markdown table.
  String toMarkdownTable() {
    final String mdTable;
    final List<String> columns = ['Category', 'Value'];
    final String sep = ' | ';
    String head = "${sep.trimLeft()} ${(columns).join(sep)} ${sep.trimRight()}";
    head +=
        "\n${sep.trimLeft()} ${List.filled(columns.length, ':---').join(sep)} ${sep.trimRight()}";
    List<String> body = [];
    for (final entry in data.entries) {
      final String category = '**${entry.key.toUpperCase()}**';
      dynamic values = entry.value;
      if (values is List && values.isEmpty) values = '';
      if (values is String || values is num) {
        body.add("\n${sep.trimLeft()}$category$sep$values${sep.trimRight()}");
      }
      if (convertToPrimitive(values) is List) {
        values = values.toList();
      }
      if (values is List) {
        final List<String> listValues = values.map((element) {
          String elHead;
          elHead = element.toString();
          var elBody = convertToPrimitive(element);
          final List<String> elBodyList;
          if (elBody is Map) {
            elBodyList = elBody.entries
                .map((entry) => '`${entry.key}` ${entry.value}')
                .toList();
          } else if (elBody is List) {
            elBodyList = elBody.map((e) => '$e').toList();
          } else {
            elBodyList = [];
          }
          if (elBodyList.isNotEmpty) {
            elHead =
                "$elHead<br>${List.filled(3, '&nbsp;').join()}${elBodyList.join(' , ')}";
          }

          // return '<ul><li>$elHead</li></ul>';
          // ignore: unnecessary_string_escapes
          return '• ${List.filled(1, '&nbsp;').join()}${elHead.replaceAll(r'|', '\\\|')}';
        }).toList();
        body.add(
          "\n${sep.trimLeft()}$category$sep${listValues.join('<br>')}${sep.trimRight()}",
        );
      }
      // if (values is Map) values = values.entries.toList();
    }
    mdTable = '$head${body.join("")}';
    return mdTable;
  }

  /// on [show] prints a human-readable representation of the character's data.
  void info({bool show = true}) {
    _log.fine('Print all data for Character Object ${toString()}');
    const int width = 23;
    final String distance = ''.padRight(width);
    final String listIndent = '|${distance.substring(0, distance.length - 1)}';
    final StringBuffer buffer = StringBuffer();
    final Map<String, dynamic> data = toMap();

    for (final entry in data.entries) {
      final String cat = entry.key;
      final dynamic values = entry.value;

      // Format the category header to be uppercase and left-aligned
      final String catText = '|${cat.toUpperCase().padRight(width - 3)}';
      final String head = '\n${catText.padRight(width)}';

      if (values is List || values is Map) {
        final List<String> listLines = [];

        // Normalize both Maps and Lists into an iterable list of key-value pairs
        final List<MapEntry<dynamic, dynamic>> items = [];
        if (values is Map) {
          items.addAll(values.entries);
        } else if (values is List) {
          for (int i = 0; i < values.length; i++) {
            items.add(MapEntry(i, values[i]));
          }
        }
        final int numItems = items.length;
        if (numItems == 0) listLines.add('|');
        for (int idx = 0; idx < numItems; idx++) {
          final MapEntry<dynamic, dynamic> item = items[idx];
          String elementStr;

          if (values is Map) {
            elementStr = '${item.key}: ${item.value}';
          } else {
            elementStr = '${item.value}';
          }

          listLines.add('| - $elementStr\n');

          // Add the vertical alignment spacer if it isn't the final element
          if (idx + 1 != numItems) {
            listLines.add(listIndent);
          }
        }

        String helper = '$head${listLines.join('')}';
        helper = helper.replaceFirstMapped(RegExp(r'\n$'), (match) => '');
        buffer.write(helper);
      } else if (values is String || values is num) {
        buffer.write('$head| $values');
      }
    }

    if (show) print(buffer.toString());
  }

  /* ––––––––––––––––––––––– category mutation –––––––––––––––––––––– */

  /// Sets [value] for [category].
  ///
  /// In strict mode, the category must already exist and the value must match
  /// its configured type. In relaxed mode, new categories can be added and
  /// their type is inferred from the value.
  ///
  /// When [force] is `true`, invalid assignments are ignored after being
  /// logged. When [force] is `false`, invalid assignments throw an exception.
  void set(String category, dynamic value, {bool force = true}) {
    // force will turn off the envorcement for correct categories (with Errors)
    _log.finest('Set value of category. ($category : $value)');
    if (!categories.containsKey(category) && strict) {
      value = null;
      _log.shout(
        'Cannot add value to Character. Category "$category" does not exist.',
      );
      if (!force) throw UnknownCategoryException(category);
      return;
    } else {
      final Type targetType;
      if (value == null) {
        return _modifyCategory(null, category);
      }
      if (!strict) {
        // targetType = dynamic;
        final currentType = value.runtimeType;
        final internalType = convertInternalType[currentType.toString()];
        targetType = internalType ?? currentType;
        _log.finest('New category type is: $targetType');
        categories[category] = internalType ?? targetType;
      } else {
        targetType = categories[category] ?? Null;
      }

      if (isListType(value.runtimeType) && isListType(targetType)) {
        // print([value.runtimeType, targetType]);
      }

      if (isMapType(value.runtimeType) && isMapType(targetType)) {
        return _modifyCategory(
          convertMapToType(value as Map<dynamic, dynamic>, targetType),
          category,
        );
      }

      if (!sameTypes(value.runtimeType, targetType) && strict) {
        _log.shout(
          'Cannot add value to Character. Type Mismatch for category "$category". Expected $targetType, got ${value.runtimeType}.',
        );
        if (!force) {
          throw CategoryTypeMismatchException(
            category,
            targetType,
            value.runtimeType,
          );
        }
        return;
      }

      return _modifyCategory(value, category);
    }
  }

  /// Initializes or replaces the value of [category] without performing
  /// validation.
  ///
  /// A missing value is represented by `null`. Mandatory base categories are
  /// initialized with an empty string instead.
  void _modifyCategory(dynamic result, String category) {
    if (baseCategories.contains(category) && result == null) {
      result = "";
    }
    if (categories.containsKey(category)) {
      data[category] = result;
    }
  }

  /// Removes the value stored in [category].
  ///
  /// The category itself remains part of the character schema. For mandatory
  /// base categories, removing the value resets it to an empty string.
  void remove(String category) {
    _log.finer('Remove category "$category" from Character $toString()');
    if (!categories.containsKey(category)) {
      _log.warning('Remove Ignored: category "$category" does not exist.');
      return;
    }
    set(category, null);
  }

  /* ––––––––––––––––––––––––– bulk updates ––––––––––––––––––––––––– */

  /// Updates multiple categories from [entry].
  ///
  /// When [merge] is `true`, existing lists and maps are merged with the new
  /// values. Otherwise, supplied values replace the existing values.
  void update(Map<String, dynamic> entry, {bool merge = false}) {
    _log.fine('Update data of Character ${toString()}');
    _log.finest('with categories: ${entry.keys.toList().join(", ")}');
    Map<String, dynamic> updates = entry;
    if (merge) updates = _mergeUpdates(updates);

    updates.forEach((category, value) {
      set(category, value, force: true);
    });
  }

  /// Updates a map-valued category without replacing the entire map.
  ///
  /// [updates] are added to the existing map. Passing `null` clears the
  /// category.
  ///
  /// Throws [UnknownCategoryException] when [category] does not exist, or
  /// [CategoryTypeMismatchException] when the category is not map-valued.
  void updateCategoryMap(String category, Map<String, dynamic>? updates) {
    _log.fine('Update Character category "$category" but only if its a map.');
    if (!categories.containsKey(category)) {
      _log.shout('Cannot update because category "$category" does not exist.');
      throw UnknownCategoryException(category);
    }
    Type catType = categories[category] ?? Null;
    if (!isMapType(catType)) {
      _log.shout(
        'Cannot update category "$category". Type of category is not Map: $catType',
      );
      throw CategoryTypeMismatchException(category, Map, catType);
    }
    if (updates == null) {
      set(category, null);
      return;
    }
    final Map<String, dynamic> currentMap = Map<String, dynamic>.from(
      data[category] as Map<String, dynamic>? ?? const <String, dynamic>{},
    );

    currentMap.addAll(updates);
    set(category, currentMap);
  }

  /// Merges [updates] with the character's current data.
  ///
  /// Existing lists are extended and existing maps are merged. Other values
  /// replace their existing value.
  Map<String, dynamic> _mergeUpdates(Map<String, dynamic> updates) {
    return updates.map((key, value) {
      if (categories.containsKey(key)) {
        if (value is List) {
          final dataValue = data[key] as List;
          final after = List<dynamic>.from(dataValue);
          after.addAll(value);
          return MapEntry(key, after);
        }
        if (value is Map) {
          final dataValue = data[key] as Map;
          final after = {...dataValue, ...value};
          return MapEntry(key, after);
        }
        return MapEntry(key, value);
      }
      return MapEntry(key, value);
    });
  }

  /// Creates a new data map by applying [updates] to the current data.
  ///
  /// When [merge] is `true`, lists and maps are merged using [_mergeUpdates].
  /// The character's existing [data] map is never modified.
  Map<String, dynamic> _updateDataWith(
    Map<String, dynamic> updates, {
    bool merge = true,
  }) {
    _log.fine('Update data with $updates (do merge: $merge)');
    if (merge) {
      final merged = _mergeUpdates(updates);
      return {...data, ...merged};
    }
    return Map<String, dynamic>.from(updates);
  }

  /* ––––––––––––––––––––– syntax configuration ––––––––––––––––––––– */

  /// Whether syntax and color configuration is available.
  bool get hasSyntax => mapColor != null && mapSyntax != null;

  /// Adds or updates the syntax and color configuration.
  ///
  /// Existing values are kept when the corresponding argument is `null`.
  /// The configuration is also applied to the internal text modifiers.
  void addSyntax(
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor, {
    Map<String, dynamic>? mapColorFav,
  }) {
    if (hasSyntax) _log.finest('Syntax will be redefined.');

    this.mapSyntax = mapSyntax ?? this.mapSyntax;
    this.mapColor = mapColor ?? this.mapColor;
    this.mapColorFav = mapColorFav ?? this.mapColorFav;
    _modString.addSyntax(
      mapSyntax: this.mapSyntax,
      mapColor: this.mapColor,
      mapColorFav: this.mapColorFav,
    );
    _modListStr.addSyntax(
      mapSyntax: this.mapSyntax,
      mapColor: this.mapColor,
      mapColorFav: this.mapColorFav,
    );
    _modMapStr.addSyntax(
      mapSyntax: this.mapSyntax,
      mapColor: this.mapColor,
      mapColorFav: this.mapColorFav,
    );
    _log.info('Successfully defined syntax for Character ${toString()}.');
  }

  /* ––––––––––––––––––––––– text modification –––––––––––––––––––––– */

  /// Creates a [TextModifier] suitable for [input].
  ///
  /// Reusable modifiers are used for strings, lists of strings, and maps of
  /// strings. Other non-null values receive a new modifier.
  ///
  /// Throws [InvalidModifierInputException] when [input] is `null`.
  TextModifier<dynamic> modifier(dynamic input) {
    if (input is String) {
      return _modString.set(input);
    } else if (input is List<String>) {
      return _modListStr.set(List<String>.from(input));
    } else if (input is Map<dynamic, String>) {
      return _modMapStr.set(Map<dynamic, String>.from(input));
    } else {
      return TextModifier(input);
    }
  }

  /// Creates a [TextModifier] for the value stored in [category].
  ///
  /// When [transform] is `true`, changes made through the returned modifier
  /// are written back to the category. The character's syntax configuration
  /// is also applied to the modifier.
  ///
  /// When [transform] is `false`, the modifier is returned without the
  /// callback that updates the category.
  TextModifier<dynamic> modify(String category, {bool transform = true}) {
    _log.fine(
      'Create TextModifier for category "$category" of Type ${get(category).runtimeType}.',
    );

    final input = get(category);
    final TextModifier<dynamic> mod = modifier(input);

    if (transform) {
      final modCopy = mod.copyWith(
        transform: (result) => _modifyCategory(result, category),
        mapSyntax: mapSyntax,
        mapColor: mapColor,
        mapColorFav: mapColorFav,
      );
      return modCopy;
    }
    return mod;
  }
}

/// Represents a Chinese character with fixed identifying categories.
///
/// A [ChCharacter] is identified by its simplified form, traditional form,
/// and Pinyin. These categories are always used as the character's
/// [identifier].
class ChCharacter extends Character with CopyEngine<ChCharacter> {
  /// Categories that identify a Chinese character.
  @override
  List<String> get baseCategories => const [
    'simplified',
    'traditional',
    'pinyin',
  ];

  /// Creates a Chinese character.
  ///
  /// Additional categories can be supplied through [categories], while initial
  /// category values can be supplied through [entry].
  ChCharacter({
    super.categories,
    super.entry,
    super.mapSyntax,
    super.mapColor,
    super.mapColorFav,
  });

  /// Creates an independent copy of this Chinese character.
  ///
  /// The returned instance remains a [ChCharacter] and retains its current
  /// data, category schema, and syntax configuration.
  ///
  /// [baseCategories] cannot be changed because Chinese characters always
  /// use the three fixed identifying categories defined by [baseCategories].
  @override
  ChCharacter createInstance({
    Map<String, dynamic>? entry,
    Map<String, Type>? categories,
    List<String>? baseCategories,
    bool? strict,
  }) {
    _log.finer('Create instance of ChCharacter.');
    if (baseCategories != null) {
      _log.finest('Cannot change baseCategories of ChCharacter.');
    }
    return ChCharacter(
      entry: entry ?? data.deepCopy(),
      categories: categories ?? Map<String, Type>.from(this.categories),
      mapSyntax: mapSyntax,
      mapColor: mapColor,
      mapColorFav: mapColorFav,
    );
  }

  /* –––––––––––––––––– category text normalization ––––––––––––––––– */

  /// Sets [value] for [category] after applying Chinese-specific normalization.
  ///
  /// Pinyin is converted to numeric Pinyin, while simplified and traditional
  /// Chinese text is cleaned before being passed to the base implementation.
  @override
  void set(String category, value, {bool force = true}) {
    if (category == 'pinyin' && value is String) {
      value = modifier(value).toNumericPinyin().result;
      _log.finer('Convert pinyin to numeric style.');
    }
    if ((category == 'simplified' || category == 'traditional') &&
        value is String) {
      value = modifier(value).toCleanLanguage('chinese').result;
      _log.finer('Cleanup chinese character symbols.');
    }
    super.set(category, value, force: force);
  }

  /* –––––––––––––––––––––––– identification –––––––––––––––––––––––– */

  /// Returns the identifier words used to generate a unique ID.
  ///
  /// If the second identifier is empty, the first identifier is used twice.
  List<String> get uniqueWords {
    final String s0 = identifier[0];
    final String s1 = identifier[1];
    final List<String> idWords = s1.isEmpty ? [s0, s0] : [s0, s1];
    return idWords;
  }

  /// Returns the identifier words as Unicode code points.
  List<String> get _toUnicode {
    final List<String> idWords = uniqueWords;

    List<String> unicodeList = [];

    for (String symbols in idWords) {
      List<String> unicodeSymbols = [];
      for (int i = 0; i < symbols.length; i++) {
        final String symbol = symbols[i];
        if (symbol.isNotEmpty) {
          final String hexCode = symbol
              .codeUnitAt(0)
              .toRadixString(16)
              .toUpperCase()
              .padLeft(4, '0');
          unicodeSymbols.add('U+$hexCode');
        }
      }

      if (unicodeSymbols.isNotEmpty) {
        unicodeList.add(unicodeSymbols.join(''));
      }
    }
    return unicodeList;
  }

  /// Creates a unique identifier for the Chinese character.
  ///
  /// [method] determines how the identifier is generated:
  /// - `unicode` uses the character's Unicode code points.
  /// - `symbol` uses the character symbols directly.
  /// - `hash` uses the character's hash code.
  ///
  /// Throws [UnimplementedFeatureException] when [method] is not supported.
  @override
  String uniqueID({String method = 'unicode'}) {
    isValid(method, _idMethods, funcName: 'uniqueID', argName: 'method');

    String unique = switch (method) {
      'unicode' =>
        '${plainPinyin}_${[for (String c in _toUnicode) c.replaceAll('+', '')].join('_')}',
      'symbol' => '${plainPinyin}_${uniqueWords.join('_')}',
      'hash' => '${plainPinyin}_$hashCodeFormatted',
      _ => throw UnimplementedFeatureException('uniqueID', mode: method),
    };

    if (unique.startsWith('_')) unique = 'empty_char';

    return unique;
  }

  /* –––––––––––––––––––––––– character data –––––––––––––––––––––––– */

  /// Returns image data stored in [category].
  ///
  /// The default category is `images`.
  dynamic images({String category = 'images'}) {
    final rawValue = get(category);

    if (rawValue == null || !isMapType(rawValue.runtimeType)) {
      return null;
    }

    final targetType = categories[category];

    if (targetType == null) {
      return null;
    } else if (!isMapType(targetType)) {
      _log.warning('Category for images "$category" is not a map.');
      return null;
    }

    final mapValue = rawValue as Map<dynamic, dynamic>;
    final converted = convertMapToType(mapValue, targetType);
    return converted;
  }

  /// Returns the character variants stored in [category].
  ///
  /// The default category is `variants`.
  List<String> variants({String category = 'variants'}) {
    final variantsData = get(category);
    if (variantsData == null || variantsData is! List) return [];
    final variants = List<String>.from(variantsData);
    final mod = modifier(variants) as TextModifier<List<String>>;
    return mod.findFirstChar('chinese').result;
  }

  /* ––––––––––––––––––––––––– chinese data ––––––––––––––––––––––––– */

  /// Returns the character's Pinyin in numeric tone notation.
  String get numericPinyin {
    final mod = modifier(get('pinyin')) as TextModifier<String>;
    return mod.toNumericPinyin().result;
  }

  /// Returns the character's Pinyin with tone marks.
  String get toneMarkedPinyin {
    final mod = modifier(get('pinyin')) as TextModifier<String>;
    return mod.toToneMarkedPinyin().result;
  }

  /// Returns the character's Pinyin without tone information.
  String get plainPinyin {
    final String pinyin = get('pinyin') as String;
    final mod = modifier(pinyin) as TextModifier<String>;
    return mod.toPlainPinyin().result;
  }
}
