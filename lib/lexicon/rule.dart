import 'package:lexicon/lexicon.dart';
import 'sentence.dart';
import 'character.dart';
import 'dictionary.dart';
import 'text_modifier.dart';
import 'utils.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('RuleLog');

late TextModifier<String> modifier;

final Set<String> _idMethods = {'shorten', 'hash'}; // uniqueID : method

class Rule extends Character with CopyEngine<Rule> {
  String level;
  String title;
  String subtitle;
  String explanation;
  List<String> tags;
  List<String> structures;
  List<String> structuresOpp;
  List<Sentence> sentences;
  Dictionary characters;
  Dictionary charactersOpp;

  @override
  bool get strict => true;

  @override
  List<String> get baseCategories => ['level', 'title', 'subtitle'];

  Rule._internal({required Map<String, dynamic> entry, super.specs})
    : level = entry['level'] is String ? entry['level'].toString().trim() : '',
      title = entry['title'] is String ? entry['title'].toString().trim() : '',
      subtitle = entry['subtitle'] is String
          ? entry['subtitle'].toString().trim()
          : '',
      explanation = entry['explanation'] is String
          ? entry['explanation'].toString().trim()
          : '',
      tags = entry['tags'] is List ? List.from(entry['tags'] as List) : [],
      structures = entry['structures'] is List
          ? List.from(entry['structures'] as List)
          : [],
      structuresOpp = entry['structuresOpp'] is List
          ? List.from(entry['structuresOpp'] as List)
          : [],
      sentences = entry['sentences'] is List
          ? _listSentences(List.from(entry['sentences'] as List))
          : [],
      characters = Dictionary(characters: entry['characters']),
      charactersOpp = Dictionary(characters: entry['charactersOpp']) {
    update({
      'level': level,
      'title': title,
      'subtitle': subtitle,
      'explanation': explanation,
      'tags': tags,
      'structures': structures,
      'structuresOpp': structuresOpp,
      'sentences': sentences,
      'characters': characters,
      'charactersOpp': charactersOpp,
    });
  }

  factory Rule({
    Map<String, dynamic> entry = const {},
    TextModifier<String>? mod,
  }) {
    final Map<String, Type> ruleCat = {
      'level': String,
      'title': String,
      'subtitle': String,
      'tags': List<String>,
      'structures': List<String>,
      'structuresOpp': List<String>,
      'explanation': String,
      'sentences': List<Sentence>,
      'characters': Dictionary,
      'charactersOpp': Dictionary,
    };
    _log.info('factory init of Rule');
    modifier = mod ?? TextModifier('');
    return Rule._internal(entry: entry, specs: ruleCat);
  }

  static List<Sentence> _listSentences(List<dynamic>? rawSentences) {
    if (rawSentences == null) return [];

    return rawSentences
        .map((item) {
          if (item is Sentence) return item;
          if (item is Map<String, String>) {
            String text = item['text'] ?? '';
            String pinyin = item['pinyin'] ?? '';
            String translation = item['translation'] ?? '';
            return Sentence(
              text: text,
              pinyin: pinyin,
              translation: translation,
              mod: modifier,
            );
          }
          return null;
        })
        .whereType<Sentence>()
        .toSet()
        .where((s) => !s.isEmpty)
        .toList();
  }

  @override
  String toString() {
    return 'Level $level: $title';
  }

  @override
  Rule copy() {
    return Rule(entry: data.deepCopy());
  }

  @override
  Rule createInstance({
    Map<String, dynamic>? entry,
    Map<String, Type>? specs,
    List<String>? baseCategories,
  }) {
    if (baseCategories != null)
      _log.fine('Cannot change baseCategories of Rule.');
    final init = Rule._internal(
      entry: entry ?? data.deepCopy(),
      specs: categories,
    );
    return init;
  }

  @override
  Rule reconfigure({Map<String, Type>? specs, List<String>? baseCategories}) {
    throw UnsupportedError('reconfigure() is not available for Rule.');
  }

  void clear() {
    level = "";
    title = "";
    subtitle = "";
    tags = [];
    structures = [];
    structuresOpp = [];
    sentences = [];
    characters.empty();
    charactersOpp.empty();
  }

  @override
  void set(String category, value, {bool force = false}) {
    if (value == null) {
      throw ArgumentError('Value for "$category" cannot be null');
    }
    if (force) {
      _log.finer(
        'Rule was set to force reset of category values. This option is deprecated.',
      );
    }

    super.set(category, value, force: false);
    if (sameTypes(categories[category]!, data[category].runtimeType)) {
      final dataValue = data[category];
      if (category == 'level' && dataValue is String) {
        level = dataValue;
      } else if (category == 'title' && dataValue is String) {
        title = dataValue;
      } else if (category == 'subtitle' && dataValue is String) {
        subtitle = dataValue;
      } else if (category == 'tags' && dataValue is List<String>) {
        tags = dataValue;
      } else if (category == 'structures' && dataValue is List<String>) {
        structures = dataValue;
      } else if (category == 'structuresOpp' && dataValue is List<String>) {
        structuresOpp = dataValue;
      } else if (category == 'sentences' && dataValue is List<Sentence>) {
        sentences = dataValue;
      } else if (category == 'characters' && dataValue is Dictionary) {
        characters = dataValue;
      } else if (category == 'charactersOpp' && dataValue is Dictionary) {
        charactersOpp = dataValue;
      }
    }
  }

  @override
  void remove(String category) {
    throw UnsupportedError('remove() is not available for Rule.');
  }

  @override
  void updateCategoryMap(String category, Map<String, dynamic>? updates) {
    throw UnsupportedError('updateCategoryMap() is not available for Rule.');
  }

  @override
  List<String> get identifier => [level, title, subtitle];

  @override
  Dictionary operator +(other) {
    throw UnsupportedError('operator + is not available for Rule.');
  }

  @override
  void operator []=(String category, value) {
    throw UnsupportedError('operator []= is not available for Rule.');
  }

  @override
  bool get isEmpty {
    return isMapCompletelyEmpty(toMap());
  }

  Dictionary get charactersAll => characters.copy().add(charactersOpp);

  List<String> _referenceOthers(Character thisChar) => charactersAll.characters
      .where((char) => char != thisChar)
      .map(
        (char) =>
            modifier.set(char['simplified'] as String).toCleanRef().result,
      )
      .where((char) => char.isNotEmpty)
      .toList();

  List<String> get references => characters.characters
      .map(
        (char) =>
            modifier.set(char['simplified'] as String).toCleanRef().result,
      )
      .where((char) => char.isNotEmpty)
      .toList();

  String uniqueID({String method = 'shorten'}) {
    String unique = '';
    String shortTitle = '';
    String shortSubTitle = '';

    isValid(method, _idMethods, funcName: 'uniqueID', argName: 'method');

    if (method == 'shorten') {
      if (title.isNotEmpty) {
        shortTitle = title
            .split(' ')
            .map((word) => word[0])
            .toList()
            .where((char) => char.isNotEmpty)
            .join('');
      }
      if (subtitle.isNotEmpty) {
        shortSubTitle = subtitle
            .split(' ')
            .map((word) => word[0])
            .toList()
            .where((char) => char.isNotEmpty)
            .join('');
      }
      unique = '${level}_${shortTitle}_$shortSubTitle';
    } else if (method == 'hash') {
      unique = "${level}_$hashCodeFormatted";
    }
    return unique;
  }

  List<String> applySyntaxToCharacters() {
    if (characters.isNotEmpty) {
      for (Character char in characters) {
        Map<String, dynamic> combined = {...char.data, ...data};
        combined['strucures_opp'] = combined['structuresOpp'];
        combined['explanation'] = TextModifier(
          combined['explanation'] as String,
        ).act.linkPinyin();
        combined['sentences'] = combined['sentences'].map((Sentence sentence) {
          return sentence.applySyntax();
        }).toList();
        combined['other_characters'] = _referenceOthers(char);

        final newCategories = {
          ...categories,
          ...{'other_characters': List<String>},
        };

        newCategories.remove('characters');
        newCategories.remove('charactersOpp');
        newCategories.remove('structuresOpp');

        // Character updated = char.copyWith(
        //   specs: newCategories,
        //   entry: combined,
        // );
        // print(updated.data);
      }
    }
    return [];
  }
}
