import 'text_modifier.dart';

class Sentence {
  String _text = '';
  String _pinyin = '';
  String _transl = '';

  String _processedPinyin = '';
  // String _txtCached = '';
  // String _markedText = '';

  final TextModifier<String> mod;

  // static final RegExp _bracketPattern = RegExp(r'[《》〈〉]');

  Sentence({
    String text = '',
    String pinyin = '',
    String translation = '',
    required this.mod,
  }) {
    _text = text;
    _text = mod.set(_text).toCleanLanguage('chinese').result;

    _pinyin = pinyin;
    _pinyin = mod.set(_pinyin).toCleanLanguage('english').toNumericPinyin().result;
    _processedPinyin = mod.toToneMarkedPinyin().result;

    _transl = translation;
    _transl = mod.set(_transl).toCleanLanguage('english').result;
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

  String applySyntax({String color = 'grey'}) {
    mod.set(pinyin);
    mod.act.color = color;
    mod.act.command = 'newline';
    final synNewLine = mod.act.getSyntax()[0];
    final synPinyin = mod.act.applySyntaxCommands(['color']).result as String;
    final List<String> result = [text, synPinyin, translation];
    result.removeWhere((item) => item.isEmpty);
    return '${result.join(synNewLine)}$synNewLine';
  }
}
