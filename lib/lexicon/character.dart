import 'package:logging/logging.dart';
import 'package:meta/meta.dart';
import 'package:collection/collection.dart';
import 'text_modifier.dart';
import 'utils.dart';
import 'dictionary.dart';

final Logger _log = Logger('CharacterEngine');

/* ================================================================ */
/*                           CONFIGURATION                          */
/* ================================================================ */

final Set<String> _idMethods = {
  'unicode',
  'symbol',
  'hash',
}; // uniqueID : method

/* ================================================================ */
/*                          IMPLEMENTATION                          */
/* ================================================================ */

class Character {
  final Map<String, Type> categories;
  final Map<String, dynamic> data = {};

  final TextModifier _modString = TextModifier<String>('');
  final TextModifier _modList = TextModifier<List<String>>(['']);

  List<String> get _identifiers {
    if (categories.isNotEmpty) return categories.keys.toList();
    return [];
  }

  void setSyntax(
    Map<String, dynamic> mapSyntax,
    Map<String, dynamic> mapColor, {
    Map<String, dynamic>? mapColorFav,
  }) {
    _modString.addAction(mapSyntax, mapColor, mapColorFav: mapColorFav);
  }

  /* ================================================================ */
  /*                            CONSTRUCTOR                           */
  /* ================================================================ */

  Character({
    Map<String, Type> specs = const {},
    Map<String, dynamic> entry = const {},
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) : categories = {} {
    if (mapColor != null && mapSyntax != null) {
      setSyntax(mapSyntax, mapColor, mapColorFav: mapColorFav);
    }

    categories.addAll({for (final category in _identifiers) category: String});
    categories.addAll(specs);
    categories.forEach((category, type) {
      if (_identifiers.contains(category)) {
        data[category] = '';
      } else {
        data[category] = null;
      }
    });

    entry.forEach((category, value) {
      set(category, value);
    });

    for (final idKey in _identifiers) {
      final value = data[idKey];
      if (value == null) {
        _log.severe(
          'Integrity Breach: Core identifier "$idKey" cannot be missing or empty!',
        );
        throw ArgumentError(
          'Mandatory field missing: Each character entry requires a valid $idKey string.',
        );
      }
    }

    _log.info('Initial character: ${toString()}');
  }

  /* ––––––––––––––––––––––––––––– copy ––––––––––––––––––––––––––––– */

  @protected
  Character createInstance({
    Map<String, Type>? specs,
    Map<String, dynamic>? entry,
  }) {
    return Character(specs: specs ?? {}, entry: entry ?? {});
  }

  Character copy() {
    return createInstance(
      specs: Map<String, Type>.from(categories),
      entry: data.deepCopy(),
    );
  }

  Character copyWith({Map<String, Type>? specs, Map<String, dynamic>? entry}) {
    return createInstance(
      specs: specs ?? Map<String, Type>.from(categories),
      entry: entry == null ? data.deepCopy() : (data.deepCopy()..addAll(entry)),
    );
  }

  /* ================================================================ */
  /*                           BASIC METHODS                          */
  /* ================================================================ */

  /* –––––––––––––––––––– operator (magic method) ––––––––––––––––––– */
  Dictionary operator +(dynamic other) {
    final comboCategories = Map<String, Type>.from(categories);
    final List<Character> comboCharacters = [copy()];

    if (other is Character && !other.isEmpty && this != other) {
      comboCharacters.add(other.copy());
    } else if (other is Dictionary) {
      return other.copyWith(categories: comboCategories) + this;
    } else {
      _log.warning('Addition Ignored: Unsupported type ${other.runtimeType}');
    }
    return Dictionary(categories: comboCategories, characters: comboCharacters);
  }

  dynamic operator [](String category) {
    // different from get which can return null instead of error
    if (!categories.containsKey(category)) {
      throw ArgumentError('Category "$category" does not exist.');
    }
    return data[category];
  }

  void operator []=(String category, dynamic value) {
    set(category, value);
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
    List<String> values = [for (String i in _identifiers) data[i] as String];
    String repr = values.join(' | ');
    return '〔 $repr 〕';
  }

  Map<String, dynamic> toMap() {
    return convertMixedMap(data);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! Character) return false;
    return const ListEquality<String>().equals(identifier, other.identifier);
  }

  /* –––––––––––––––––––––––––––– compare ––––––––––––––––––––––––––– */

  bool exact(Character other, {bool ignoreNull = false}) {
    if (this != other) return false;
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
    for (String i in _identifiers) data[i] as String,
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
          final MapEntry item = items[idx];
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

    if (!categories.containsKey(category)) {
      _log.severe('Validation Failure: Category "$category" does not exist.');
      value = null;
      if (!force) throw ArgumentError('Category "$category" does not exist');
    } else {
      final targetType = categories[category]!;
      if (isMapType(value.runtimeType) && isMapType(targetType)) {
        final mapValue = value as Map<dynamic, dynamic>;
        value = convertMapToType(mapValue, targetType);
        data[category] = value;
        _log.finer('Successfully updated category "$category"');
      }

      if (!sameTypes(value.runtimeType, targetType) && value != null) {
        _log.severe(
          'Type Mismatch for "$category": Expected $targetType, got ${value.runtimeType}',
        );
        value = data[category];
        if (!force) throw TypeError();
      }
      data[category] = value;
      _log.finer('Successfully updated category "$category"');
    }
  }

  void remove(String category) {
    if (!categories.containsKey(category)) {
      _log.warning('Remove Ignored: category "$category" does not exist.');
      return;
    }
    if (_identifiers.contains(category)) {
      data[category] = '';
      _log.finer('Reset identifier value for "$category" to empty string.');
    } else {
      data[category] = null;
      _log.finer('Reset optional value for "$category" to null.');
    }
  }

  dynamic get(String category) {
    if (!categories.containsKey(category)) {
      _log.warning('Get Ignored: category "$category" does not exist.');
      return null; // Return null instead of crashing if a field doesn't exist
    }
    return data[category];
  }

  Character update(Map<String, dynamic> entry) {
    entry.forEach((category, value) {
      try {
        set(category, value);
      } catch (e) {
        // _log.warning('Type conversion or assignment failure on key "$category"');
      }
    });
    return this;
  }

  void updateCategoryMap(String category, Map<String, dynamic>? updates) {
    if (!categories.containsKey(category)) {
      throw ArgumentError('Category "$category" does not exist.');
    }
    if (!isMapType(categories[category]!)) {
      throw ArgumentError(
        'Category "$category" is registered as ${categories[category]}, not a Map.',
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
}

class ChCharacter extends Character {
  final String _imageKey = 'images';
  final String _variantKey = 'variants';

  @override
  List<String> get _identifiers => const [
    'simplified',
    'traditional',
    'pinyin',
  ];
  List<String> get baseCategories => _identifiers;

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
    }
    if ((category == 'simplified' || category == 'traditional') &&
        value is String) {
      value = _modString.set(value).toCleanLanguage('chinese').result;
    }
    super.set(category, value, force: force);
  }

  @override
  ChCharacter createInstance({
    Map<String, Type>? specs,
    Map<String, dynamic>? entry,
  }) {
    return ChCharacter(specs: specs ?? {}, entry: entry ?? {});
  }

  @override
  ChCharacter copy() => super.copy() as ChCharacter;

  @override
  ChCharacter copyWith({
    Map<String, Type>? specs,
    Map<String, dynamic>? entry,
  }) => super.copyWith(specs: specs, entry: entry) as ChCharacter;

  /* ================================================================ */
  /*                              CHINESE                             */
  /* ================================================================ */

  String get numericPinyin {
    final pinyin = data['pinyin'] as String;
    return _modString.set(pinyin).toNumericPinyin().result as String;
  }

  String get toneMarkedPinyin {
    final pinyin = data['pinyin'] as String;
    return _modString.set(pinyin).toToneMarkedPinyin().result as String;
  }

  String get plainPinyin {
    final pinyin = data['pinyin'] as String;
    return _modString.set(pinyin).toPlainPinyin().result as String;
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
    if (variantsData == null || variantsData is! List) {
      return [];
    }
    final variants =
        _modList.set(variantsData).findFirstChar('chinese').result
            as List<String>;
    // if (variants == null) return [];
    // if (variants is String) return [variants];
    // if (variants is List) return List<String>.from(variants);
    // return [];
    return variants;
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
      unique = '$hashCode';
    }

    if (unique.startsWith('_')) unique = 'empty_char';

    return unique;
  }
}
