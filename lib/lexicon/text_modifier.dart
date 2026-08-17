import 'utils.dart';
import 'text_action.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('TextModEngine');

class TextModifier<T extends Object> {
  T _input;
  T result;
  TextAction? _strAct;
  TextAction? _inputAct;

  static const String _cjkRadSupl = r'\u2E80-\u2EFF';
  static const String _kangxiRad = r'\u2F00-\u2FDF';
  static const String _cjkStrokes = r'\u31C0-\u31EF';
  static const String _cjkExtA = r'\u3400-\u4DBF';
  static const String _cjkUniIdeogr = r'\u4E00-\u9FFF';
  static const String _pleco = r'\u{EAAA}-\u{EFFF}';

  static const String _extBF = r'\u{20000}-\u{2EBEF}';
  static const String _extGH = r'\u{30000}-\u{3347F}';
  static const String _extI = r'\u{2EBF0}-\u{2EE5F}';
  static const String unassignedExtensions = r'\u{40000}-\u{10FFFF}';

  static const String isChineseChar =
      '$_cjkRadSupl$_kangxiRad$_cjkStrokes$_cjkExtA$_cjkUniIdeogr$_extBF$_extI$_extGH';

  static final Map<String, RegExp> _patterns = {
    'chinese': RegExp('([$isChineseChar]+)', unicode: true),
    'notChinese': RegExp('([^$isChineseChar]+)', unicode: true),
    'english': RegExp(r'([a-zA-Z]+)'),
  };
  static final _plecoPatterns =
      "(${['1A0A', 'A0P', '1A0P', 'AA10', 'AA00'].join('|')})";
  static final RegExp rPleco = RegExp(
    '[$_pleco]|$_plecoPatterns',
    unicode: true,
  );
  static final RegExp rDigit = RegExp(r'\d+');
  // static final RegExp rPunctuation = RegExp(r'[?|!|.|？|。|,]$');
  static final RegExp rPunctuation = RegExp(r'[.,?!。，！？]');
  static final RegExp rVowel = RegExp(r'[aoeiuvü]+');
  static final RegExp rFrame = RegExp(r'\[([^\]\[]+)\]');
  static final RegExp rBullet = RegExp(r'[■□●○]');

  RegExp? getPattern(String type) {
    return _patterns[type];
  }

  static const List<List<String>> _pinyinToneMark = [
    ['a', 'o', 'e', 'i', 'u', 'v', 'ü'], // Tone 0 / 5
    ['ā', 'ō', 'ē', 'ī', 'ū', 'ǖ', 'ǖ'], // Tone 1
    ['á', 'ó', 'é', 'í', 'ú', 'ǘ', 'ǘ'], // Tone 2
    ['ǎ', 'ǒ', 'ě', 'ǐ', 'ǔ', 'ǚ', 'ǚ'], // Tone 3
    ['à', 'ò', 'è', 'ì', 'ù', 'ǜ', 'ǜ'], // Tone 4
  ];

  static const Map<String, List<String>> _toneMap = {
    'ā': ['a', '1'], 'á': ['a', '2'], 'ǎ': ['a', '3'], 'à': ['a', '4'], // a
    'ē': ['e', '1'], 'é': ['e', '2'], 'ě': ['e', '3'], 'è': ['e', '4'], // e
    'ī': ['i', '1'], 'í': ['i', '2'], 'ǐ': ['i', '3'], 'ì': ['i', '4'], // i
    'ō': ['o', '1'], 'ó': ['o', '2'], 'ǒ': ['o', '3'], 'ò': ['o', '4'], // o
    'ū': ['u', '1'], 'ú': ['u', '2'], 'ǔ': ['u', '3'], 'ù': ['u', '4'], // u
    'ǖ': ['v', '1'], 'ǘ': ['v', '2'], 'ǚ': ['v', '3'], 'ǜ': ['v', '4'], // ü
    'ü': ['v', ''],
  };

  static const Map<String, String> _punctuationMap = {
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

  /* ================================================================ */
  /*                            CONSTRUCTOR                           */
  /* ================================================================ */

  TextModifier(this._input) : result = _input;

  TextModifier<T> set(T input) {
    _input = input;
    result = input;
    return this;
  }

  T get input => _input;

  // TextModifier cleanLanguage(String language) {
  //   result = toCleanSentence(language);
  //   return this;
  // }

  TextModifier<String> createInstance(String text) {
    return TextModifier<String>(text);
  }

  TextModifier<String> _getMod(String text) {
    return createInstance(text);
  }

  void addAction(
    Map<String, dynamic> mapSyntax,
    Map<String, dynamic> mapColor, {
    Map<String, dynamic>? mapColorFav,
  }) {
    _strAct = TextAction(
      '',
      mapColor: mapColor,
      mapSyntax: mapSyntax,
      mapColorFav: mapColorFav,
    );
    _inputAct = TextAction(
      result,
      mapColor: mapColor,
      mapSyntax: mapSyntax,
      mapColorFav: mapColorFav,
    );
  }

  TextAction get act {
    if (_inputAct == null) {
      throw AssertionError('TextAction object has not been added yet.');
    }
    _inputAct!.set(result);
    return _inputAct!;
  }

  TextAction getStrAct(String text) {
    if (_strAct == null) {
      throw AssertionError('TextAction object has not been added yet.');
    }
    _strAct!.set(text);
    return _strAct!;
  }

  /* ================================================================ */
  /*                              METHODS                             */
  /* ================================================================ */

  T _process(String Function(String) worker, {bool ignoreEmpty = true}) {
    if (result is String) {
      return worker(result as String) as T;
    } else if (result is List) {
      final List<String> processedResult = [];
      for (final dynamic element in result as List) {
        final String processed = worker(element.toString());
        if (!ignoreEmpty || processed.trim().isNotEmpty) {
          processedResult.add(processed);
        }
      }
      return processedResult as T;
    }
    return result;
  }

  /* ––––––––––––––––––––––––––––– clean –––––––––––––––––––––––––––– */

  TextModifier<T> removeSyntax() {
    result = _process((text) {
      return text.replaceAll(rPleco, '');
    }, ignoreEmpty: false);
    return this;
  }

  TextModifier<T> toCleanLink() {
    result = _process((text) {
      // final RegExp punctuationPat = RegExp(r'[.,!?。，！？]');
      return text
          .replaceAll(rPunctuation, '')
          .replaceAll('_', '＿')
          .replaceAll('…', '＿')
          .replaceAll(' ', '')
          .strip('＿');
    }, ignoreEmpty: true);
    return this;
  }

  TextModifier<T> toCleanRef() {
    result = _process((text) {
      // final RegExp punctuationPat = RegExp(r'[.,!?。，！？]');
      return text
          // .replaceAll(punctuationPat, '')
          .replaceAll('_', '＿')
          .replaceAll('…', '＿')
          .replaceAll(' ', '');
    }, ignoreEmpty: true);
    return this;
  }

  TextModifier<T> toCleanLanguage(String language) {
    isValid(
      language,
      {'chinese', 'english', 'german'},
      argName: 'language',
      funcName: 'toSentence',
    );

    final List<String> linkSyntax = [];
    try {
      act.command = 'link';
      linkSyntax.addAll(act.getSyntax());
    } catch (e) {
      _log.warning('Some characters cannot be removed.');
    }
    result = _process((sentence) {
      String processed = sentence;
      for (var entry in _punctuationMap.entries) {
        if (language == 'chinese') {
          processed = processed.replaceAll(entry.key, entry.value);
        } else {
          processed = processed.replaceAll(entry.value, entry.key);
        }
      }
      for (var element in linkSyntax) {
        processed = processed.replaceAll(element, '');
      }
      return processed;
    }, ignoreEmpty: false);
    return this;
  }

  /* –––––––––––––––––––––––––––– convert ––––––––––––––––––––––––––– */

  TextModifier<T> toPlainPinyin() {
    result = _process((pinyin) {
      final pinyinNumeric = _getMod(pinyin).toNumericPinyin().result;
      return pinyinNumeric.replaceAll(rDigit, '');
    }, ignoreEmpty: false);
    return this;
  }

  TextModifier<T> toNumericPinyin() {
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
    }, ignoreEmpty: false);
    return this;
  }

  TextModifier<T> toToneMarkedPinyin() {
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
    }, ignoreEmpty: false);
    return this;
  }
  /* ––––––––––––––––––––––––––––– regex –––––––––––––––––––––––––––– */

  TextModifier<T> findFirstChar(String type) {
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
    }, ignoreEmpty: true);
    return this;
  }

  TextModifier<T> modifyPattern(
    RegExp pattern,
    String Function(Match match) onMatch,
  ) {
    result = _process((text) {
      return text.replaceAllMapped(pattern, onMatch);
    });
    return this;
  }

  TextModifier<T> linkPinyin() {
    RegExp pattern = rFrame;
    return modifyPattern(pattern, (match) {
      final linked = getStrAct(
        match.group(1)!,
      ).applySyntax(commandList: ['link']).result;
      return '[$linked]';
    });
  }

  TextModifier<T> convertPinyin() {
    TextModifier<String> mod = _getMod('');
    return modifyPattern(rFrame, (match) {
      final pinyin = mod.set(match.group(1)!).toToneMarkedPinyin().result;
      return '[$pinyin]';
    });
  }

  TextModifier<T> writeToPleco() {
    String nlSyntax = act.getSyntax(cmd: 'newline')[0];
    result = _process((text) {
      String result = text;
      return result
          .replaceAll('\n\n', '$nlSyntax $nlSyntax')
          .replaceAll('\n', nlSyntax)
          .replaceAll(rBullet, '◼');
    }, ignoreEmpty: true);
    return this;
  }
}
