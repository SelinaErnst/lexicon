import 'text_modifier.dart';

class Sentence {
  String _text = '';
  String _pinyin = '';
  String _transl = '';

  String _processedPinyin = '';
  // String _txtCached = '';
  // String _markedText = '';

  final TextModifier<String> mod;

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

  String get text => _text;
  String get translation => _transl;
  String get pinyin => _processedPinyin;

  bool get isEmpty {
    if (_text.isEmpty && _transl.isEmpty && _pinyin.isEmpty) return true;
    return false;
  }

  @override
  String toString() {
    return 'Sentence: $text';
  }

  Map<String, String> toMap() {
    return {'text': text, 'pinyin': pinyin, 'translation': translation};
  }

  void addSyntax({
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) {
    mod.addSyntax(mapSyntax: mapSyntax, mapColor: mapColor, mapColorFav: mapColorFav);
  }

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
