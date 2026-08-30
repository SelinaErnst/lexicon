import 'package:logging/logging.dart';
import 'package:collection/collection.dart';
import 'dart:convert';
import 'dart:io';
import 'text_modifier.dart';
import 'template_renderer.dart';
import 'character.dart';
import 'rule.dart';
import 'utils.dart';
import 'dictionary.dart';
import 'errors.dart';
import 'package:path/path.dart' as p;

final Logger _log = Logger('DictionaryIOLog');

/// Maps file extensions to their accepted format aliases.
const Map<String, Set<String>> _extOptions = {
  '.txt': {'pleco', 'txt', '.txt', 'all'},
  '.jsonl': {'chd', 'jsonl', '.jsonl', 'all'},
  '.db': {'db', '.db', 'sql', 'base', 'all'},
};

/// Contains all valid export format aliases.
final Set<String> _expOptions = _extOptions.values.expand((set) => set).toSet();

/// Resolves a format alias to its canonical file extension.
///
/// Returns the matching extension from [extOpt], or `null` when [choice]
/// is `null` or no matching alias exists.
String? getExt(
  String? choice, {
  Map<String, Set<String>> extOpt = _extOptions,
}) {
  if (choice == null) return null;

  final matchEntry = extOpt.entries.firstWhereOrNull(
    (entry) => entry.value.contains(choice),
  );

  return matchEntry?.key;
}

/// File import output
extension DictionaryIO<C extends Character, R extends Rule>
    on Dictionary<C, R> {
  /* ================================================================ */
  /*                               READ                               */
  /* ================================================================ */

  /// Checks whether [file] exists before performing a synchronous read.
  ///
  /// Throws [FileNotFoundException] if [file] does not exist.
  void readSync(
    File file, {
    bool add = true,
    Map<String, dynamic>? categories,
    String? format,
    String? name,
    String? template,
  }) {
    if (!file.existsSync()) {
      _log.shout('Dictionary file does not exist.');
      throw FileNotFoundException(file.path);
    }
    throw UnimplementedFeatureException('readSync');
  }

  /// Reads a category schema from [file] and applies it to the dictionary.
  Future<void> readCategories(File file) async {
    final fileCategories = await readJSON<Map<String, dynamic>>(file);
    // print(fileCategories);
    categories = fileCategories;
  }

  /// Reads rules from a line-delimited JSON file.
  ///
  /// When [add] is `false`, existing rules are removed before importing
  /// the new rules.
  ///
  /// Throws [[UnsupportedFileFormatException]] if [file] does not use the `.jsonl` extension,
  /// [[FileNotFoundException]] if the target file does not exist, or [FormatException]
  /// if the file cannot be processed.
  Future<void> readRules(File file, {bool add = false}) async {
    final String directory = getDirectory(file);
    final String filename = getFileName(file);
    final String ext = getExtension(file);

    if (ext != '.jsonl') {
      throw UnsupportedFileFormatException(ext);
    }
    File targetFile = File(p.join(directory, '$filename$ext'));
    if (!targetFile.existsSync()) {
      _log.shout('File does not exist.');
      throw FileNotFoundException(targetFile.path);
    }

    final bool success = await _readJSONL(targetFile, add: add, type: Rule);
    if (success == false) {
      _log.shout('Unsuccessful attempt at reading file to dictionary rules.');
      throw DictionaryParseException(targetFile.path);
    }
  }

  /// Reads dictionary data from the specified file.
  ///
  /// The file format is determined from its extension. Supported formats are
  /// text files, line-delimited JSON files, and database files.
  ///
  /// When [categories] is provided, it replaces the current category schema.
  /// When [add] is `false`, existing characters are replaced by the imported
  /// data.
  ///
  /// Throws [UnsupportedFileFormatException] if the requested format is unsupported,
  /// [FileNotFoundException] if the target file does not exist, or [DictionaryParseException]
  /// if the data cannot be processed.
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
      throw UnsupportedFileFormatException(fileFormat.toString());
    }

    File targetFile = File(p.join(directory, '$filename$fileFormat'));
    if (!targetFile.existsSync()) {
      _log.shout('File does not exist.');
      throw FileNotFoundException(targetFile.path);
    }

    final success = switch (fileFormat) {
      '.txt' => await () async {
        return await _readTXT(targetFile, template: template ?? '', add: add);
      }(),
      '.jsonl' => await _readJSONL(targetFile, add: add, type: Character),
      '.db' => await () async {
        return await _readDB(targetFile, name: name, add: add);
      }(),
      _ => false,
    };
    if (success == false) {
      _log.shout('Unsuccessful attempt at reading file to dictionary.');
      throw DictionaryParseException(targetFile.path);
    }
  }

  /// Streams and processes line-delimited JSON files.
  ///
  /// Routes parsed dictionary maps cleanly into [_addRule] or [_addCharacter] based
  /// on the defined runtime target [type]. Strips out structural empty lines or
  /// trailing spacing without string mutations to optimize loop efficiency.
  /// Reads and processes a line-delimited JSON file.
  ///
  /// Each decoded entry is passed to [_addRule] or [_addCharacter] according
  /// to [type]. When [add] is `false`, the existing collection is cleared.
  /// Returns `true` when processing succeeds and `false` when an error occurs.
  Future<bool> _readJSONL(
    File file, {
    bool add = true,
    Type type = Character,
  }) async {
    _log.fine('Read .jsonl file.');
    try {
      if (!add && type == Rule) emptyRules();
      if (!add && type == Character) emptyCharacters();
      // final List<Character> jsonlCharacters = [];
      // final

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
        if (type == Rule) {
          // _log.warning([type, type == Rule, entry]);
          addRule(entry);
        } else if (type == Character) {
          addCharacter(entry);
        }
      }
      reorder();
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Parser implementation for reading .txt dictionary files.
  Future<bool> _readTXT(
    File file, {
    String template = '',
    bool add = true,
  }) async {
    _log.fine('Read .txt file.');
    // throw UnimplementedFeatureException('_readTXT');
    return false;
  }

  /// Parser implementation for reading SQLite or database (.db) files.
  Future<bool> _readDB(File file, {String? name, bool add = true}) async {
    _log.fine('Read .db file.');
    // throw UnimplementedFeatureException('_readDB');
    return false;
  }

  /* ================================================================ */
  /*                               WRITE                              */
  /* ================================================================ */

  /// Writes the dictionary to the file format specified by [file] or [format].
  ///
  /// The supported formats are text (`.txt`), line-delimited JSON (`.jsonl`),
  /// and database (`.db`). When the file name contains an extension, that
  /// extension takes precedence over [format].
  ///
  /// For text output, [template] and [mod] are required. [categories] can be
  /// used to select the categories included in the output.
  ///
  /// Throws [UnsupportedFileFormatException] if the requested format is not
  /// supported. Throws [InvalidDictionaryDataException] if required arguments
  /// for a selected format are invalid. Throws [DictionaryWriteException] if
  /// writing the dictionary fails.
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
      throw DictionaryWriteException(targetFile.path);
    }
  }

  /// Exporters processing internal dictionary layouts into templated raw plain text formats.
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

  /// Streams and serializes managed character models down into lines of raw JSON tracking strings.
  Future<bool> _toJSONL(File file) async {
    _log.fine('Write to .jsonl file.');

    final lines = characters.map((char) => char.toMap()).toList();
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

  /// Exporters converting dictionary datasets down into database storage connections.
  Future<bool> _toDB(File file, {bool overwrite = true}) async {
    _log.fine('Write to .db file.');
    // throw UnimplementedFeatureException('_toDB');
    return false;
  }
}
