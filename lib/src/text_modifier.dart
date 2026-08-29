import 'utils.dart';
import 'package:logging/logging.dart';
import 'package:lexicon/src/errors.dart';

final Logger _log = Logger('TextModifierLog');

/// Provides chained text processing and syntax formatting operations.
///
/// Supports strings, lists, and maps. String values contained within lists
/// and maps are processed individually, while non-string values are preserved
/// unchanged.
///
/// Processing operations update [result] and return the modifier instance
/// to allow multiple transformations to be chained.
class TextModifier<T> {
  /// The original input supplied to this modifier.
  T _input;

  /// Returns the original input supplied to this modifier.
  T get input => _input;

  /// The current value produced by the modification chain.
  late T result;

  /// The fully resolved syntax command currently applied.
  String _fullCommand;

  /// The resolved color value currently applied.
  String _colorVal;

  /// Returns the currently resolved color value.
  String get color => _colorVal;

  /// Reusable string modifier used for nested string operations.
  TextModifier<String>? _actString;

  /// Optional callback invoked after a processing operation produces a result.
  void Function(dynamic result)? transform;

  /// Syntax definitions used by syntax formatting operations.
  Map<String, dynamic>? mapSyntax;

  /// Color definitions used by syntax formatting operations.
  Map<String, dynamic>? mapColor;

  /// Favorite color aliases used by syntax formatting operations.
  Map<String, dynamic>? mapColorFav;

  /// Regular expression patterns used to identify character types.
  static final Map<String, RegExp> _patterns = {
    'chinese': RegExp('([$isChineseChar]+)', unicode: true),
    'notChinese': RegExp('([^$isChineseChar]+)', unicode: true),
    'english': RegExp(r'([a-zA-Z]+)'),
    'any': RegExp(
      '([\\w|$unassignedExtensions|$isChineseChar])',
      unicode: true,
    ),
  };

  /* ================================================================ */
  /*                            CONSTRUCTOR                           */
  /* ================================================================ */

  /// Creates a text modifier for [input].
  ///
  /// Syntax and color configuration can be supplied directly or inherited
  /// from another [mod] instance.
  TextModifier(
    this._input, {
    this.transform,
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
    TextModifier<dynamic>? mod,
  }) : _colorVal = '',
       _fullCommand = _defaultCommand {
    result = _copyInput(input);
    if (mod != null) {
      addSyntax(
        mapSyntax: mod.mapSyntax,
        mapColor: mod.mapColor,
        mapColorFav: mod.mapColorFav,
      );
    } else {
      addSyntax(
        mapSyntax: mapSyntax,
        mapColor: mapColor,
        mapColorFav: mapColorFav,
      );
    }
  }

  /// Creates an independent copy of [input] suitable for use as [result].
  ///
  /// Lists and maps are converted to the appropriate generic type when a
  /// matching converter is available. For dynamic modifiers, internal runtime
  /// collection types are resolved to their corresponding public types before
  /// conversion.
  ///
  /// Values that do not require collection conversion are returned unchanged.
  T _copyInput(T input) {
    Type targetType;
    if (T == dynamic) {
      String internalType = input.runtimeType.toString();
      if (internalType.startsWith('_')) {
        targetType = convertInternalType[internalType] ?? dynamic;
      } else {
        targetType = input.runtimeType;
      }
    } else {
      targetType = T;
    }

    if (input is List) {
      final converted = convertListToType(input, targetType);
      if (converted != null) return converted as T;
      _log.warning('Input List was not copied to $targetType.');
    } else if (input is Map) {
      final converted = convertMapToType(input, targetType);
      if (converted != null) return converted as T;
      _log.warning('Input Map was not copied to $targetType.');
    }
    _log.finer('Input of type ${input.runtimeType} was not copied');
    return input;
  }

  /// Creates a new modifier using the supplied values or the current
  /// modifier's input, transformation callback, and syntax configuration.
  TextModifier<T> copyWith({
    T? input,
    void Function(dynamic result)? transform,
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) {
    final mod = TextModifier(
      input ?? _input,
      transform: transform ?? this.transform,
    );
    if (mapSyntax != null || mapColor != null) {
      mod.addSyntax(
        mapSyntax: mapSyntax,
        mapColor: mapColor,
        mapColorFav: mapColorFav,
      );
    }
    return mod;
  }

  /// Replaces the current input and resets [result] to that value.
  ///
  /// Optionally updates the active [command] and [color].
  TextModifier<T> set(dynamic input, {String? command, String? color}) {
    if (input is! T) {
      _log.shout('input for TextModifier<$T> cannot be ${input.runtimeType}');
      throw InvalidModifierInputException(
        actual: input.runtimeType,
        expected: T,
      );
    } else {
      _input = input;
      result = _copyInput(input);
    }
    if (command != null) {
      _fullCommand = getFullCommand(command) ?? _defaultCommand;
    }
    if (color != null) {
      _colorVal = getColor(color) ?? _defaultColor;
    }
    return this;
  }

  /// Passes a processed result to the configured [transform] callback.
  void transformResult() {
    if (transform != null) {
      transform!(result);
    }
  }

  /// Creates a string-specific modifier instance.
  TextModifier<String> createInstance(String text) {
    return TextModifier<String>(text);
  }

  /// Assigns syntax and color configurations to this modifier.
  void addSyntax({
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) {
    this.mapSyntax = mapSyntax;
    this.mapColor = mapColor;
    this.mapColorFav = mapColorFav;
    // _actString?.addSyntax(
    //   mapSyntax: this.mapSyntax,
    //   mapColor: this.mapColor,
    //   mapColorFav: this.mapColorFav,
    // );
  }

  /// Throws [SyntaxNotConfiguredException] when syntax configuration
  /// has not been assigned.
  void _warnMissingSyntax() {
    if (!hasSyntax) {
      _log.shout('Syntax has not been added yet.');
      throw SyntaxNotConfiguredException();
    }
  }

  /// Whether syntax and color configurations are available.
  bool get hasSyntax => mapColor != null && mapSyntax != null;

  /// Returns a reusable string modifier carrying this modifier's
  /// syntax configuration and current command settings.
  TextModifier<String> get actString {
    final modString = _actString ?? TextModifier<String>('');
    if (!modString.hasSyntax) {
      modString.addSyntax(
        mapColor: mapColor,
        mapSyntax: mapSyntax,
        mapColorFav: mapColorFav,
      );
    }
    modString.set('', command: command, color: color);
    return modString;
  }

  /* ================================================================ */
  /*                         STRING PROCESSING                        */
  /* ================================================================ */

  /// Applies [worker] to the current [result].
  ///
  /// Strings are transformed directly. String values contained in maps and
  /// string elements contained in lists are transformed individually.
  /// Non-string values are preserved unchanged.
  ///
  /// When [ignoreEmpty] is true, processed string values that become empty
  /// are removed from their containing map or list.
  ///
  /// The processed value is stored in [result], and [transformResult] is
  /// invoked after processing.
  ///
  /// Returns the current [result].
  T _process(String Function(String) worker, {bool ignoreEmpty = true}) {
    _log.finest('Process input of type ${result.runtimeType}');
    if (result == null) {
      return result;
    }
    if (result is String) {
      result = worker(result as String) as T;
    } else if (result is Map) {
      final map = result as Map;
      for (final key in map.keys.toList()) {
        final value = map[key];

        if (value is String) {
          final processed = worker(value);

          if (!ignoreEmpty || processed.trim().isNotEmpty) {
            map[key] = processed;
          } else {
            map.remove(key);
          }
        }
      }
    } else if (result is List) {
      final list = result as List;
      for (int i = list.length - 1; i >= 0; i--) {
        final value = list[i];

        if (value is String) {
          final String processed = worker(value);

          if (!ignoreEmpty || processed.trim().isNotEmpty) {
            list[i] = processed;
          } else {
            list.removeAt(i);
          }
        }
      }
    }
    transformResult();
    return result;
  }

  /// Applies [onMatch] to every occurrence matching [pattern].
  ///
  /// The replacement function receives each [Match] and determines the
  /// resulting text for that occurrence.
  TextModifier<T> modifyPattern(
    RegExp pattern,
    String Function(Match match) onMatch, {
    bool ignoreEmpty = false,
  }) {
    _process((text) {
      return text.replaceAllMapped(pattern, onMatch);
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /* –––––––––––––––––––––– string manipulation ––––––––––––––––––––– */

  /// Removes occurrences of " " from the current result.
  TextModifier<T> trim({bool ignoreEmpty = true}) {
    _process((text) {
      return text.trim();
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Removes occurrences of [pattern] from the current result.
  TextModifier<T> strip(String pattern, {bool ignoreEmpty = true}) {
    _process((text) {
      return text.strip(pattern);
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Replaces every occurrence matching [pattern] with [replacement].
  TextModifier<T> replaceAll(
    String pattern,
    String replacement, {
    bool ignoreEmpty = false,
  }) {
    return modifyPattern(RegExp(pattern), (match) => replacement);
  }

  /* ––––––––––––––––––––––––––––– regex –––––––––––––––––––––––––––– */

  /// Removes configured Pleco syntax markers from the current result.
  TextModifier<T> removeSyntax({bool ignoreEmpty = false}) {
    _process((text) {
      return text.replaceAll(rPleco, '');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Cleans a name into a normalized identifier containing only
  /// letters, numbers, and underscores.
  TextModifier<T> cleanName({bool ignoreEmpty = true}) {
    _process((text) {
      String goodName = text.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
      goodName = goodName.replaceAll(RegExp(r'_+'), '_');
      goodName = goodName == "_" ? "" : goodName;
      return goodName;
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Converts text into a normalized link representation.
  TextModifier<T> toCleanLink({bool ignoreEmpty = true}) {
    _process((text) {
      return text
          .replaceAll(rPunctuation, '')
          .replaceAll('_', '＿')
          .replaceAll('…', '＿')
          .replaceAll(' ', '')
          .strip('＿');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Converts text into a normalized reference representation.
  TextModifier<T> toCleanRef({bool ignoreEmpty = true}) {
    _process((text) {
      return text
          // .replaceAll(rPunctuation, '')
          .replaceAll('_', '＿')
          .replaceAll('…', '＿')
          .replaceAll(' ', '');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Converts punctuation between the supported language conventions.
  TextModifier<T> toCleanLanguage(String language, {bool ignoreEmpty = false}) {
    isValid(
      language,
      {'chinese', 'english', 'german'},
      argName: 'language',
      funcName: 'toSentence',
    );
    _process((sentence) {
      String processed = sentence;
      for (var entry in _punctuationMap.entries) {
        if (language == 'chinese') {
          processed = processed.replaceAll(entry.key, entry.value);
        } else {
          processed = processed.replaceAll(entry.value, entry.key);
        }
      }

      return processed;
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Extracts the first substring matching the requested character type.
  TextModifier<T> findFirstChar(String type, {bool ignoreEmpty = true}) {
    isValid(
      type,
      _patterns.keys.toSet(),
      funcName: 'findFirstChar',
      argName: 'type',
    );

    _process((text) {
      final pattern = _patterns[type];
      if (pattern == null) {
        return '';
      }
      final matches = pattern.allMatches(text);
      if (matches.isNotEmpty) {
        return matches.first.group(0)!;
      }
      return '';
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /* –––––––––––––––––––––––––––– pinyin –––––––––––––––––––––––––––– */

  /// Removes tone information from Pinyin.
  TextModifier<T> toPlainPinyin({bool ignoreEmpty = false}) {
    _process((pinyin) {
      // if (pinyin.isEmpty) return pinyin;
      // final pinyinNumeric = _getMod(pinyin).toNumericPinyin().result;
      final pinyinNumeric = actString.set(pinyin).toNumericPinyin().result;
      return pinyinNumeric.replaceAll(rDigit, '');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Converts Pinyin into numeric tone notation.
  TextModifier<T> toNumericPinyin({bool ignoreEmpty = false}) {
    _process((pinyin) {
      String currentText = pinyin.toLowerCase();
      String toneDigit = '';
      String convertedText = '';

      for (int i = 0; i < currentText.length; i++) {
        final String c = currentText[i];

        if (_toneMap.containsKey(c)) {
          final List<String> mapping = _toneMap[c]!;
          convertedText += mapping[0];
          toneDigit = mapping[1];
        } else {
          if (c == ' ' || rPunctuation.hasMatch(c)) {
            convertedText += toneDigit;
            toneDigit = '';
          }
          convertedText += c;
        }
      }

      if (toneDigit.isNotEmpty) {
        convertedText += toneDigit;
      }

      return convertedText;
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Converts numeric Pinyin into tone-marked Pinyin.
  TextModifier<T> toToneMarkedPinyin({bool ignoreEmpty = false}) {
    _process((pinyin) {
      String currentText = pinyin.toLowerCase();
      currentText = currentText.replaceAll('ü', 'v');
      List<String> currentWords = currentText.split(' ');
      List<String> convertedWords = [];

      for (String word in currentWords) {
        // Punctuation extraction block
        String end = '';
        final Match? punctuationMatch = rPunctuation.firstMatch(word);
        if (punctuationMatch != null) {
          end = punctuationMatch.group(0)!;
        }
        String charConverted = '';
        String wordBuilder = '';
        String cleanWord = word.substring(0, word.length - end.length);

        if (rDigit.hasMatch(word)) {
          for (int i = 0; i < cleanWord.length; i++) {
            final String c = cleanWord[i];
            if (c.compareTo('a') >= 0 && c.compareTo('z') <= 0) {
              charConverted += c;
            } else {
              if (c.compareTo('0') >= 0 && c.compareTo('5') <= 0) {
                int tone = int.parse(c) % 5; // tone 5 -> 0
                if (tone == 0) {
                  charConverted = charConverted.replaceAll('v', 'ü');
                } else {
                  final Match? m = rVowel.firstMatch(charConverted);
                  if (m == null) {
                    charConverted += c;
                  } else if (m.group(0)!.length == 1) {
                    // one vowel
                    final String matchedVowel = m.group(0)!;
                    final int vowelIndex = _pinyinToneMark[0].indexOf(
                      matchedVowel,
                    );
                    charConverted =
                        charConverted.substring(0, m.start) +
                        _pinyinToneMark[tone][vowelIndex] +
                        charConverted.substring(m.end);
                  } else {
                    if (charConverted.contains('a')) {
                      charConverted = charConverted.replaceFirst(
                        'a',
                        _pinyinToneMark[tone][0],
                      );
                    } else if (charConverted.contains('o')) {
                      charConverted = charConverted.replaceFirst(
                        'o',
                        _pinyinToneMark[tone][1],
                      );
                    } else if (charConverted.contains('e')) {
                      charConverted = charConverted.replaceFirst(
                        'e',
                        _pinyinToneMark[tone][2],
                      );
                    } else if (charConverted.endsWith('ui')) {
                      charConverted = charConverted.replaceFirst(
                        'i',
                        _pinyinToneMark[tone][3],
                      );
                    } else if (charConverted.endsWith('iu')) {
                      charConverted = charConverted.replaceFirst(
                        'u',
                        _pinyinToneMark[tone][4],
                      );
                    } else {
                      charConverted += '#';
                    }
                  }
                }
              }
              wordBuilder += charConverted;
              charConverted = '';
            }
          }
          wordBuilder += charConverted;
          wordBuilder += end;
        } else {
          wordBuilder += cleanWord + end;
        }
        convertedWords.add(wordBuilder);
      }
      return convertedWords.join(' ');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Converts Pinyin frames to tone-marked Pinyin.
  TextModifier<T> convertPinyin({bool ignoreEmpty = false}) {
    return modifyPattern(rFrame, (match) {
      final pinyin = actString.set(match.group(1)!).toToneMarkedPinyin().result;
      return '[$pinyin]';
    }, ignoreEmpty: ignoreEmpty);
  }

  /* ================================================================ */
  /*                           APPLY SYNTAX                           */
  /* ================================================================ */

  /// Converts formatted text into Pleco-compatible output.
  TextModifier<T> writeToPleco({bool ignoreEmpty = true}) {
    _warnMissingSyntax();
    String nlSyntax = getSyntax(cmd: 'newline')[0];
    _process((text) {
      String result = text;
      return result
          .replaceAll('\n\n', '$nlSyntax $nlSyntax')
          .replaceAll('\n', nlSyntax)
          .replaceAll(rBullet, '◼');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }


  /// Links Pronunciation frames to their configured syntax representation.
  TextModifier<T> linkPronunciation({bool ignoreEmpty = false}) {
    _warnMissingSyntax();
    return modifyPattern(rFrame, (match) {
      final linked = actString
          .set(match.group(1)!)
          .applySyntax(commandList: ['link'])
          .result;
      return '[$linked]';
    }, ignoreEmpty: ignoreEmpty);
  }


  /// Frames [text] using the supplied syntax elements.
  String _frameText(String text, List<String> syntax) {
    String framedText = text;
    if (syntax.length == 2) {
      framedText = '${syntax.first}$framedText${syntax.last}';
    } else if (syntax.length == 1) {
      framedText = '${syntax.first}$framedText';
    }
    return framedText;
  }

  /// Applies the active syntax command or the supplied [commandList]
  /// to the current result.
  TextModifier<T> applySyntax({
    List<String> commandList = const [],
    bool ignoreEmpty = false,
  }) {
    _process((text) {
      if (commandList.isEmpty) {
        return actString.set(text, command: _fullCommand).applyCommand().result;
      }
      return actString.set(text).applySyntaxCommands(commandList).result;
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Applies the currently selected syntax [command].
  TextModifier<T> applyCommand({bool ignoreEmpty = false}) {
    _log.finest('Command is applied: $command');
    final List<String> activeSyntax = getSyntax(cmd: command);
    final activeColor = color;
    _process((text) {
      if (text.isEmpty) return text;
      String processed = text;
      if (command == _colorCommand &&
          // activeColor != null &&
          activeColor.isNotEmpty) {
        processed = '$activeColor$processed';
        processed = _frameText(processed, activeSyntax);
      } else if (command != _colorCommand) {
        processed = _frameText(processed, activeSyntax);
      }
      return processed;
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /// Applies one or more syntax commands sequentially.
  TextModifier<T> applySyntaxCommands(
    dynamic commands, {
    bool ignoreEmpty = false,
  }) {
    _log.fine('List of commands is applied to text: $commands');
    _process((text) {
      String applied = text;
      if (commands is List) {
        for (final String cmd in commands as List<String>) {
          applied = actString.set(applied, command: cmd).applyCommand().result;
        }
      } else {
        applied = actString
            .set(applied, command: commands as String)
            .applyCommand()
            .result;
      }
      return applied;
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /* ================================================================ */
  /*                             COMMANDS                             */
  /* ================================================================ */

  static final String _defaultCommand = 'normal';
  static final String _colorCommand = 'color';
  static final String _defaultColor = '';

  /// Sets the active syntax command.
  ///
  /// The provided command or alias is resolved to its configured command.
  /// Falls back to the default command when the command cannot be resolved.
  set command(String newCommand) =>
      _fullCommand = getFullCommand(newCommand) ?? _defaultCommand;

  /// Returns the currently active syntax command.
  ///
  /// Returns `null` when no command is active.
  String? get command {
    final currentCommand = _fullCommand;
    if (currentCommand == '') return null;
    if (currentCommand == _defaultCommand) return _defaultCommand;
    return currentCommand;
  }

  /// Resolves a command alias to its configured command name.
  String? getFullCommand(String? cmd) {
    _log.finer('get full command from: $cmd');
    if (cmd == null || cmd == _defaultCommand) return null;
    _warnMissingSyntax();
    cmd = cmd.toLowerCase();
    for (final commandSyntax in mapSyntax!.entries) {
      if (cmd == commandSyntax.key.toLowerCase()) return commandSyntax.key;
      final dynamic commandInfo = commandSyntax.value;
      if (commandInfo is Map && commandInfo.containsKey('caller')) {
        final dynamic caller = commandInfo['caller'];
        if (caller is List) {
          if (caller.contains(cmd)) return commandSyntax.key;
        }
      }
    }
    _log.shout('Invalid command "$cmd".');
    return null;
  }

  /// Checks whether [fullCommand] is a configured command.
  bool _isCommand(String? fullCommand) {
    if (fullCommand == null) return false;
    _warnMissingSyntax();
    if (mapSyntax!.containsKey(fullCommand)) return true;
    return false;
  }

  /// Returns the syntax definition for the selected command.
  List<String> getSyntax({String? cmd}) {
    String? targetedCommand;
    if (cmd != null) {
      targetedCommand = getFullCommand(cmd);
    } else {
      targetedCommand = _fullCommand;
    }

    if (_isCommand(targetedCommand)) {
      return List<String>.from(
        mapSyntax![targetedCommand]['syntax'] as List<dynamic>,
      );
    }
    _log.warning('Could not get syntax from command "$command"');
    return [];
  }

  set color(String newColor) => _colorVal = getColor(newColor) ?? '';

  /// Resolves a color name, alias, or direct color value.
  String? getColor(String? col) {
    _log.finer('get color from: $col');
    if (col == null || col == _defaultColor) return null;
    _warnMissingSyntax();
    if (_isColor(col)) return col;
    if (_isFavColor(col)) {
      col = mapColorFav![col] as String;
    }
    if (_isColorName(col)) {
      final colorVal = mapColor![col] as String;
      return colorVal;
    }
    _log.shout('Invalid color "$col".');
    return null;
  }

  /// Checks whether [col] is a configured color value.
  bool _isColor(String col) {
    if (mapColor!.containsValue(col)) return true;
    return false;
  }

  /// Checks whether [col] is a configured color name or favorite alias.
  bool _isColorName(String col) {
    if (mapColor!.containsKey(col)) return true;
    if (mapColorFav is Map && mapColorFav!.containsKey(col)) return true;
    return false;
  }

  /// Checks whether [col] is a configured favorite color alias.
  bool _isFavColor(String col) {
    if (mapColorFav is Map && mapColorFav!.containsKey(col)) return true;
    return false;
  }
}

/// Unicode range for CJK Radicals Supplement.
const String _cjkRadSupl = r'\u2E80-\u2EFF';
/// Unicode range for Kangxi Radicals.
const String _kangxiRad = r'\u2F00-\u2FDF';
/// Unicode range for CJK Strokes.
const String _cjkStrokes = r'\u31C0-\u31EF';
/// Unicode range for CJK Unified Ideographs Extension A.
const String _cjkExtA = r'\u3400-\u4DBF';
/// Unicode range for CJK Unified Ideographs.
const String _cjkUniIdeogr = r'\u4E00-\u9FFF';
/// Unicode range used for Pleco syntax characters.
const String _pleco = r'\u{EAAA}-\u{EFFF}';

/// Unicode range for CJK Unified Ideographs Extensions B–F.
const String _extBF = r'\u{20000}-\u{2EBEF}';
/// Unicode range for CJK Unified Ideographs Extensions G–H.
const String _extGH = r'\u{30000}-\u{3347F}';
/// Unicode range for CJK Unified Ideographs Extension I.
const String _extI = r'\u{2EBF0}-\u{2EE5F}';
/// Unicode range covering unassigned extensions.
final String unassignedExtensions = r'\u{40000}-\u{10FFFF}';
/// Combined Unicode ranges used to identify Chinese characters.
const String isChineseChar =
    '$_cjkRadSupl$_kangxiRad$_cjkStrokes$_cjkExtA$_cjkUniIdeogr$_extBF$_extI$_extGH';
/// Regular expression for supported Pleco syntax patterns.
final _plecoPatterns = "(${['1A0A', 'A0P', '1A0P', 'AA10', 'AA00'].join('|')})";
/// Matches Pleco syntax characters and supported Pleco patterns.
final RegExp rPleco = RegExp('[$_pleco]|$_plecoPatterns', unicode: true);
/// Matches one or more numeric digits.
final RegExp rDigit = RegExp(r'\d+');
/// Matches supported Chinese and English punctuation marks.
final RegExp rPunctuation = RegExp(r'[.,?!。，！？]');
/// Matches Pinyin vowels, including `ü`.
final RegExp rVowel = RegExp(r'[aoeiuvü]+');
/// Matches text enclosed in backslash-delimited frames.
final RegExp rFrame = RegExp(r'\[([^\]\[]+)\]');
/// Matches supported bullet characters.
final RegExp rBullet = RegExp(r'[■□●○]');

/// Maps Pinyin tone numbers to their corresponding tone-marked vowels.
const List<List<String>> _pinyinToneMark = [
  ['a', 'o', 'e', 'i', 'u', 'v', 'ü'], // Tone 0 / 5
  ['ā', 'ō', 'ē', 'ī', 'ū', 'ǖ', 'ǖ'], // Tone 1
  ['á', 'ó', 'é', 'í', 'ú', 'ǘ', 'ǘ'], // Tone 2
  ['ǎ', 'ǒ', 'ě', 'ǐ', 'ǔ', 'ǚ', 'ǚ'], // Tone 3
  ['à', 'ò', 'è', 'ì', 'ù', 'ǜ', 'ǜ'], // Tone 4
];
/// Maps tone-marked Pinyin characters to their base vowel and tone number.
const Map<String, List<String>> _toneMap = {
  'ā': ['a', '1'], 'á': ['a', '2'], 'ǎ': ['a', '3'], 'à': ['a', '4'], // a
  'ē': ['e', '1'], 'é': ['e', '2'], 'ě': ['e', '3'], 'è': ['e', '4'], // e
  'ī': ['i', '1'], 'í': ['i', '2'], 'ǐ': ['i', '3'], 'ì': ['i', '4'], // i
  'ō': ['o', '1'], 'ó': ['o', '2'], 'ǒ': ['o', '3'], 'ò': ['o', '4'], // o
  'ū': ['u', '1'], 'ú': ['u', '2'], 'ǔ': ['u', '3'], 'ù': ['u', '4'], // u
  'ǖ': ['v', '1'], 'ǘ': ['v', '2'], 'ǚ': ['v', '3'], 'ǜ': ['v', '4'], // ü
  'ü': ['v', ''],
};
/// Maps punctuation between English/German-style and Chinese-style forms.
const Map<String, String> _punctuationMap = {
  // Sentence Endings
  '.': '。',
  ',': '，',
  '!': '！',
  '?': '？',
  // Pauses & Breaks
  ':': '：',
  ';': '；',
  // Enclosures & Quotes
  '(': '（',
  ')': '）',
  '[': '［',
  ']': '］',
  '{': '｛',
  '}': '｝',
  // Special Typographical Marks
  '_': '＿',
  '~': '～',
};

// static final RegExp _bracketPattern = RegExp(r'[《》〈〉]');
