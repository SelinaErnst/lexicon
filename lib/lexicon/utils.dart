import 'package:collection/collection.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

extension StringStripExtension on String {
  String strip(String string) {
    if (isEmpty || string.isEmpty) return this;
    final String escaped = RegExp.escape(string);
    final RegExp leadingPattern = RegExp('^[$escaped]+');
    final RegExp trailingPattern = RegExp('[$escaped]+\$');
    return replaceAll(leadingPattern, '').replaceAll(trailingPattern, '');
  }
}

extension UniversalCollectionContainsExtension on Iterable<dynamic> {
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

extension MapDeepCopy on Map<String, dynamic> {
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

bool isMapType(Type type) {
  final String str = type.toString();
  return type == Map || str == 'Map' || str.contains('Map<');
}

bool isError(Type type) {
  final String str = type.toString();
  return str.contains('Error');
}

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

bool isExactType(Type thisType, dynamic thatType) {
  final String thisTypeStr = thisType.toString().replaceAll('_', '');
  final String thatTypeStr = thatType.toString().replaceAll('_', '');
  return thisTypeStr == thatTypeStr;
}

final Map<Type, Object Function(Map<dynamic, dynamic>)> _mapConverters = {
  Map<String, String>: (source) => Map<String, String>.from(source),
  Map<String, int>: (source) => Map<String, int>.from(source),
  Map<String, List<String>>: (source) => Map<String, List<String>>.from(source),
  Map<String, dynamic>: (source) => Map<String, dynamic>.from(source),
};

final Map<Type, Object Function(List<dynamic>)> _listConverter = {
  List<String>: (source) => List<String>.from(source),
  List<int>: (source) => List<int>.from(source),
  List<dynamic>: (source) => List<dynamic>.from(source),
};

dynamic convertMapToType(Map<dynamic, dynamic> source, Type targetType) {
  final converter = _mapConverters[targetType];
  if (converter != null) {
    return converter(source);
  }

  throw ArgumentError('Unsupported runtime map casting target: $targetType');
}

dynamic convertListToType(List<dynamic> source, Type targetType) {
  final converter = _listConverter[targetType];
  if (converter != null) {
    return converter(source);
  }
}

bool isValid(
  String value,
  Set<String> valid, {
  String funcName = '',
  String argName = '',
}) {
  String description = '';
  if (funcName.isNotEmpty || argName.isNotEmpty) {
    description = ' (func: $funcName, arg: $argName))';
  }
  if (!valid.contains(value)) {
    throw ArgumentError(
      'Invalid value "$value"$description. Must be one of: ${valid.join(', ')}',
    );
  }
  return true;
}

String convertMapToJsonString(Map<String, dynamic> ogMap) {
  final Map<String, dynamic> cleanMap = convertMixedMap(ogMap);
  return jsonEncode(cleanMap);
}

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

Future<Map<String, dynamic>?> readJSON(File file) async {
  try {
    final jsonString = await file.readAsString();
    return jsonDecode(jsonString) as Map<String, dynamic>;
  } catch (e) {
    return null;
  }
}

Map<String, dynamic>? readJSONSync(File file) {
  try {
    final jsonString = file.readAsStringSync();
    return jsonDecode(jsonString) as Map<String, dynamic>;
  } catch (e) {
    return null;
  }
}

bool isMapCompletelyEmpty(Map<String, dynamic> map) {
  if (map.isEmpty) return true;
  for (final value in map.values) {
    if (!_isValueEmpty(value)) {
      return false;
    }
  }
  return true;
}

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
    return MapEntry(key, _convertToPrimitive(value));
  });
}

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
    return _convertToPrimitive(item);
  }).toList();
}

dynamic _convertToPrimitive(dynamic item) {
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

String getDirectory(File file) {
  return p.dirname(file.path);
}

String getFileName(File file) {
  return p.basenameWithoutExtension(file.path);
}

String getExtension(File file) {
  return p.extension(file.path);
}
