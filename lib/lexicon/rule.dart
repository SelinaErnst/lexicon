import 'package:lexicon/lexicon.dart';
import 'sentence.dart';
import 'character.dart';
import 'dictionary.dart';
import 'text_modifier.dart';
import 'utils.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('RuleLog');

final Set<String> _idMethods = {'shorten', 'hash'}; // uniqueID : method

final staticModifier = TextModifier<String>('');

class Rule extends Character with CopyEngine<Rule> {
  String get level => data['level'] as String;
  String get title => data['title'] as String;
  String get subtitle => data['subtitle'] as String;
  String get explanation => data['explanation'] as String;
  List<String> get tags => data['tags'] as List<String>;
  List<String> get structures => data['structures'] as List<String>;
  List<String> get structuresOpp => data['structuresOpp'] as List<String>;
  List<Sentence> get sentences => data['sentences'] as List<Sentence>;
  Dictionary get characters => data['characters'] as Dictionary;
  Dictionary get charactersOpp => data['charactersOpp'] as Dictionary;
  // ChDictionary characters = ChDictionary(name: 'ruleCharacters');
  // ChDictionary charactersOpp = ChDictionary(name: 'ruleCharactersOpp');
  // Dictionary characters = Dictionary(
  //   name: 'ruleCharacters',
  //   baseCategories: ['simplified', 'traditional', 'pinyin'],
  // );
  // Dictionary charactersOpp = Dictionary(
  //   name: 'ruleCharactersOpp',
  //   baseCategories: ['simplified', 'traditional', 'pinyin'],
  // );

  @override
  bool get strict => true;

  @override
  List<String> get baseCategories => ['level', 'title', 'subtitle'];

  Rule._internal({
    required Map<String, dynamic> entry,
    super.specs,
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) {
    
    data['characters'] = Dictionary(
      name: 'ruleCharacters',
      baseCategories: ['simplified', 'traditional', 'pinyin'],
    );

    data['charactersOpp'] = Dictionary(
      name: 'ruleCharactersOpp',
      baseCategories: ['simplified', 'traditional', 'pinyin'],
    );

    for (final item in categories.entries) {
      if (entry.containsKey(item.key)) {
        set(item.key, entry[item.key]);
      } else {
        set(item.key, null);
      }
    }

    if (mapColor != null && mapSyntax != null) {
      addSyntax(mapSyntax, mapColor, mapColorFav: mapColorFav);
    }
    characters.setLinkedRule(this);
    charactersOpp.setLinkedRule(this);
  }

  factory Rule({
    Map<String, dynamic> entry = const {},
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) {
    final Map<String, Type> ruleCat = {
      // 'level': int,
      // 'title': String,
      // 'subtitle': String,
      'tags': List<String>,
      'structures': List<String>,
      'structuresOpp': List<String>,
      'explanation': String,
      'sentences': List<Sentence>,
      'characters': Dictionary,
      'charactersOpp': Dictionary,
    };
    _log.info('factory init of Rule');
    return Rule._internal(
      entry: entry,
      specs: ruleCat,
      mapSyntax: mapSyntax,
      mapColor: mapColor,
      mapColorFav: mapColorFav,
    );
  }

  @override
  Rule createInstance({
    Map<String, dynamic>? entry,
    Map<String, Type>? specs,
    List<String>? baseCategories,
    bool? strict,
  }) {
    _log.finer('Create instance of Rule.');
    return Rule._internal(
      entry: entry ?? data.deepCopy(),
      specs: categories,
      mapSyntax: mapSyntax,
      mapColor: mapColor,
      mapColorFav: mapColorFav,
    );
  }

  void clear() {
    for (final entry in categories.entries) {
      remove(entry.key);
    }
  }

  static List<Sentence> _listSentences(List<dynamic> rawSentences) {
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
              mod: staticModifier,
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
    return '« Level $level: $title »';
  }

  @override
  void set(String category, dynamic value, {bool force = false}) {
    if (force) {
      _log.finest(
        'Rule was set to force reset of category values. This option is deprecated.',
      );
    }

    dynamic dataValue;

    if (['level', 'title', 'subtitle', 'explanation'].contains(category)) {
      dataValue = value is String ? value.trim() : '';
    } else if (['tags', 'structures', 'structuresOpp'].contains(category)) {
      List<String> dataList = value is List<String> ? value : <String>[];
      dataList = dataList.map((String element) => element.trim()).toList();
      dataValue = List<String>.from(dataList);
    } else if (category == 'sentences') {
      dataValue = value is List ? _listSentences(value) : <Sentence>[];
    } else if (['characters', 'charactersOpp'].contains(category)) {
      dataValue = value;
      if (category == 'characters') {
        if (dataValue is! Dictionary) {
          data['characters'].characters = dataValue;
          dataValue = data['characters'];
        }
      }
      if (category == 'charactersOpp') {
        if (dataValue is! Dictionary) {
          data['charactersOpp'].characters = dataValue;
          dataValue = data['charactersOpp'];
        }
      }
    }
    super.set(category, dataValue, force: false);
  }

  @override
  List<String> get identifier => [level, title, subtitle];

  @override
  Dictionary operator +(other) {
    throw UnsupportedError('operator + is not available for Rule.');
  }

  @override
  bool get isEmpty {
    return isMapCompletelyEmpty(toMap());
  }

  Dictionary get charactersAll => characters.copy() + charactersOpp;

  List<String> get references => characters.characters
      .map(
        (char) =>
            modifier(String, char['simplified']).toCleanRef().result as String,
      )
      .where((char) => char.isNotEmpty)
      .toList();

  List<String> _referenceOthers(Character thisChar) => charactersAll.characters
      .where((char) => char != thisChar)
      .map(
        (char) =>
            modifier(String, char['simplified']).toCleanRef().result as String,
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

  List<Character> applySyntaxToCharacters() {
    final List<Character> syntaxed = [];
    if (characters.isNotEmpty) {
      for (Character char in characters) {
        Map<String, dynamic> combined = {...char.data, ...data};
        combined['strucures_opp'] = combined['structuresOpp'];
        combined['explanation'] = modifier(
          String,
          combined['explanation'],
        ).linkPinyin();
        combined['sentences'] = combined['sentences'].map((Sentence sentence) {
          sentence.addSyntax(
            mapSyntax: mapSyntax,
            mapColor: mapColor,
            mapColorFav: mapColorFav,
          );
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

        final Character updated = char.reconfigure(specs: newCategories);
        updated.update(combined);
        syntaxed.add(updated);
      }
    }
    return syntaxed;
  }
}
