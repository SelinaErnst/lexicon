import 'package:lexicon/lexicon.dart';
import 'sentence.dart';
import 'character.dart';
import 'dictionary.dart';
import 'text_modifier.dart';
import 'utils.dart';

final modifier = TextModifier('');

final Set<String> _idMethods = {'shorten', 'hash'}; // uniqueID : method

class Rule extends Character {
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

  // @override
  // List<String> get _identifiers => const ['level', 'title', 'subtitle'];
  // @override
  final List<String> _identifiers = ['level', 'title', 'subtitle'];
  List<String> get baseCategories => _identifiers;

  Rule._internal({
    required String level,
    required String title,
    required String subtitle,
    required String explanation,
    required List<String> tags,
    required List<String> structures,
    required List<String> structuresOpp,
    required List<Sentence> sentences,
    required Dictionary characters,
    required Dictionary charactersOpp,
    super.specs,
  }) : level = level,
       title = title,
       subtitle = subtitle,
       explanation = explanation,
       tags = tags,
       structures = structures,
       structuresOpp = structuresOpp,
       sentences = sentences,
       characters = characters,
       charactersOpp = charactersOpp,
       super(
         entry: {
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
         },
       );

  factory Rule({
    String level = '',
    String title = '',
    String subtitle = '',
    String explanation = '',
    List<String> tags = const [],
    List<String> structures = const [],
    List<String> structuresOpp = const [],
    List<dynamic>? sentences,
    List<dynamic>? characters,
    List<dynamic>? charactersOpp,
    TextModifier<String>? mod,
  }) {
    final Map<String, Type> categories = {
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
    return Rule._internal(
      level: level.trim(),
      title: title.trim(),
      subtitle: subtitle.trim(),
      explanation: explanation.trim(),
      tags: List.from(tags),
      structures: List.from(structures),
      structuresOpp: List.from(structuresOpp),
      sentences: _listSentences(sentences, mod: mod),
      characters: Dictionary(characters: characters),
      charactersOpp: Dictionary(characters: charactersOpp),
      specs: categories,
    );
  }

  static List<Sentence> _listSentences(
    List<dynamic>? rawSentences, {
    TextModifier<String>? mod,
  }) {
    List<Sentence> sentenceList = [];
    if (rawSentences == null) return sentenceList;
    try {
      rawSentences = List<Sentence>.from(rawSentences);
      sentenceList = rawSentences
          .whereType<Sentence>()
          .toSet()
          .where((sts) => !sts.isEmpty)
          .toList();
    } catch (e) {
      for (final item in rawSentences!) {
        final stsMap = item as Map<String, dynamic>;
        final sts = Sentence(
          mod: mod ?? modifier,
          text: stsMap['text'] as String? ?? '',
          pinyin: stsMap['pinyin'] as String? ?? '',
          translation: stsMap['translation'] as String? ?? '',
        );
        if (!sts.isEmpty) sentenceList.add(sts);
      }
    }
    return sentenceList;
  }

  @override
  String toString() {
    return 'Level $level: $title';
  }

  @override
  Rule copy() {
    return Rule(
      level: level,
      title: title,
      subtitle: subtitle,
      tags: List<String>.from(tags),
      structures: List<String>.from(structures),
      structuresOpp: List<String>.from(structuresOpp),
      sentences: List<Sentence>.from(sentences),
      characters: List<Character>.from(characters.characters),
      charactersOpp: List<Character>.from(charactersOpp.characters),
    );
  }

  @override
  Character createInstance({
    Map<String, Type>? specs,
    Map<String, dynamic>? entry,
  }) {
    throw UnsupportedError('createInstance() is not available for Rule.');
  }

  @override
  Character copyWith({Map<String, Type>? specs, Map<String, dynamic>? entry}) {
    throw UnsupportedError('copyWith() is not available for Rule.');
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
  void set(String category, value, {bool force = true}) {
    if (value == null) {
      throw ArgumentError('Value for "$category" cannot be null');
    }
    super.set(category, value, force: force);
    if (sameTypes(categories[category]!, data[category].runtimeType)) {
      if (category == 'level') {
        level = data[category] as String;
      } else if (category == 'title') {
        title = data[category] as String;
      } else if (category == 'subtitle') {
        subtitle = data[category] as String;
      } else if (category == 'tags') {
        tags = data[category] as List<String>;
      } else if (category == 'structures') {
        structures = data[category] as List<String>;
      } else if (category == 'structuresOpp') {
        structuresOpp = data[category] as List<String>;
      } else if (category == 'sentences') {
        sentences = data[category] as List<Sentence>;
      } else if (category == 'characters') {
        characters = data[category] as Dictionary;
      } else if (category == 'charactersOpp') {
        charactersOpp = data[category] as Dictionary;
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
        (char) => modifier.set(char['simplified'] as String).toCleanRef().result,
      )
      .where((char) => char.isNotEmpty)
      .toList();

  List<String> get references => characters.characters
      .map(
        (char) => modifier.set(char['simplified'] as String).toCleanRef().result,
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
        ).linkPinyin();
        combined['sentences'] = combined['sentences'].map((Sentence sentence) {
          return sentence.applySyntax();
        }).toList();
        combined['other_characters'] = _referenceOthers(char);

        final newCategories = {
          ...categories,
          ...{'other_characters': List<String>, },
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
