// ignore_for_file: unnecessary_string_escapes

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
    bool? strict,
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

  @override
  T relax() => createInstance(strict: false);

  @override
  T restrict() => createInstance(strict: true);
}

/* ================================================================ */
/*                          IMPLEMENTATION                          */
/* ================================================================ */

class Character {
  late final Map<String, Type> categories;
  final Map<String, dynamic> data = {};
  final bool strict;

  final TextModifier<String> _modString = TextModifier('');
  final TextModifier<List<String>> _modListStr = TextModifier(['']);

  Map<String, dynamic>? mapSyntax;
  Map<String, dynamic>? mapColor;
  Map<String, dynamic>? mapColorFav;

  final List<String> baseCategories;

  // List<String> get baseCategories => _identifiers;

  /* ================================================================ */
  /*                            CONSTRUCTOR                           */
  /* ================================================================ */

  Character({
    Map<String, Type> specs = const {},
    Map<String, dynamic> entry = const {},
    this.strict = true, // default for all subclasses
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
      for (final entry in specs.entries)
        if (!this.baseCategories.contains(entry.key)) entry.key: entry.value,
    });

    if (strict) {
      categories = Map.unmodifiable(finalCategories);
    } else {
      categories = finalCategories;
    }

    finalCategories.forEach((category, type) {
      _modifyCategory(null, category);
    });

    entry.forEach((category, value) {
      set(category, value);
    });

    for (final idKey in this.baseCategories) {
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

  /* ================================================================ */
  /*                               COPY                               */
  /* ================================================================ */

  Character createInstance({
    Map<String, Type>? specs,
    Map<String, dynamic>? entry,
    List<String>? baseCategories,
    bool? strict,
  }) {
    _log.finer('Create instance of Character with different entry.');
    if (!hasSyntax) {
      _log.finest('Instance is missing syntax maps.');
    }
    return Character(
      specs: specs ?? Map<String, Type>.from(categories),
      entry: entry ?? data.deepCopy(),
      strict: strict ?? this.strict,
      baseCategories: baseCategories ?? this.baseCategories,
      mapSyntax: mapSyntax,
      mapColor: mapColor,
      mapColorFav: mapColorFav,
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

  Character relax() {
    return createInstance(strict: false);
  }

  Character restrict() {
    return createInstance(strict: true);
  }

  /* ================================================================ */
  /*                           BASIC METHODS                          */
  /* ================================================================ */

  Dictionary operator +(dynamic other) {
    _log.fine('Addition of Character and ${other.runtimeType}.');
    final comboCategories = Map<String, Type>.from(categories);
    final List<Character> comboCharacters = [createInstance()];

    if (other is Character) {
      if (other.isNotEmpty && this != other) {
        comboCharacters.add(other.createInstance());
      }
    } else if (other is Dictionary) {
      // print( other.reconfigure(categories: comboCategories));
      // return other + this;
      return other.reconfigure(categories: comboCategories) + this;
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
    if (!data.containsKey(category)) {
      _log.shout('Category "$category" does not exist.');
      throw ArgumentError('Category "$category" does not exist.');
    }
    return data[category];
  }

  void operator []=(String category, dynamic value) {
    set(category, value, force: false);
  }

  @override
  bool operator ==(Object other) {
    _log.finest('Compare Character ${toString()} to ${other.toString()}');
    if (identical(this, other)) return true;
    if (other is! Character) return false;
    return const ListEquality<String>().equals(identifier, other.identifier);
  }

  @override
  int get hashCode => const ListEquality<String>().hash(identifier);

  String get hashCodeFormatted {
    return _formatHashCode(hashCode);
  }

  String _formatHashCode(int hash) {
    return hash.toString().padLeft(10, '0');
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

  bool get isEmpty => identifier.every((slot) => slot.isEmpty);

  bool get isNotEmpty => !isEmpty;

  /* ================================================================ */
  /*                        DATA AND CATEGORIES                       */
  /* ================================================================ */

  List<String> get identifier => [
    for (String i in baseCategories) data[i].toString(),
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

  void info() {
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

    print(buffer.toString());
  }

  /* ================================================================ */
  /*                                GET                               */
  /* ================================================================ */

  dynamic get(String category) {
    _log.finer('Lookup value of category $category.');
    if (!categories.containsKey(category)) {
      _log.warning('Lookup Ignored: category "$category" does not exist.');
      return null; // Return null instead of crashing if a field doesn't exist
    }
    return data[category];
  }

  /* ================================================================ */
  /*                           SET / UPDATE                           */
  /* ================================================================ */

  void _modifyCategory(dynamic result, String category) {
    if (baseCategories.contains(category) && result == null) {
      result = "";
    }
    if (categories.containsKey(category)) {
      data[category] = result;
    }
  }

  void set(String category, dynamic value, {bool force = true}) {
    // force will turn off the envorcement for correct categories (with Errors)
    _log.finest('Set value of category. ($category : $value)');

    if (!categories.containsKey(category) && strict) {
      value = null;
      _log.severe('Ignore Set: Category "$category" does not exist.');
      if (!force) throw ArgumentError('Category "$category" does not exist');
    } else {
      final Type targetType;
      if (value == null) {
        return _modifyCategory(null, category);
      }
      if (!strict) {
        // targetType = dynamic;
        targetType = value.runtimeType;
        categories[category] = targetType;
      } else {
        targetType = categories[category] ?? Null;
      }

      if (isMapType(value.runtimeType) && isMapType(targetType)) {
        return _modifyCategory(
          convertMapToType(value as Map<dynamic, dynamic>, targetType),
          category,
        );
      }

      if (!sameTypes(value.runtimeType, targetType) && strict) {
        _log.severe(
          'Ignore Set: Type Mismatch for "$category". Expected $targetType, got ${value.runtimeType}.',
        );
        if (!force) throw TypeError();
        return;
      }

      return _modifyCategory(value, category);
    }
  }

  void remove(String category) {
    _log.finer('Remove category "$category" from Character $toString()');
    if (!categories.containsKey(category)) {
      _log.warning('Remove Ignored: category "$category" does not exist.');
      return;
    }
    set(category, null);
  }

  void update(Map<String, dynamic> entry, {bool merge = false}) {
    _log.fine('Update data of Character ${toString()}');
    _log.finest('with categories: ${entry.keys.toList().join(", ")}');
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
  /*                              SYNTAX                              */
  /* ================================================================ */

  bool get hasSyntax => mapColor != null && mapSyntax != null;

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
    _log.info('Successfully defined syntax for Character ${toString()}.');
  }

  /* ================================================================ */
  /*                              MODIFY                              */
  /* ================================================================ */

  TextModifier modifier(Type type, dynamic input) {
    if (type == String && input is String) {
      return _modString.set(input);
    } else if (isListType(type) && input is List<String>) {
      return _modListStr.set(List<String>.from(input));
    } else if (input is Map<String,String>) {
      return TextModifier(input);
    } else if (input != null) {
      return TextModifier(input as Object);
    } else {
      throw ArgumentError(
        'Cannot get TextModifier due to incorrect input type: $type.',
      );
    }
  }

  TextModifier modify(String category, {bool transform = true}) {
    _log.fine(
      'Create TextModifier for category "$category" of Type ${get(category).runtimeType}.',
    );

    final input = get(category);
    final TextModifier mod;
    if (input is String) {
      mod = modifier(String, input);
    } else if (input is List<String>) {
      mod = modifier(List<String>, input);
    } else {
      mod = modifier(input.runtimeType, input);
    }
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

  @override
  ChCharacter createInstance({
    Map<String, dynamic>? entry,
    Map<String, Type>? specs,
    List<String>? baseCategories,
    bool? strict,
  }) {
    _log.finer('Create instance of Character with different entry.');
    if (baseCategories != null) {
      _log.finest('Cannot change baseCategories of ChCharacter.');
    }
    if (!hasSyntax) {
      _log.finest('Instance is missing syntax maps.');
    }
    return ChCharacter(
      entry: entry ?? data.deepCopy(),
      specs: specs ?? Map<String, Type>.from(categories),
      mapSyntax: mapSyntax,
      mapColor: mapColor,
      mapColorFav: mapColorFav,
    );
    // return ChCharacter(specs: specs ?? {}, entry: entry ?? data.deepCopy());
  }

  /* ================================================================ */
  /*                           SET CATEGORY                           */
  /* ================================================================ */

  @override
  void set(String category, value, {bool force = true}) {
    if (category == 'pinyin' && value is String) {
      value = modifier(String, value).toNumericPinyin().result;
      _log.finer('Convert pinyin to numeric style.');
    }
    if ((category == 'simplified' || category == 'traditional') &&
        value is String) {
      value = modifier(String, value).toCleanLanguage('chinese').result;
      _log.finer('Cleanup chinese character symbols.');
    }
    super.set(category, value, force: force);
  }

  /* ================================================================ */
  /*                            CATEGORIES                            */
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
    final mod = modifier(List<String>, variants) as TextModifier<List<String>>;
    return mod.findFirstChar('chinese').result;
  }

  /* ================================================================ */
  /*                              UNIQUE                              */
  /* ================================================================ */

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
        for (String c in _toUnicode) c.replaceAll('+', ''),
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

  /* ================================================================ */
  /*                              CHINESE                             */
  /* ================================================================ */

  String get numericPinyin {
    final mod = modifier(String, get('pinyin')) as TextModifier<String>;
    return mod.toNumericPinyin().result;
  }

  String get toneMarkedPinyin {
    final mod = modifier(String, get('pinyin')) as TextModifier<String>;
    return mod.toToneMarkedPinyin().result;
  }

  String get plainPinyin {
    final mod = modifier(String, get('pinyin')) as TextModifier<String>;
    return mod.toPlainPinyin().result;
  }
}
