import "utils.dart";
import "package:lexicon/lexicon/text_modifier.dart";
import "package:lexicon/lexicon/character.dart";
import "dart:io";
import "package:logging/logging.dart";
import 'package:collection/collection.dart';

final Logger _log = Logger('WriterLog');

Map<String, dynamic> getContSpecs(String container) {
  final RegExp outerPattern = RegExp(r'([^<]*?):\[(.*?)\]:([^>]*)');
  final RegExp innerPattern = RegExp(r'(\w*)\|(\w*)\|(\w*)');
  RegExpMatch? outerMatch = outerPattern.firstMatch(container);
  outerMatch =
      outerMatch ??
      outerPattern.firstMatch('H:[normal|normal|normal]:PLACEHOLDER ');
  if (outerMatch == null) throw Error();
  String? contSpecs = outerMatch.group(2);
  contSpecs = contSpecs ?? 'normal|normal|normal';
  RegExpMatch? innerMatch = innerPattern.firstMatch(contSpecs);
  innerMatch = innerMatch ?? innerPattern.firstMatch('normal|normal|normal');
  if (innerMatch == null) throw Error();
  if (outerMatch.allGroups.length != 3 || innerMatch.allGroups.length != 3) {
    throw Error();
  }
  return {
    'type': outerMatch.group(1)!.toUpperCase(),
    'specs': innerMatch.allGroups,
    'data': outerMatch.group(3),
  };
}

class ContentController {
  late Map<String, dynamic> specs;
  late String _font;
  late String _color;
  late String _visible;
  TextModifier<String> mod;

  ContentController(String container, TextModifier<String> mod) : mod = mod {
    specs = getContSpecs(container);
    if (specs['type'] != 'H') throw Error();

    final style = List<String>.from(specs['specs'] as List);
    _font = mod.getFullCommand(style[0]) ?? 'normal';
    _color = mod.getColor(style[1]) ?? '';
    _visible = mod.getFullCommand(style[2]) ?? 'visible';
  }

  bool get doContent {
    if (['hidden', 'ignore'].contains(_visible)) return false;
    if (['visible', 'available'].contains(_visible)) return true;
    return true;
  }

  bool doWrite(bool contentIsNotEmpty) {
    if (['visible'].contains(_visible)) return true;
    if (['ignore'].contains(_visible)) return false;
    if (['available', 'hidden'].contains(_visible)) return contentIsNotEmpty;
    return true;
  }

  String get writeHead {
    if (doContent) {
      mod.color = _color;
      return mod.set(specs['data']).applySyntaxCommands([
        _font,
        'color',
      ]).result;
    }
    return '';
  }

  String writeContent(String content) {
    if (doWrite(content.isNotEmpty) &&
        mod.set(content).findFirstChar('any').result != '') {
      content = writeHead + content;
      if (doContent) content += mod.getSyntax(cmd: 'newline')[0];
    } else {
      content = "";
    }
    return content;
  }
}

class Content {
  late dynamic _charCategoryContent;
  late Map<String, dynamic> specs;
  late Map<String, String> styleElements;
  late String type;
  final TextModifier<String> mod;

  Content(String container, Character character, TextModifier<String> mod)
    : mod = mod {
    specs = getContSpecs(container);
    _charCategoryContent = character.get(specs['data'] as String);
    type = specs['type'] as String;
    final style = List<String>.from(specs['specs'] as List);

    if (!['L', 'T', 'I'].contains(type[0])) {
      throw Error();
    } else if (type[0] == 'L') {
      styleElements = {
        'sep': mod.getFullCommand(style[0]) ?? 'normal',
        'bullet': mod.getSyntax(cmd: style[0]).isEmpty
            ? ''
            : mod.getSyntax(cmd: style[0])[0],
        'newline': mod.getFullCommand(style[1]) ?? 'normal',
        'size': mod.getFullCommand(style[2]) ?? 'normal', //
      };
    } else if (type[0] == 'T' || type[0] == 'I') {
      styleElements = {
        'font': mod.getFullCommand(style[0]) ?? 'normal',
        'color': mod.getColor(style[1]) ?? '',
        'size': mod.getFullCommand(style[2]) ?? 'normal', //
      };
    } else {
      styleElements = {};
    }
  }

  bool get doNewLine {
    if (styleElements.containsKey('newline')) {
      return styleElements['newline'] == 'newline';
    }
    return false;
  }

  String writeContent() {
    if (_charCategoryContent != null) {
      if (type.endsWith('LINK')) {
        _charCategoryContent = TextModifier(
          _charCategoryContent as Object,
          mod: mod,
        ).applySyntaxCommands(['link']).result;
      }
      if (type[0] == 'T' || type[0] == 'I') return _writeTextContent();
      if (type[0] == 'L') return _writeListContent();
    }
    return '';
  }

  String _writeTextContent() {
    if (_charCategoryContent == null) return "";
    if (type[0] == 'T' || type[0] == 'I') {
      mod.color = styleElements['color']!;

      final commands = [
        styleElements['size']!,
        styleElements['font']!,
        'color',
      ];
      final result = mod
          .set(_charCategoryContent.toString())
          .applySyntaxCommands(commands)
          .result;

      return result;
    }
    return "";
  }

  String _writeListContent() {
    String bullet = "";
    String nlSymb = mod.getSyntax(cmd: 'newline')[0];
    String strContent = "";
    if (_charCategoryContent == null) return strContent;
    if (_charCategoryContent is List && type[0] == 'L') {
      List<String> listContent = List<String>.from(
        _charCategoryContent as List,
      );
      listContent = listContent.where((item) => item.trim() != "").toList();
      if (styleElements['bullet'] != "") bullet = "${styleElements['bullet']} ";
      if (doNewLine) {
        strContent = listContent.join("$nlSymb$bullet");
      } else {
        strContent = listContent.join(" $bullet");
      }
      if (styleElements['sep'] == "point") strContent = "$bullet$strContent";
      return mod.set(strContent).applySyntaxCommands([
        styleElements['size']!,
      ]).result;
    }
    return _charCategoryContent.toString();
  }
}

class ContentBlock {
  late String content;
  late String command;
  late Character character;
  late TextModifier<String> mod;

  ContentBlock(this.character, {String? cmd, required TextModifier<String> mod})
    : content = "",
      mod = mod {
    command = mod.getFullCommand(cmd) ?? "";
  }

  String writeBlock(String content) {
    this.content = content;
    // String nlSymb = mod.getSyntax(cmd: 'newline')[0];
    if (mod.set(this.content).removeSyntax().result.trim().isEmpty) return "";
    // mod.set(this.content).strip(nlSymb);
    return mod.set(this.content).applySyntaxCommands([command, 'block']).result;
  }

  String writeContent(String template) {
    final writer = Writer(mod, template: template);
    writer.compile(character);
    return writeBlock(writer.text);
  }
}

class Writer {
  late String template;

  String _resultText = "";

  String _currentTmpl = "";
  ContentController? _currentHead;
  Content? _currentContent;
  ContentBlock? _currentBlock;
  String _currentLine = "";

  TextModifier<String> mod;
  Character? character;

  Writer(this.mod, {String? template, File? tmplFile}) {
    this.template = tmplFile != null ? _getTemplate(tmplFile) : template!;
    _currentTmpl = this.template;
  }

  String get text => _resultText;

  // ? replace('\n\n',' ').replace('\n',' ').replace('  ',' ')
  String get result => mod.set(_addChar + _resultText).linkPinyin().result;

  String get _addChar {
    if (character == null) return "";
    final e = ListEquality<String>();
    final bool hasBase = e.equals(character!.baseCategories, [
      'simplified',
      'traditional',
      'pinyin',
    ]);
    if (hasBase) {
      final String traditional = mod
          .set(character!['traditional'])
          .applySyntaxCommands(['bracket'])
          .result;
      final String pinyin = mod
          .set(character!['pinyin'])
          .toNumericPinyin()
          .result;
      final String simplified = character!['simplified'] as String;
      return "$simplified$traditional\t$pinyin\t";
    }
    return "";
  }

  static final Map<String, String> _mapInstructors = {'newline': '<N>'};

  String _getTemplate(File file, {bool keepNewline = false}) {
    if (getExtension(file) == '.chd') {
      if (file.existsSync()) {
        List<String> lines = file.readAsLinesSync();
        if (keepNewline) {
          lines = lines
              .map((l) => l.isEmpty ? _mapInstructors['newline']! : l)
              .toList();
        } else {
          lines = lines.where((l) => l.isNotEmpty).toList();
        }
        return lines.join('');
      }
      throw Error();
    }
    return '';
  }

  Writer compile(Character character) {
    this.character = character;
    _currentTmpl = template;
    _resultText = "";
    _getContainer();
    _currentHead = null;
    _currentContent = null;
    _currentBlock = null;
    _currentLine = "";
    return this;
  }

  RegExp rContainer = RegExp(r'.*?<(.*?)>(.*)');
  RegExp rBlock = RegExp(r'\{(.*?)\}(.*)');

  static final List<String> blocks = [
    'indent',
    'right',
    'left',
    'mark',
    'markline',
  ];

  void _getContainer() {
    if (_currentTmpl == "") return;
    final matchContainer = rContainer.firstMatch(_currentTmpl);
    if (matchContainer == null) return;

    String container = matchContainer.group(1) ?? '';
    _currentTmpl = matchContainer.group(2) ?? '';
    // final Map<String, dynamic> specs = getContSpecs(container);
    bool isController = (container.split(':').length > 1);

    if (isController) {
      // _log.info('Controller is $container');
      try {
        _currentHead = ContentController(container, mod);
      } catch (e) {
        _currentContent = Content(container, character!, mod);
        _currentLine += _currentContent!.writeContent();
      }
      _getContainer();
    } else {
      if (blocks.contains(container.toLowerCase())) {
        _currentBlock = ContentBlock(character!, mod: mod, cmd: container);
        final matchBlock = rBlock.firstMatch(_currentTmpl);
        if (matchBlock == null) throw Error();
        final String tmplBlock = matchBlock.group(1) ?? '';
        _currentTmpl = matchBlock.group(2) ?? '';
        _currentLine += _currentBlock!.writeContent(tmplBlock);
        _getContainer();
      } else if (container == 'E') {
        if (_currentHead == null) {
          _resultText += _currentLine;
        } else {
          _resultText += _currentHead!.writeContent(_currentLine);
        }
        _currentLine = "";
        _currentContent = null;
        _currentBlock = null;
        _getContainer();
      } else if (container.toLowerCase() == 'n') {
        final String nlSymbol = mod.getSyntax(cmd: 'newline')[0];
        if (container == 'N') _currentLine += nlSymbol;
        if (container == 'n') _currentLine += '\n';
        _getContainer();
      } else if (container == 'TAB') {
        final String tabSymbol = mod.getSyntax(cmd: 'tab')[0];
        _currentLine += tabSymbol;
        _getContainer();
      } else {
        if (!RegExp(r'\w').hasMatch(container)) _currentLine += container;
        _getContainer();
      }
    }
  }
}
