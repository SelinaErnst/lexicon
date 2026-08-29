import 'text_modifier.dart';

/// Represents a sentence with text, Pinyin, and translation.
///
/// Input text is normalized during construction using the provided
/// [TextModifier].
class Sentence {
  /// Text modifier used to normalize and format sentence content.
  final TextModifier<String> mod;

  /// Returns the normalized sentence text.
  String get text => _text;
  String _text = '';

  /// Returns the normalized translation.
  String get translation => _transl;
  String _transl = '';

  /// Returns the processed, tone-marked Pinyin.
  String get pinyin => _processedPinyin;
  String _processedPinyin = '';
  String _pinyin = '';

  /* ================================================================ */
  /*                            CONSTRUCTOR                           */
  /* ================================================================ */

  /// Creates a sentence from text, Pinyin, and translation.
  ///
  /// The text is cleaned as Chinese content, the Pinyin is normalized
  /// to numeric form and processed into tone-marked Pinyin, and the
  /// translation is cleaned as English text.
  Sentence({
    String text = '',
    String pinyin = '',
    String translation = '',
    TextModifier<String>? mod,
  }) : mod = mod ?? TextModifier<String>('') {
    _text = text;
    _text = this.mod
        .set(_text)
        .removeSyntax()
        .toCleanLanguage('chinese')
        .result
        .trim();

    _pinyin = pinyin;
    _pinyin = this.mod
        .set(_pinyin)
        .removeSyntax()
        .toCleanLanguage('english')
        .toNumericPinyin()
        .result
        .trim();
    _processedPinyin = this.mod.toToneMarkedPinyin().result.trim();

    _transl = translation;
    _transl = this.mod.set(_transl).toCleanLanguage('english').result;
  }

  /// Whether the sentence contains no text, Pinyin, or translation.
  bool get isEmpty {
    if (_text.isEmpty && _transl.isEmpty && _pinyin.isEmpty) return true;
    return false;
  }

  /* –––––––––––––––––––––––– representation –––––––––––––––––––––––– */

  /// Returns a short textual representation using the sentence text.
  @override
  String toString() {
    return 'Sentence: $text';
  }

  /// Converts the sentence into a map representation.
  Map<String, String> toMap() {
    return {'text': text, 'pinyin': pinyin, 'translation': translation};
  }

  /* –––––––––––––––––––––––––––– syntax –––––––––––––––––––––––––––– */

  /// Adds syntax and color configuration to the sentence's modifier.
  void addSyntax({
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) {
    mod.addSyntax(
      mapSyntax: mapSyntax,
      mapColor: mapColor,
      mapColorFav: mapColorFav,
    );
  }

  /// Applies the configured syntax to the sentence.
  ///
  /// Returns the formatted sentence with its available components
  /// joined according to the configured newline syntax.
  String applySyntax({String color = 'grey'}) {
    mod.set(pinyin);
    mod.color = color;
    mod.command = 'newline';
    final synNewLine = mod.getSyntax()[0];
    final synPinyin = mod.applySyntaxCommands(['color']).result;
    final List<String> result = [text, synPinyin, translation];
    result.removeWhere((item) => item.isEmpty);
    return '${result.join(synNewLine)}$synNewLine';
  }
}
