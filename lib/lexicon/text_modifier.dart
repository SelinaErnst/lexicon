import 'utils.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('TextModifierLog');

class TextModifier<T extends Object> {
  T _input;
  T result;
  String? _fullCommand;
  String? _colorVal;

  TextModifier? _actString;

  void Function(dynamic result)? transform;

  Map<String, dynamic>? mapSyntax;
  Map<String, dynamic>? mapColor;
  Map<String, dynamic>? mapColorFav;

  static final Map<String, RegExp> _patterns = {
    'chinese': RegExp('([$isChineseChar]+)', unicode: true),
    'notChinese': RegExp('([^$isChineseChar]+)', unicode: true),
    'english': RegExp(r'([a-zA-Z]+)'),
  };

  /* ================================================================ */
  /*                            CONSTRUCTOR                           */
  /* ================================================================ */

  TextModifier(this._input, {this.transform}) : result = _input;

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

  TextModifier<T> set(dynamic input, {String? command, String? color}) {
    if (input is! T) {
      throw ArgumentError(
        'input for TextModifier<$T> cannot be ${input.runtimeType}',
      );
    } else {
      _input = input;
      result = input;
    }
    if (command != null) _fullCommand = getFullCommand(command);
    if (color != null) _colorVal = _getColor(color);
    return this;
  }

  void transformResult(T modified) {
    if (transform != null) {
      transform!(modified);
    }
  }

  T get input => _input;

  TextModifier<String> createInstance(String text) {
    return TextModifier<String>(text);
  }

  TextModifier<String> _getMod(String text) {
    return createInstance(text);
  }

  void addSyntax({
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) {
    this.mapSyntax = mapSyntax;
    this.mapColor = mapColor;
    this.mapColorFav = mapColorFav;
  }

  void _warnMissingSyntax() {
    if (!hasSyntax) throw AssertionError('Syntax has not been added yet.');
  }

  bool get hasSyntax => mapColor != null && mapSyntax != null;

  TextModifier<String> get actString {
    _actString = _actString ?? TextModifier<String>('');
    if (!_actString!.hasSyntax) {
      _actString!.addSyntax(
        mapColor: mapColor,
        mapSyntax: mapSyntax,
        mapColorFav: mapColorFav,
      );
    }
    _actString!.set('', command: command, color: color);
    return _actString as TextModifier<String>;
  }

  /* ================================================================ */
  /*                              METHODS                             */
  /* ================================================================ */

  T _process(String Function(String) worker, {bool ignoreEmpty = true}) {
    T processedResult;
    if (result is String) {
      processedResult = worker(result as String) as T;
    } else if (result is Map) {
      final Map<String, String> processing = {};

      for (final entry in (result as Map).entries) {
        final String processed = worker(entry.value.toString());
        if (!ignoreEmpty || processed.trim().isNotEmpty) {
          processing[entry.key.toString()] = processed;
        }
      }
      processedResult = processing as T;
    } else if (result is List<String>) {
      final List<String> processing = [];
      for (final dynamic element in result as List) {
        final String processed = worker(element.toString());
        if (!ignoreEmpty || processed.trim().isNotEmpty) {
          processing.add(processed);
        }
      }
      processedResult = processing as T;
    } else {
      processedResult = result;
    }
    transformResult(processedResult);
    return processedResult;
  }

  /* ================================================================ */
  /*                        STRING MANIPULATION                       */
  /* ================================================================ */

  TextModifier<T> strip(String pattern, {bool ignoreEmpty = true}) {
    result = _process((text) {
      return text.strip(pattern);
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /* ================================================================ */
  /*                         SYNTAX PROCESSING                        */
  /* ================================================================ */

  TextModifier<T> removeSyntax({bool ignoreEmpty = false}) {
    result = _process((text) {
      return text.replaceAll(rPleco, '');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  TextModifier<T> toCleanLink({bool ignoreEmpty = true}) {
    result = _process((text) {
      return text
          .replaceAll(rPunctuation, '')
          .replaceAll('_', '＿')
          .replaceAll('…', '＿')
          .replaceAll(' ', '')
          .strip('＿');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  TextModifier<T> toCleanRef({bool ignoreEmpty = true}) {
    result = _process((text) {
      return text
          // .replaceAll(rPunctuation, '')
          .replaceAll('_', '＿')
          .replaceAll('…', '＿')
          .replaceAll(' ', '');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  TextModifier<T> toCleanLanguage(String language, {bool ignoreEmpty = false}) {
    isValid(
      language,
      {'chinese', 'english', 'german'},
      argName: 'language',
      funcName: 'toSentence',
    );

    result = _process((sentence) {
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

  /* ================================================================ */
  /*                              PINYIN                              */
  /* ================================================================ */

  TextModifier<T> toPlainPinyin({bool ignoreEmpty = false}) {
    result = _process((pinyin) {
      final pinyinNumeric = _getMod(pinyin).toNumericPinyin().result;
      return pinyinNumeric.replaceAll(rDigit, '');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  TextModifier<T> toNumericPinyin({bool ignoreEmpty = false}) {
    result = _process((pinyin) {
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

  TextModifier<T> toToneMarkedPinyin({bool ignoreEmpty = false}) {
    result = _process((pinyin) {
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
  /* ––––––––––––––––––––––––––––– regex –––––––––––––––––––––––––––– */

  TextModifier<T> findFirstChar(String type, {bool ignoreEmpty = true}) {
    isValid(
      type,
      _patterns.keys.toSet(),
      funcName: 'findFirstChar',
      argName: 'type',
    );

    result = _process((text) {
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

  TextModifier<T> replaceAll(
    String pattern,
    String replacement, {
    bool ignoreEmpty = false,
  }) {
    return modifyPattern(RegExp(pattern), (match) => replacement);
  }

  TextModifier<T> modifyPattern(
    RegExp pattern,
    String Function(Match match) onMatch, {
    bool ignoreEmpty = false,
  }) {
    result = _process((text) {
      return text.replaceAllMapped(pattern, onMatch);
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  TextModifier<T> linkPinyin({bool ignoreEmpty = false}) {
    return modifyPattern(rFrame, (match) {
      final linked = actString
          .set(match.group(1)!)
          .applySyntax(commandList: ['link'])
          .result;
      return '[$linked]';
    }, ignoreEmpty: ignoreEmpty);
  }

  TextModifier<T> convertPinyin({bool ignoreEmpty = false}) {
    TextModifier<String> mod = _getMod('');
    return modifyPattern(rFrame, (match) {
      final pinyin = mod.set(match.group(1)!).toToneMarkedPinyin().result;
      return '[$pinyin]';
    }, ignoreEmpty: ignoreEmpty);
  }

  TextModifier<T> writeToPleco({bool ignoreEmpty = true}) {
    String nlSyntax = getSyntax(cmd: 'newline')[0];
    result = _process((text) {
      String result = text;
      return result
          .replaceAll('\n\n', '$nlSyntax $nlSyntax')
          .replaceAll('\n', nlSyntax)
          .replaceAll(rBullet, '◼');
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  /* ================================================================ */
  /*                           APPLY SYNTAX                           */
  /* ================================================================ */

  String _frameText(String text, List<String> syntax) {
    String framedText = text;
    if (syntax.length == 2) {
      framedText = '${syntax.first}$framedText${syntax.last}';
    } else if (syntax.length == 1) {
      framedText = '${syntax.first}$framedText';
    }
    return framedText;
  }

  TextModifier<T> applySyntax({
    List<String> commandList = const [],
    bool ignoreEmpty = false,
  }) {
    result = _process((text) {
      if (commandList.isEmpty) {
        return actString.set(text, command: _fullCommand).applyCommand().result;
      }
      return actString.set(text).applySyntaxCommands(commandList).result;
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  TextModifier<T> applyCommand({bool ignoreEmpty = false}) {
    result = _process((text) {
      final List<String> activeSyntax = getSyntax(cmd: command);
      final activeColor = color;
      if (text.isEmpty) return text;
      String processed = text;
      if (command == _colorCommand && activeColor != null) {
        processed = '$activeColor$processed';
      }
      processed = _frameText(processed, activeSyntax);
      return processed;
    }, ignoreEmpty: ignoreEmpty);
    return this;
  }

  TextModifier<T> applySyntaxCommands(
    dynamic commands, {
    bool ignoreEmpty = false,
  }) {
    result = _process((text) {
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

  set command(String newCommand) => _fullCommand = getFullCommand(newCommand);

  String? get command {
    final currentCommand = _fullCommand;
    if (currentCommand == null) return null;
    if (currentCommand == _defaultCommand) return _defaultCommand;
    return currentCommand;
  }

  String? getFullCommand(String? cmd) {
    if (cmd == null || cmd == _defaultCommand) {
      return cmd;
    }

    _warnMissingSyntax();

    for (final commandSyntax in mapSyntax!.entries) {
      if (cmd == commandSyntax.key) return commandSyntax.key;
      final dynamic commandInfo = commandSyntax.value;
      if (commandInfo is Map && commandInfo.containsKey('caller')) {
        final dynamic caller = commandInfo['caller'];
        if (caller is List) {
          if (caller.contains(cmd)) return commandSyntax.key;
        }
      }
    }
    throw ArgumentError('Invalid command "$cmd".');
  }

  bool _isCommand(String? fullCommand) {
    if (fullCommand == null) return false;
    _warnMissingSyntax();
    if (mapSyntax!.containsKey(fullCommand)) return true;
    return false;
  }

  List<String> getSyntax({String? cmd}) {
    String? targetedCommand;
    if (cmd != null) {
      targetedCommand = getFullCommand(cmd);
    } else {
      targetedCommand = _fullCommand;
    }

    if (_isCommand(targetedCommand)) {
      _warnMissingSyntax();
      return List<String>.from(
        mapSyntax![targetedCommand]['syntax'] as List<dynamic>,
      );
    }
    _log.warning('Could not get syntax from command "$command"');
    return [];
  }

  String? get color => _colorVal;

  set color(String newColor) => _colorVal = _getColor(newColor);

  String? _getColor(String? col) {
    if (col == null) return null;
    if (_isColor(col)) return col;
    if (_isFavColor(col)) {
      _warnMissingSyntax();
      col = mapColorFav![col] as String;
    }
    if (_isColorName(col)) {
      _warnMissingSyntax();
      final colorVal = mapColor![col] as String;
      return colorVal;
    }
    throw ArgumentError('Invalid color "$col".');
  }

  bool _isColor(String col) {
    _warnMissingSyntax();
    if (mapColor!.containsValue(col)) return true;
    return false;
  }

  bool _isColorName(String col) {
    _warnMissingSyntax();
    if (mapColor!.containsKey(col)) return true;
    if (mapColorFav is Map && mapColorFav!.containsKey(col)) return true;
    return false;
  }

  bool _isFavColor(String col) {
    if (mapColorFav is Map && mapColorFav!.containsKey(col)) return true;
    return false;
  }
}

const String _cjkRadSupl = r'\u2E80-\u2EFF';
const String _kangxiRad = r'\u2F00-\u2FDF';
const String _cjkStrokes = r'\u31C0-\u31EF';
const String _cjkExtA = r'\u3400-\u4DBF';
const String _cjkUniIdeogr = r'\u4E00-\u9FFF';
const String _pleco = r'\u{EAAA}-\u{EFFF}';

const String _extBF = r'\u{20000}-\u{2EBEF}';
const String _extGH = r'\u{30000}-\u{3347F}';
const String _extI = r'\u{2EBF0}-\u{2EE5F}';
const String unassignedExtensions = r'\u{40000}-\u{10FFFF}';

const String isChineseChar =
    '$_cjkRadSupl$_kangxiRad$_cjkStrokes$_cjkExtA$_cjkUniIdeogr$_extBF$_extI$_extGH';

final _plecoPatterns = "(${['1A0A', 'A0P', '1A0P', 'AA10', 'AA00'].join('|')})";
final RegExp rPleco = RegExp('[$_pleco]|$_plecoPatterns', unicode: true);
final RegExp rDigit = RegExp(r'\d+');
final RegExp rPunctuation = RegExp(r'[.,?!。，！？]');
final RegExp rVowel = RegExp(r'[aoeiuvü]+');
final RegExp rFrame = RegExp(r'\[([^\]\[]+)\]');
final RegExp rBullet = RegExp(r'[■□●○]');

const List<List<String>> _pinyinToneMark = [
  ['a', 'o', 'e', 'i', 'u', 'v', 'ü'], // Tone 0 / 5
  ['ā', 'ō', 'ē', 'ī', 'ū', 'ǖ', 'ǖ'], // Tone 1
  ['á', 'ó', 'é', 'í', 'ú', 'ǘ', 'ǘ'], // Tone 2
  ['ǎ', 'ǒ', 'ě', 'ǐ', 'ǔ', 'ǚ', 'ǚ'], // Tone 3
  ['à', 'ò', 'è', 'ì', 'ù', 'ǜ', 'ǜ'], // Tone 4
];

const Map<String, List<String>> _toneMap = {
  'ā': ['a', '1'], 'á': ['a', '2'], 'ǎ': ['a', '3'], 'à': ['a', '4'], // a
  'ē': ['e', '1'], 'é': ['e', '2'], 'ě': ['e', '3'], 'è': ['e', '4'], // e
  'ī': ['i', '1'], 'í': ['i', '2'], 'ǐ': ['i', '3'], 'ì': ['i', '4'], // i
  'ō': ['o', '1'], 'ó': ['o', '2'], 'ǒ': ['o', '3'], 'ò': ['o', '4'], // o
  'ū': ['u', '1'], 'ú': ['u', '2'], 'ǔ': ['u', '3'], 'ù': ['u', '4'], // u
  'ǖ': ['v', '1'], 'ǘ': ['v', '2'], 'ǚ': ['v', '3'], 'ǜ': ['v', '4'], // ü
  'ü': ['v', ''],
};

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
