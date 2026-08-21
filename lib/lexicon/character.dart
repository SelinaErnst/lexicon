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

mixin CopyEngine<T extends Character> on Character {
  // redefine the resulting Type of

  @override
  T createInstance({
    Map<String, Type>? specs,
    Map<String, dynamic>? entry,
    List<String>? baseCategories,
  });

  @override
  T copy() {
    return createInstance();
  }

  @override
  T reconfigure({Map<String, Type>? specs, List<String>? baseCategories}) {
    return createInstance(specs: specs, baseCategories: baseCategories);
  }

  @override
  T copyWith(Map<String, dynamic> updates, {bool merge = false}) {
    return createInstance(entry: _updateDataWith(updates, merge: merge));
  }
}

/* ================================================================ */
/*                          IMPLEMENTATION                          */
/* ================================================================ */

class Character {
  late final Map<String, Type> categories;
  final Map<String, dynamic> data = {};
  final bool strict;

  final TextModifier<String> _modString = TextModifier('');

  Map<String, dynamic>? _mapSyntax;
  Map<String, dynamic>? _mapColor;
  Map<String, dynamic>? _mapColorFav;

  final List<String> baseCategories;

  // List<String> get baseCategories => _identifiers;

  /* ================================================================ */
  /*                            CONSTRUCTOR                           */
  /* ================================================================ */

  Character({
    Map<String, Type> specs = const {},
    Map<String, dynamic> entry = const {},
    this.strict = true, // default for all subclasses
    this.baseCategories = const [],
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) {
    Map<String, Type> finalCategories = {};
    if (mapColor != null && mapSyntax != null) {
      addSyntax(mapSyntax, mapColor, mapColorFav: mapColorFav);
    }

    finalCategories.addAll({
      for (final category in baseCategories) category: String,
    });
    finalCategories.addAll(specs);

    if (strict) {
      categories = Map.unmodifiable(finalCategories);
    } else {
      categories = finalCategories;
    }

    finalCategories.forEach((category, type) {
      if (baseCategories.contains(category) && type == String) {
        data[category] = '';
      } else {
        data[category] = null;
      }
    });

    entry.forEach((category, value) {
      set(category, value);
    });

    for (final idKey in baseCategories) {
      final value = data[idKey];
      if (value == null) {
        _log.shout('Value of baseCategory "$idKey" cannot be null.');
        throw ArgumentError(
          'Mandatory field missing: Each character entry requires a valid $idKey string.',
        );
      }
    }

    _log.info('Successfully created character: ${toString()}');
  }

  /* ––––––––––––––––––––––––––––– copy ––––––––––––––––––––––––––––– */

  Character createInstance({
    Map<String, Type>? specs,
    Map<String, dynamic>? entry,
    List<String>? baseCategories,
  }) {
    _log.finer('Create instance of Character with different entry.');
    if (_hasSyntax) {
      return Character(
        specs: specs ?? Map<String, Type>.from(categories),
        entry: entry ?? data.deepCopy(),
        baseCategories: baseCategories ?? this.baseCategories,
        strict: strict,
        mapSyntax: _mapSyntax,
        mapColor: _mapColor,
        mapColorFav: _mapColorFav,
      );
    }
    _log.finest('Instance is missing syntax maps.');
    return Character(
      specs: specs ?? Map<String, Type>.from(categories),
      entry: entry ?? data.deepCopy(),
      strict: strict,
      baseCategories: baseCategories ?? this.baseCategories,
    );
  }

  Character copy() {
    _log.finest('Copy Character ${toString()}.');
    return createInstance();
  }

  Character reconfigure({
    Map<String, Type>? specs,
    List<String>? baseCategories,
  }) {
    _log.finest('Copy Character ${toString()} with different configuration.');
    return createInstance(specs: specs, baseCategories: baseCategories);
  }

  Character copyWith(Map<String, dynamic> updates, {bool merge = false}) {
    _log.finest('Update Character ${toString()} with $updates.');
    return createInstance(entry: _updateDataWith(updates, merge: merge));
  }

  Character _changeStrictness(bool strict) {
    _log.finer('Change Character strictness to $strict.');

    if (_hasSyntax) {
      return Character(
        specs: Map<String, Type>.from(categories),
        entry: data.deepCopy(),
        strict: strict,
        baseCategories: baseCategories,
        mapSyntax: _mapSyntax,
        mapColor: _mapColor,
        mapColorFav: _mapColorFav,
      );
    }
    _log.finest('Syntax maps are missing.');
    return Character(
      specs: Map<String, Type>.from(categories),
      entry: data.deepCopy(),
      strict: strict,
      baseCategories: baseCategories,
    );
  }

  Character relax() {
    return _changeStrictness(false);
  }

  Character restrict() {
    return _changeStrictness(true);
  }

  /* ================================================================ */
  /*                           BASIC METHODS                          */
  /* ================================================================ */

  /* –––––––––––––––––––– operator (magic method) ––––––––––––––––––– */
  Dictionary operator +(dynamic other) {
    _log.fine('Addition of Character and ${other.runtimeType}.');
    final comboCategories = Map<String, Type>.from(categories);
    final List<Character> comboCharacters = [createInstance()];

    if (other is Character && !other.isEmpty && this != other) {
      comboCharacters.add(other.createInstance());
    } else if (other is Dictionary) {
      return other.copyWith(categories: comboCategories) + this;
    } else {
      _log.warning('Addition Failed: Unsupported type ${other.runtimeType}');
      throw UnsupportedError(
        'Addition is not supported for type ${other.runtimeType}',
      );
    }
    return Dictionary(categories: comboCategories, characters: comboCharacters);
  }

  dynamic operator [](String category) {
    _log.finest('Lookup value of category "$category".');
    // different from get which can return null instead of error
    if (!categories.containsKey(category)) {
      _log.shout(
        'Category "$category" does not exist in predefined categories.',
      );
      throw ArgumentError('Category "$category" does not exist.');
    }
    return data[category];
  }

  void operator []=(String category, dynamic value) {
    set(category, value, force: !strict);
  }

  @override
  int get hashCode => const ListEquality<String>().hash(identifier);

  String _formatHashCode(int hash) {
    return hash.toString().padLeft(10, '0');
  }

  String get hashCodeFormatted {
    return _formatHashCode(hashCode);
  }

  bool contains(String category) {
    return categories.containsKey(category);
  }

  @override
  String toString() {
    List<String> values = [for (var i in baseCategories) data[i].toString()];
    String repr = values.join(' | ');
    return '〔 $repr 〕';
  }

  Map<String, dynamic> toMap() {
    return convertMixedMap(data);
  }

  @override
  bool operator ==(Object other) {
    _log.finest('Compare Character ${toString()} to ${other.toString()}');
    if (identical(this, other)) return true;
    if (other is! Character) return false;
    return const ListEquality<String>().equals(identifier, other.identifier);
  }

  /* –––––––––––––––––––––––––––– compare ––––––––––––––––––––––––––– */

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

  bool get isEmpty {
    return identifier.every((slot) => slot.isEmpty);
  }

  /* –––––––––––––––––––––––––– attributes –––––––––––––––––––––––––– */

  List<String> get identifier => [
    for (String i in baseCategories) data[i] as String,
  ];

  List<String> get filled {
    return [
      for (final k in data.keys)
        if (data[k] != null) k,
    ];
  }

  List<String> get missing {
    return [
      for (final k in data.keys)
        if (data[k] == null) k,
    ];
  }

  /* ================================================================ */
  /*                            INFO SCREEN                           */
  /* ================================================================ */

  void info() {
    _log.fine('Print all data for Character ${toString()}');
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

    print(buffer.toString());
  }
  /* ================================================================ */
  /*                              SETTER                              */
  /* ================================================================ */

  void set(String category, dynamic value, {bool force = true}) {
    // force will turn off the envorcement for correct categories (with Errors)
    _log.finest('Set value of category. ($category : $value)');

    if (!categories.containsKey(category) && strict) {
      value = null;
      _log.severe('Ignore Set: Category "$category" does not exist.');
      if (!force) throw ArgumentError('Category "$category" does not exist');
    } else {
      final Type targetType;
      if (!strict) {
        // targetType = dynamic;
        targetType = value.runtimeType;
        categories[category] = targetType;
      } else {
        targetType = categories[category] ?? Null;
      }

      if (isMapType(value.runtimeType) && isMapType(targetType)) {
        final mapValue = value as Map<dynamic, dynamic>;
        value = convertMapToType(mapValue, targetType);
        data[category] = value;
      }

      if (!sameTypes(value.runtimeType, targetType) &&
          value != null &&
          strict) {
        _log.severe(
          'Ignore Set: Type Mismatch for "$category". Expected $targetType, got ${value.runtimeType}.',
        );
        value = data[category];
        if (!force) throw TypeError();
      }
      data[category] = value;
    }
  }

  void remove(String category) {
    _log.finer('Remove category "$category" from Character $toString()');
    if (!categories.containsKey(category)) {
      _log.warning('Remove Ignored: category "$category" does not exist.');
      return;
    }
    if (baseCategories.contains(category)) {
      data[category] = '';
      _log.finest('Reset identifier value for "$category" to empty string.');
    } else {
      data[category] = null;
      _log.finest('Reset optional value for "$category" to null.');
    }
  }

  dynamic get(String category) {
    _log.fine('Lookup value of category $category.');
    if (!categories.containsKey(category)) {
      _log.warning('Lookup Ignored: category "$category" does not exist.');
      return null; // Return null instead of crashing if a field doesn't exist
    }
    return data[category];
  }

  void update(Map<String, dynamic> entry, {bool merge = false}) {
    _log.fine(
      'Update Character ${toString()} with categories: ${entry.keys.toList().join(", ")}',
    );
    Map<String, dynamic> updates = entry;
    if (merge) updates = _mergeUpdates(updates);

    updates.forEach((category, value) {
      set(category, value, force: true);
    });
  }

  void updateCategoryMap(String category, Map<String, dynamic>? updates) {
    _log.fine('Update Character category "$category" but only if its a map.');
    if (!categories.containsKey(category)) {
      _log.shout(
        'Cannot update because category does not exist in predefined categories.',
      );
      throw ArgumentError('Category "$category" does not exist.');
    }
    Type catType = categories[category] ?? Null;
    if (!isMapType(catType)) {
      _log.shout('Value cannot be used if not Map, actual type: $catType');
      throw ArgumentError(
        'Category "$category" is registered as $catType, not a Map.',
      );
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

  /* ================================================================ */
  /*                              MODIFY                              */
  /* ================================================================ */

  void addSyntax(
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor, {
    Map<String, dynamic>? mapColorFav,
  }) {
    if (_hasSyntax) _log.finest('Syntax will be redefined.');

    _mapSyntax = mapSyntax ?? _mapSyntax;
    _mapColor = mapColor ?? _mapColor;
    _mapColorFav = mapColorFav ?? _mapColorFav;
    _modString.addAction(_mapSyntax, _mapColor, mapColorFav: mapColorFav);
    _log.info('Successfully defined syntax for Character ${toString()}.');
  }

  bool get _hasSyntax => _mapColor != null && _mapSyntax != null;

  TextModifier modify(String category) {
    _log.fine(
      'Create TextModifier for category "$category" of Type ${get(category).runtimeType}.',
    );
    final input = get(category);
    if (input is String) {
      var modifier = TextModifier<String>(input);
      if (_hasSyntax) {
        modifier.addAction(_mapSyntax, _mapColor, mapColorFav: _mapColorFav);
      }
      return modifier;
    }
    if (input is List<String>) {
      var modifier = TextModifier<List<String>>(input);
      if (_hasSyntax) {
        modifier.addAction(_mapSyntax, _mapColor, mapColorFav: _mapColorFav);
      }
      return modifier;
    }
    _log.shout(
      'Cannot create TextModifier due to incorrect input type: ${get(category).runtimeType}',
    );
    throw ArgumentError(
      'Values of category "$category" are not compatible with TextModifier.',
    );
  }
}

class ChCharacter extends Character with CopyEngine<ChCharacter> {
  final String _imageKey = 'images';
  final String _variantKey = 'variants';

  @override
  List<String> get baseCategories => const [
    'simplified',
    'traditional',
    'pinyin',
  ];

  ChCharacter({
    super.specs,
    super.entry,
    super.mapSyntax,
    super.mapColor,
    super.mapColorFav,
  });

  /* ================================================================ */
  /*                             OVERRIDE                             */
  /* ================================================================ */

  @override
  void set(String category, value, {bool force = true}) {
    if (category == 'pinyin' && value is String) {
      value = _modString.set(value).toNumericPinyin().result;
      _log.finer('Convert pinyin to numeric style.');
    }
    if ((category == 'simplified' || category == 'traditional') &&
        value is String) {
      value = _modString.set(value).toCleanLanguage('chinese').result;
      _log.finer('Cleanup chinese character symbols.');
    }
    super.set(category, value, force: force);
  }

  @override
  ChCharacter createInstance({
    Map<String, Type>? specs,
    Map<String, dynamic>? entry,
    List<String>? baseCategories,
  }) {
    if (baseCategories != null) {
      _log.fine('Cannot change baseCategories of ChCharacter.');
    }
    _log.finer('Create instance of Character with different entry.');
    if (_hasSyntax) {
      return ChCharacter(
        specs: specs ?? Map<String, Type>.from(categories),
        entry: entry ?? data.deepCopy(),
        mapSyntax: _mapSyntax,
        mapColor: _mapColor,
        mapColorFav: _mapColorFav,
      );
    }
    _log.finest('Instance is missing syntax maps.');
    return ChCharacter(specs: specs ?? {}, entry: entry ?? data.deepCopy());
  }

  /* ================================================================ */
  /*                              CHINESE                             */
  /* ================================================================ */

  String get numericPinyin {
    final String pinyin = "${data['pinyin']}";
    return _modString.set(pinyin).toNumericPinyin().result;
  }

  String get toneMarkedPinyin {
    final String pinyin = "${data['pinyin']}";
    return _modString.set(pinyin).toToneMarkedPinyin().result;
  }

  String get plainPinyin {
    final String pinyin = "${data['pinyin']}";
    return _modString.set(pinyin).toPlainPinyin().result;
  }

  /* ================================================================ */
  /*                                APP                               */
  /* ================================================================ */

  dynamic images() {
    final rawValue = get(_imageKey);

    if (rawValue == null || !isMapType(rawValue.runtimeType)) {
      return null;
    }

    final targetType = categories[_imageKey];

    if (targetType == null) {
      return null;
    } else if (!isMapType(targetType)) {
      _log.warning('Category for images "$_imageKey" is not a map.');
      return null;
    }

    final mapValue = rawValue as Map<dynamic, dynamic>;
    final converted = convertMapToType(mapValue, targetType);
    return converted;
  }

  List<String> get variants {
    final variantsData = get(_variantKey);
    if (variantsData == null || variantsData is! List) return [];
    final variants = List<String>.from(variantsData);
    final modifier = modify(_variantKey) as TextModifier<List<String>>;
    return modifier.set(variants).findFirstChar('chinese').result;
  }

  List<String> get toUnicode {
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

  List<String> get uniqueWords {
    final String s0 = identifier[0];
    final String s1 = identifier[1];
    final List<String> idWords = s1.isEmpty ? [s0, s0] : [s0, s1];
    return idWords;
  }

  String uniqueID({String method = 'unicode'}) {
    String unique;

    isValid(method, _idMethods, funcName: 'uniqueID', argName: 'method');

    if (method == 'unicode') {
      final List<String> strippedUnicode = [
        for (String c in toUnicode) c.replaceAll('+', ''),
      ];
      unique = "${plainPinyin}_${strippedUnicode.join('_')}";
    } else if (method == 'symbol') {
      final List<String> idWords = uniqueWords;
      unique = "${plainPinyin}_${idWords.join('_')}";
    } else if (method == 'hash') {
      unique = "${plainPinyin}_$hashCodeFormatted";
    } else {
      throw UnimplementedError(
        'uniqueID has not been implemented for method $method".',
      );
    }

    if (unique.startsWith('_')) unique = 'empty_char';

    return unique;
  }
}
