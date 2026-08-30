import 'package:suhan_lexicon/suhan_lexicon.dart';
import 'package:suhan_lexicon/src/errors.dart';
import 'package:suhan_lexicon/src/utils.dart';
import 'package:logging/logging.dart';

final Logger _log = Logger('RuleLog');

final Set<String> _idMethods = {'shorten', 'hash'}; // uniqueID : method

/// Shared text modifier used for rule-level text processing.
final _staticModifier = TextModifier<String>('');

/// Represents a grammar or language rule.
///
/// A rule extends [Character] with rule-specific metadata, linked character
/// dictionaries, example sentences, and rule identifiers.
class Rule extends Character with CopyEngine<Rule> {
  /// access data content directly
  /// The level assigned to this rule.
  String get level => data['level'] as String;

  /// The title of this rule.
  String get title => data['title'] as String;

  /// The subtitle of this rule.
  String get subtitle => data['subtitle'] as String;

  /// The explanation describing this rule.
  String get explanation => data['explanation'] as String;

  /// Tags associated with this rule.
  List<String> get tags => data['tags'] as List<String>;

  /// Character structures associated with this rule.
  List<String> get structures => data['structures'] as List<String>;

  /// Character structures representing the opposite form of this rule.
  List<String> get structuresOpp => data['structuresOpp'] as List<String>;

  /// Example sentences associated with this rule.
  List<Sentence> get sentences => data['sentences'] as List<Sentence>;

  /// Characters associated with this rule.
  Dictionary get characters => data['characters'] as Dictionary;

  /// Characters representing the opposite side of this rule.
  Dictionary get charactersOpp => data['charactersOpp'] as Dictionary;

  @override
  bool get strict => true;

  @override
  List<String> get identifier => [level, title, subtitle];

  @override
  List<String> get baseCategories => ['level', 'title', 'subtitle'];

  /// The dictionary type used for linked character collections.
  final Type dictionaryType;

  /// The character associated with this rule.
  ///
  /// The character may be empty, but retains its base category structure.
  final Character connectedCharacter;

  static final Map<String, dynamic> _empty = {
    'tags': <String>[],
    'structures': <String>[],
    'structuresOpp': <String>[],
    'explanation': '',
    'sentences': <Sentence>[],
  };

  /// Creates a rule with optional metadata, character connection, and
  /// syntax configuration.
  ///
  /// [runtimeDictType] defines the dictionary type used for the rule's
  /// linked character collections.
  Rule({
    Map<String, dynamic> entry = const {},
    Character? connection,
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
    Type runtimeDictType = Dictionary,
  }) : connectedCharacter = connection ?? Character(),
       dictionaryType = runtimeDictType,
       super(
         entry: {..._empty, ...entry},
         categories: {
           'tags': List<String>,
           'structures': List<String>,
           'structuresOpp': List<String>,
           'explanation': String,
           'sentences': List<Sentence>,
           'characters': runtimeDictType,
           'charactersOpp': runtimeDictType,
         },
       ) {
    _log.info('Successfully created rule: ${toString()}');
    if (mapColor != null && mapSyntax != null) {
      addSyntax(mapSyntax, mapColor, mapColorFav: mapColorFav);
    }

    final currentCharacters = data['characters'];
    final currentCharactersOpp = data['charactersOpp'];

    if (currentCharacters is Dictionary) {
      final freshDict = currentCharacters.copy();
      if (connection != null &&
          !currentCharacters.characters.contains(connection)) {
        freshDict.characters = [connection, ...currentCharacters.characters];
      }
      data['characters'] = freshDict;
    } else {
      _ruleCharacters('characters', connection);
    }

    if (currentCharactersOpp is Dictionary) {
      final freshDictOpp = currentCharactersOpp.copy();
      if (connection != null &&
          !currentCharactersOpp.characters.contains(connection)) {
        freshDictOpp.characters = [
          connection,
          ...currentCharactersOpp.characters,
        ];
      }
      data['charactersOpp'] = freshDictOpp;
    } else {
      _ruleCharacters('charactersOpp', connection);
    }

    final dynamic activeDict = data['characters'];
    final dynamic activeDictOpp = data['charactersOpp'];
    if (activeDict != null) activeDict.setLinkedRule(this);
    if (activeDictOpp != null) activeDictOpp.setLinkedRule(this);

    _log.fine(data);
  }

  @override
  String toString() {
    return '« Level $level: $title »';
  }

  /* ––––––––––––––––––––––––––––– copy ––––––––––––––––––––––––––––– */

  /// Creates an independent copy of this rule.
  ///
  /// The copy retains its connected character, dictionary type, syntax
  /// configuration, and rule data.
  @override
  Rule createInstance({
    Map<String, dynamic>? entry,
    Map<String, Type>? categories,
    List<String>? baseCategories,
    bool? strict,
  }) {
    _log.finer('Create instance of Rule.');
    return Rule(
      entry: entry ?? data.deepCopy(),
      connection: connectedCharacter,
      mapSyntax: mapSyntax,
      mapColor: mapColor,
      mapColorFav: mapColorFav,
      runtimeDictType: dictionaryType,
    );
  }

  /// Creates an empty dictionary configured for characters linked to this rule.
  Dictionary createDictionaryInstance(String name) {
    final d = Dictionary(
      name,
      baseCategories: connectedCharacter.baseCategories,
    );
    return d;
  }

  /* ––––––––––––––––––––––––––––– data ––––––––––––––––––––––––––––– */

  /// Removes all values from the rule's categories.
  void clear() {
    for (final entry in categories.entries) {
      remove(entry.key);
    }
  }

  /// Sets and normalizes a rule category.
  ///
  /// Text values are trimmed, list-based values are normalized to lists
  /// of trimmed strings, sentences are converted to [Sentence] objects,
  /// and character categories are maintained as linked dictionaries.
  @override
  void set(String category, dynamic value, {bool force = true}) {
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
      dataValue = _ruleCharacters(category, value);
    }
    super.set(category, dataValue, force: force);
  }

  /// Returns the linked character dictionary for [category], creating it
  /// when necessary.
  Dictionary _ruleCharacters(String category, dynamic value) {
    if (data[category] == null) {
      data[category] = createDictionaryInstance('rule${category.title()}');
    }
    if (value is! Dictionary) {
      data[category].characters = value;
      value = data[category];
    }
    return value as Dictionary;
  }

  /// Converts raw sentence data into a list of valid [Sentence] objects.
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
              mod: _staticModifier,
            );
          }
          return null;
        })
        .whereType<Sentence>()
        .toSet()
        .where((s) => !s.isEmpty)
        .toList();
  }

  /// Prevents addition through the character operator for rules.
  ///
  /// Rules manage their linked character dictionaries explicitly rather
  /// than supporting direct addition.
  @override
  Dictionary operator +(other) {
    _log.shout('Operator + is not available for Rule.');
    throw UnsupportedOperationException('+');
  }

  /// Returns a combined copy of the characters associated with this rule
  /// and its opposite character collection.
  Dictionary get charactersAll => characters.copy() + charactersOpp.copy();

  /// Returns cleaned references for the characters associated with this rule.
  List<String> get references => characters.characters
      .map((char) => modifier(char['simplified']).toCleanRef().result as String)
      .where((char) => char.isNotEmpty)
      .toList();

  /// Returns cleaned references for characters other than [thisChar].
  List<String> _referenceOthers(Character thisChar) => charactersAll.characters
      .where((char) => char != thisChar)
      .map((char) => modifier(char['simplified']).toCleanRef().result as String)
      .where((char) => char.isNotEmpty)
      .toList();

  /* ––––––––––––––––––––––––––– identity ––––––––––––––––––––––––––– */

  /// Returns a unique identifier using the selected [method].
  ///
  /// The `shorten` method derives an identifier from the rule level,
  /// title, and subtitle. The `hash` method combines the level with
  /// the rule's formatted hash code.
  @override
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

  /* –––––––––––––––––––––––––––– syntax –––––––––––––––––––––––––––– */

  /// Applies this rule's syntax and related data to its characters.
  ///
  /// Returns updated character copies containing the rule's relevant
  /// information, including linked references, structures, explanations,
  /// and sentences.
  List<Character> applySyntaxToCharacters() {
    final List<Character> syntaxed = [];
    if (characters.isNotEmpty) {
      for (Character char in characters) {
        Map<String, dynamic> combined = {...char.data, ...data};
        combined['strucures_opp'] = combined['structuresOpp'];
        combined['explanation'] = modifier(
          combined['explanation'],
        ).linkPronunciation();
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

        final Character updated = char.reconfigure(categories: newCategories);
        updated.update(combined);
        syntaxed.add(updated);
      }
    }
    return syntaxed;
  }
}

/* ================================================================ */
/*                           CHINESE RULE                           */
/* ================================================================ */

/// A Chinese-specific implementation of [Rule].
///
/// Binds rule connections to [ChCharacter] and linked character
/// dictionaries to [ChDictionary].
class ChRule extends Rule {
  @override
  ChCharacter get connectedCharacter => super.connectedCharacter as ChCharacter;

  /// Creates a Chinese rule with a [ChCharacter] connection.
  ChRule({
    ChCharacter? connection,
    super.entry,
    super.mapSyntax,
    super.mapColor,
    super.mapColorFav,
  }) : super(
         connection: connection ?? ChCharacter(),
         runtimeDictType: ChDictionary,
       );

  /// Creates an independent copy of this Chinese rule.
  @override
  Rule createInstance({
    Map<String, dynamic>? entry,
    Map<String, Type>? categories,
    List<String>? baseCategories,
    bool? strict,
  }) {
    return ChRule(
      entry: entry ?? data.deepCopy(),
      connection: connectedCharacter,
      mapSyntax: mapSyntax,
      mapColor: mapColor,
      mapColorFav: mapColorFav,
    );
  }

  /// Creates a Chinese dictionary for characters linked to this rule.
  @override
  ChDictionary createDictionaryInstance(String name) {
    return ChDictionary(name);
  }
}
