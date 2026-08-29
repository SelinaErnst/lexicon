import 'package:collection/collection.dart';
// import 'package:lexicon/lexicon.dart';
import 'package:lexicon/src/errors.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

/* ================================================================ */
/*                            EXTENSIONS                            */
/* ================================================================ */

/// Adds convenience accessors for working with regular expression matches.
extension RegExpMatchAllGroups on RegExpMatch {
  /// Returns all captured groups as a non-nullable list.
  ///
  /// Unmatched groups are represented by an empty string.
  List<String> get allGroups {
    return List.generate(groupCount, (i) => group(i + 1) ?? '');
  }

  /// Returns all captured groups while preserving unmatched groups as `null`.
  List<String?> get allGroupsNullable {
    return groups(List.generate(groupCount, (i) => i + 1));
  }
}

/// Adds string manipulation utilities used throughout the package.
extension StringStripExtension on String {
  /// Removes occurrences of [string] from the beginning and end of the string.
  ///
  /// Returns the original string when either the receiver or [string] is empty.
  String strip(String string) {
    if (isEmpty || string.isEmpty) return this;
    final String escaped = RegExp.escape(string);
    final RegExp leadingPattern = RegExp('^($escaped)+');
    final RegExp trailingPattern = RegExp('($escaped)+\$');
    return replaceAll(leadingPattern, '').replaceAll(trailingPattern, '');
  }

  /// Removes all occurrences of [string] from the beginning of the string.
  String lstrip(String string) {
    if (isEmpty || string.isEmpty) return this;

    final String escaped = RegExp.escape(string);
    final RegExp leadingPattern = RegExp('^($escaped)+');

    return replaceAll(leadingPattern, '');
  }

  /// Removes all occurrences of [string] from the end of the string.
  String rstrip(String string) {
    if (isEmpty || string.isEmpty) return this;

    final String escaped = RegExp.escape(string);
    final RegExp trailingPattern = RegExp('($escaped)+\$');

    return replaceAll(trailingPattern, '');
  }
}

/// Adds title-case conversion to strings.
extension StringTitleExtension on String {
  /// Converts each space-separated word to title case.#
  ///
  /// The first character of each word is converted to uppercase and the
  /// remaining characters are converted to lowercase.
  String title() {
    if (isEmpty) return this;

    return split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }
}

/// Adds collection-aware containment checks to iterables.
extension UniversalCollectionContainsExtension on Iterable<dynamic> {
  /// Checks whether [target] occurs in the iterable.
  ///
  ///  Nested iterables are compared using deep collection equality, while
  /// other values are compared using their normal equality operator.
  bool containsElement(dynamic target) {
    const equality = DeepCollectionEquality();
    return any((element) {
      if (element is Iterable && target is Iterable) {
        return equality.equals(element, target);
      }
      return element == target;
    });
  }
}

/// Adds copying functionality to string-keyed dynamic maps.
extension MapDeepCopy on Map<String, dynamic> {
  /// Creates a copy of the map.
  ///
  /// Nested maps are copied recursively and lists are copied into new list
  /// instances. Other values are retained as references.
  Map<String, dynamic> deepCopy() {
    return map((key, value) {
      if (value is Map<String, dynamic>) {
        return MapEntry(key, value.deepCopy());
      }
      if (value is List) {
        return MapEntry(key, List<dynamic>.from(value));
      }
      return MapEntry(key, value);
    });
  }
}

/// Adds a check for lists whose elements are all strings.
extension ListStringCheck on List<dynamic> {
  /// Whether every element in the list is a [String].
  bool get isAllStrings {
    if (this is List<String>) return true;
    final int len = length;
    for (int i = 0; i < len; i++) {
      if (this[i] is! String) return false;
    }
    return true;
  }
}

/* ================================================================ */
/*                          TYPE COMPARISON                         */
/* ================================================================ */

/// Whether [type] represents a [Map] type, including generic map types.
bool isMapType(Type type) {
  final String str = type.toString();
  return type == Map || str == 'Map' || str.contains('Map<');
}

/// Whether [type] represents a [List] type, including generic list types.
bool isListType(Type type) {
  final String str = type.toString();
  return type == List || str == 'List' || str.contains('List<');
}

/// Whether [type] represents an [Error] type.
bool isError(Type type) {
  final String str = type.toString();
  return str.contains('Error');
}

/// Compares two types by their general collection category.
///
/// Map types are considered equal to other map types, and list types are
/// considered equal to other list types. Non-collection types must match
/// exactly.
bool sameTypes(Type thisType, dynamic thatType) {
  final String thisTypeStr = thisType.toString();
  final String thatTypeStr = thatType.toString();

  if (thatTypeStr.contains('Map')) {
    return thisTypeStr.contains('Map');
  } else if (thatTypeStr.contains('List')) {
    return thisTypeStr.contains('List');
  } else {
    return thisType == thatType;
  }
}

/// Whether [thisType] and [thatType] have the same type representation.
///
/// Private library prefixes are ignored when comparing the types.
bool isExactType(Type thisType, dynamic thatType) {
  final String thisTypeStr = thisType.toString().replaceAll('_', '');
  final String thatTypeStr = thatType.toString().replaceAll('_', '');
  return thisTypeStr == thatTypeStr;
}

/* ================================================================ */
/*                          TYPE CONVERSION                         */
/* ================================================================ */

/// Converts supported map types using their registered type converters.
final Map<Type, Object Function(Map<dynamic, dynamic>)> _mapConverter = {
  Map<String, String>: (source) => Map<String, String>.from(source),
  Map<String, int>: (source) => Map<String, int>.from(source),
  Map<String, List<String>>: (source) => Map<String, List<String>>.from(source),
  Map<String, dynamic>: (source) => Map<String, dynamic>.from(source),
  Map<dynamic, dynamic>: (source) => Map<dynamic, dynamic>.from(source),
  Map<dynamic, String>: (source) => Map<dynamic, String>.from(source),
};

/// Converts supported list types using their registered type converters.
final Map<Type, Object Function(List<dynamic>)> _listConverter = {
  List<String>: (source) => List<String>.from(source),
  List<int>: (source) => List<int>.from(source),
  List<dynamic>: (source) => List<dynamic>.from(source),
  List<Object>: (source) => List<Object>.from(source),
};

/// Maps private runtime collection type names to their corresponding
/// generic collection types.
final Map<String, Type> convertInternalType = {
  for (final type in _listConverter.keys) '_${type.toString()}': type,
  for (final type in _mapConverter.keys) '_${type.toString()}': type,
};

/// Converts [source] to the registered map type [targetType].
///
/// Returns `null` when no converter is registered for [targetType].
dynamic convertMapToType(Map<dynamic, dynamic> source, Type targetType) {
  final converter = _mapConverter[targetType];
  if (converter != null) {
    return converter(source);
  }
  return null;
}

/// Converts [source] to the registered list type [targetType].
///
/// Returns `null` when no converter is registered for [targetType].
dynamic convertListToType(List<dynamic> source, Type targetType) {
  final converter = _listConverter[targetType];
  if (converter != null) {
    return converter(source);
  }
  return null;
}

/// Whether [value] is considered empty.
///
/// `null` and empty strings are considered empty. Maps are empty when they
/// contain no meaningful values, and lists are empty when they contain no
///  meaningful elements.
bool _isValueEmpty(dynamic value) {
  if (value == null) return true;
  if (value is String) return value.trim().isEmpty;
  if (value is Map<String, dynamic>) {
    return isMapCompletelyEmpty(value);
  }
  if (value is List) {
    if (value.isEmpty) return true;
    return value.every((item) => _isValueEmpty(item));
  }
  return false;
}

/// Converts [ogMap] and its supported nested values into a JSON-compatible map.
Map<String, dynamic> convertMixedMap(Map<String, dynamic> ogMap) {
  return ogMap.map((key, value) {
    if (value is List) {
      return MapEntry(key, convertMixedList(value));
    }
    if (value is String || value is num || value is bool || value == null) {
      return MapEntry(key, value);
    }
    if (value is Map<String, dynamic>) {
      return MapEntry(key, convertMixedMap(value));
    }
    return MapEntry(key, convertToPrimitive(value));
  });
}

/// Converts [ogList] and its supported nested values into a JSON-compatible list.
List<dynamic> convertMixedList(List<dynamic> ogList) {
  return ogList.map((item) {
    if (item is String || item is num || item is bool || item == null) {
      return item;
    }
    if (item is List) {
      return convertMixedList(item);
    }
    if (item is Map<String, dynamic>) {
      return convertMixedMap(item);
    }
    return convertToPrimitive(item);
  }).toList();
}

/// Converts [item] to a primitive representation when possible.
///
/// Maps and lists are returned unchanged. Other objects are first converted
/// using `toMapList()` or `toMap()`. If neither conversion succeeds, the
/// object's runtime type is returned as a string.
dynamic convertToPrimitive(dynamic item) {
  if (item is Map || item is List) return item;
  try {
    return item.toMapList();
  } catch (_) {
    try {
      return item.toMap();
    } catch (_) {
      return item.runtimeType.toString();
    }
  }
}

/* ================================================================ */
/*                               CHECK                              */
/* ================================================================ */

/// Validates that [value] is contained in [valid].
///
/// Throws [InvalidArgumentException] when [value] is not one of the
/// permitted values.
///
/// [funcName] and [argName] provide additional context for the error.
bool isValid(
  String value,
  Set<String> valid, {
  String funcName = '',
  String argName = '',
}) {
  if (!valid.contains(value)) {
    throw InvalidArgumentException(
      argName,
      value,
      options: valid,
      function: funcName,
    );
  }

  return true;
}

/// Validates that [value] is present.
///
/// Throws [MissingArgumentException] when [value] is `null`.
///
/// [funcName], [argName], and [valid] provide additional context about
/// the expected argument.
bool isArgument(
  dynamic value,
  Type? valid, {
  String funcName = '',
  String argName = '',
}) {
  if (value == null) {
    throw MissingArgumentException(
      argName,
      function: funcName,
      expected: valid,
    );
  }

  return true;
}

/* ================================================================ */
/*                          READ AND WRITE                          */
/* ================================================================ */

/// Writes each element of [lines] to [file] on a separate line.
///
/// Each element is converted to a string before being written.
Future<void> writeListToFile(List<dynamic> lines, File file) async {
  final IOSink sink = file.openWrite(mode: FileMode.write, encoding: utf8);
  final int len = lines.length;
  for (int i = 0; i < len; i++) {
    sink.write('${lines[i].toString()}\n');
  }
  await sink.flush();
  await sink.close();
}

/// Converts [ogMap] into a JSON string.
///
/// Nested values are converted to JSON-compatible representations before encoding.
String convertMapToJsonString(Map<String, dynamic> ogMap) {
  final Map<String, dynamic> cleanMap = convertMixedMap(ogMap);
  return jsonEncode(cleanMap);
}

/// Converts [ogMap] into JSON and writes it to [file].
///
/// The resulting JSON is formatted with two-space indentation.
Future<void> writeJsonToFile(Map<String, dynamic> ogMap, File file) async {
  final Map<String, dynamic> cleanMap = convertMixedMap(ogMap);
  const encoder = JsonEncoder.withIndent('  ');
  final String jsonString = encoder.convert(cleanMap);
  await file.writeAsString(jsonString);
}

// Future<Map<String, dynamic>?> readJSONL(File file, {Map<String, Type> categories = const {}}) async {
//   try {
//     final lines = await file.readAsLines();
//     for (String line in lines) {
//       if (line.trim().isEmpty) continue;
//       Map<String, dynamic> entry = json.decode(line) as Map<String, dynamic>;
//       Character char = ChCharacter(specs: categories, entry: entry);

//     }
//     return jsonDecode(jsonString) as Map<String, dynamic>;
//   } catch (e) {
//     return null;
//   }
// }

/// Reads and decodes JSON from [file].
///
/// Returns the decoded value when it matches the requested type [T].
/// Throws [Exception] when the decoded data does not match [T] or when
/// the file cannot be read or decoded.
Future<T> readJSON<T>(File file) async {
  dynamic result;
  try {
    final jsonString = await file.readAsString();
    result = jsonDecode(jsonString);
  } catch (e) {
    result = null;
  }
  if (result is T) return result;
  throw Exception('Data is not of type $T');
}

/// Synchronously reads and decodes JSON from [file].
///
/// Returns the decoded value when it matches the requested type [T].
/// Throws [Exception] when the decoded data does not match [T] or when
/// the file cannot be read or decoded.
T readJSONSync<T>(File file) {
  dynamic result;
  try {
    final jsonString = file.readAsStringSync();
    result = jsonDecode(jsonString);
  } catch (e) {
    result = null;
  }
  if (result is T) return result;
  throw Exception('Data is not of type $T');
}

/// Whether [map] contains no meaningful values.
///
/// A map is considered completely empty when it contains no entries or
/// when all of its values are considered empty by [_isValueEmpty].
bool isMapCompletelyEmpty(Map<String, dynamic> map) {
  if (map.isEmpty) return true;
  for (final value in map.values) {
    if (!_isValueEmpty(value)) {
      return false;
    }
  }
  return true;
}

/* ================================================================ */
/*                               FILE                               */
/* ================================================================ */

/// Returns the directory containing [file].
String getDirectory(File file) {
  return p.dirname(file.path);
}

/// Returns the name of [file] without its extension.
String getFileName(File file) {
  return p.basenameWithoutExtension(file.path);
}

/// Returns the extension of [file].
String getExtension(File file) {
  return p.extension(file.path);
}

/* ================================================================ */
/*                              SORTING                             */
/* ================================================================ */

/// Compares [a] and [b] using multiple comparators in sequence.
///
/// Each comparator is used until one returns a non-zero result.
/// When [reverse] is `true`, the comparator arguments are reversed.
/// Returns `0` when all comparators consider the values equal.
int compareMultiple<T>(
  T a,
  T b,
  List<int Function(T a, T b)> comparators, {
  bool reverse = false,
}) {
  for (var compare in comparators) {
    int result;

    if (reverse) {
      result = compare(b, a);
    } else {
      result = compare(a, b);
    }

    if (result != 0) {
      return result;
    }
  }

  return 0;
}
