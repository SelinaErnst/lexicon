import "package:logging/logging.dart";
import 'package:collection/collection.dart';
import "dart:io";
import "utils.dart";
import "errors.dart";
import "text_modifier.dart";
import "character.dart";

final Logger _log = Logger('WriterLog');

final _containerType = {'H', 'L', 'T', 'I'};

/// a class that writes a character to string
/// using a .chd template and given syntax commands / colors
/// goal is to create a Pleco compatibel .txt file
class Writer {
  /// template that decides on font styles, colors, etc.
  late String template;

  /// contains Syntax
  TextModifier<String> mod;

  /// contains content (accessible by category)
  Character? character;

  /// raw result of Writer
  String get text => _resultText;

  /// processing text result for Pleco compatibility
  String get result => mod.set(_addChar + text).linkPronunciation().result;
  // replace('\n\n',' ').replace('\n',' ').replace('  ',' ')  ?

  String _resultText = "";
  String _currentTmpl = "";
  ContentController? _currentHead;
  Content? _currentContent;
  ContentBlock? _currentBlock;
  String _currentLine = "";

  static final Map<String, String> _mapInstructors = {'newline': '<N>'};

  /// looks for first container <...>
  static final RegExp _rContainer = RegExp(r'.*?<(.*?)>(.*)');

  /// looks for first content block {...}
  static final RegExp _rBlock = RegExp(r'\{(.*?)\}(.*)');

  /// all commands that decide block position / style
  static final List<String> _blocks = [
    'indent',
    'right',
    'left',
    'mark',
    'markline',
  ];

  /// constructor can be given the template as a .chd file
  Writer(this.mod, {String? template, File? tmplFile}) {
    this.template = tmplFile != null ? _getTemplate(tmplFile) : template!;
    _currentTmpl = this.template;
  }

  /// adds character information
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

  /// template file is read and returend as string
  /// IMPORTANT: keepNewline decides whether empty lines in template will be ignored or not
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
      throw FileNotFoundException(file.path);
    }
    return '';
  }

  /// take character and update _resultText
  Writer compile(Character character) {
    _log.fine(
      'Compile for character $character. Type: ${character.runtimeType}',
    );
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

  /// looks up containers step by step and writes content to _resultText
  void _getContainer() {
    if (_currentTmpl == "") return;
    final matchContainer = _rContainer.firstMatch(_currentTmpl);
    if (matchContainer == null) return;

    String container = matchContainer.group(1) ?? '';
    _currentTmpl = matchContainer.group(2) ?? '';
    bool isController = (container.split(':').length > 1);

    _log.finer('Write Container: $container');

    if (isController) {
      try {
        _currentHead = ContentController(container, mod);
      } catch (e) {
        _currentContent = Content(container, character!, mod);
        _currentLine += _currentContent!.writeContent();
      }
      _getContainer();
    } else {
      if (_blocks.contains(container.toLowerCase())) {
        _currentBlock = ContentBlock(character!, mod: mod, cmd: container);
        final matchBlock = _rBlock.firstMatch(_currentTmpl);
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

/// class that is initiated by container type H
/// controlls visibility of subsequent content / content blocks
class ContentController {
  final TextModifier<String> _mod;
  late Map<String, dynamic> _specs;
  late String _font;
  late String _color;
  late String _visible;

  /// constructor also receives TextModifier as input which should have neccessary Syntax
  ContentController(String container, TextModifier<String> mod) : _mod = mod {
    _specs = getContSpecs(container, 'H');
    if (_specs['type'] != 'H') throw Error();

    final style = List<String>.from(_specs['specs'] as List);
    _font = mod.getFullCommand(style[0]) ?? 'normal';
    _color = mod.getColor(style[1]) ?? '';
    _visible = mod.getFullCommand(style[2]) ?? 'visible';
  }

  /// Header is only seen in certain cases
  bool get _doHeader {
    if (['hidden', 'ignore'].contains(_visible)) return false;
    if (['visible', 'available'].contains(_visible)) return true;
    return true;
  }

  /// in some cases, the content decides whether the entire line is written
  bool _doWrite(bool contentIsNotEmpty) {
    if (['visible', 'ignore'].contains(_visible)) return _doHeader;
    if (['available', 'hidden'].contains(_visible)) return contentIsNotEmpty;
    return true;
  }

  /// write Header using specs from container
  String get _writeHead {
    if (_doHeader) {
      _mod.color = _color;
      return _mod.set(_specs['data']).applySyntaxCommands([
        _font,
        'color',
      ]).result;
    }
    return '';
  }

  /// write (Header +) content depending on visibility (container spec)
  String writeContent(String content) {
    if (_doWrite(content.isNotEmpty) &&
        _mod.set(content).findFirstChar('any').result != '') {
      content = _writeHead + content;
      if (_doHeader) content += _mod.getSyntax(cmd: 'newline')[0];
    } else {
      content = "";
    }
    _log.fine('Write Head and Content: $content');
    return content;
  }
}

/// class that decides how to write content given the container
class Content {
  late dynamic _charCategoryContent;
  late Map<String, dynamic> _specs;
  late Map<String, String> _styleElements;
  late String _type;
  final TextModifier<String> _mod;

  /// constructor receives character which stores content of certain category
  /// IMPORTANT: category should be mentioned in container
  Content(String container, Character character, TextModifier<String> mod)
    : _mod = mod {
    _specs = getContSpecs(container, 'T');
    _charCategoryContent = character.get(_specs['data'] as String);
    _type = _specs['type'] as String;
    final style = List<String>.from(_specs['specs'] as List);

    if (!['L', 'T', 'I'].contains(_type[0])) {
      throw Error();
    } else if (_type[0] == 'L') {
      _styleElements = {
        'sep': _mod.getFullCommand(style[0]) ?? 'normal',
        'bullet': _mod.getSyntax(cmd: style[0]).isEmpty
            ? ''
            : _mod.getSyntax(cmd: style[0])[0],
        'newline': _mod.getFullCommand(style[1]) ?? 'normal',
        'size': _mod.getFullCommand(style[2]) ?? 'normal', //
      };
    } else if (_type[0] == 'T' || _type[0] == 'I') {
      _styleElements = {
        'font': _mod.getFullCommand(style[0]) ?? 'normal',
        'color': _mod.getColor(style[1]) ?? '',
        'size': _mod.getFullCommand(style[2]) ?? 'normal', //
      };
    } else {
      _styleElements = {};
    }
  }

  /// Content can be written with a newline for each element
  bool get _doNewLine {
    if (_styleElements.containsKey('newline')) {
      return _styleElements['newline'] == 'newline';
    }
    return false;
  }

  /// write content based on container type
  /// L: list, T: text, I: integer
  String writeContent() {
    _log.finer('Write Content of type: $_type');

    if (_charCategoryContent != null) {
      /// each element of content will be framed as a link
      if (_type.endsWith('LINK')) {
        _charCategoryContent = TextModifier(
          _charCategoryContent as Object,
          mod: _mod,
        ).applySyntaxCommands(['link']).result;
      }
      if (_type[0] == 'T' || _type[0] == 'I') return _writeTextContent();
      if (_type[0] == 'L') return _writeListContent();
    }
    return '';
  }

  /// container type T: text & I: integer
  String _writeTextContent() {
    if (_charCategoryContent == null) return "";
    if (_type[0] == 'T' || _type[0] == 'I') {
      _mod.color = _styleElements['color']!;

      final commands = [
        _styleElements['size']!,
        _styleElements['font']!,
        'color',
      ];
      final result = _mod
          .set(_charCategoryContent.toString())
          .applySyntaxCommands(commands)
          .result;

      return result;
    }
    return "";
  }

  /// container type L: list
  String _writeListContent() {
    String bullet = "";
    String nlSymb = _mod.getSyntax(cmd: 'newline')[0];
    String strContent = "";
    if (_charCategoryContent == null) return strContent;
    if (_charCategoryContent is List && _type[0] == 'L') {
      List<String> listContent = List<String>.from(
        _charCategoryContent as List,
      );
      listContent = listContent.where((item) => item.trim() != "").toList();
      if (_styleElements['bullet'] != "") {
        bullet = "${_styleElements['bullet']} ";
      }
      if (_doNewLine) {
        strContent = listContent.join("$nlSymb$bullet");
      } else {
        strContent = listContent.join(" $bullet");
      }
      if (_styleElements['sep'] == "point") strContent = "$bullet$strContent";
      return _mod.set(strContent).applySyntaxCommands([
        _styleElements['size']!,
      ]).result;
    }
    return _charCategoryContent.toString();
  }
}

/// class that can contain ContentController & Content
/// IMPORTANT: ContentBlock can also be controlled by ContentController
class ContentBlock {
  final Character _character;
  final TextModifier<String> _mod;
  late String _content;
  final String _command;

  /// ContentBlock is similar to Content in needing character that stores the actual content
  /// cmd / command is the container value that decides how the content block is written
  ContentBlock(
    Character character, {
    String? cmd,
    required TextModifier<String> mod,
  }) : _content = "",
       _mod = mod,
       _command = mod.getFullCommand(cmd) ?? "",
       _character = character;

  /// Block will only be written if there is content to be shown
  String writeBlock(String content) {
    _content = content;
    // String nlSymb = _mod.getSyntax(cmd: 'newline')[0];
    if (_mod.set(_content).removeSyntax().result.trim().isEmpty) return "";
    // _mod.set(_content).strip(nlSymb);
    return _mod.set(_content).applySyntaxCommands([_command, 'block']).result;
  }

  /// takes in a substring of template that is the content block {...}
  String writeContent(String template) {
    _log.finer('Write Block: $_command');

    final writer = Writer(_mod, template: template);
    writer.compile(_character);
    return writeBlock(writer.text);
  }
}

/// creates a container with default values
String getDefaultContainer({String type = '', bool onlySpecs = false}) {
  _log.finest('Get default for Container type $type');
  if (onlySpecs) return 'normal|normal|normal';
  isValid(type[0], _containerType);
  return '$type:[normal|normal|normal]:PLACEHOLDER ';
}

/// get all information from the container (including specs for font styles)
Map<String, dynamic> getContSpecs(String container, String type) {
  final RegExp outerPattern = RegExp(r'([^<]*?):\[(.*?)\]:([^>]*)');
  final RegExp innerPattern = RegExp(r'(\w*)\|(\w*)\|(\w*)');
  RegExpMatch? outerMatch = outerPattern.firstMatch(container);
  outerMatch =
      outerMatch ?? outerPattern.firstMatch(getDefaultContainer(type: type));
  if (outerMatch == null) throw Error();
  String? contSpecs = outerMatch.group(2);
  contSpecs = contSpecs ?? getDefaultContainer(onlySpecs: true);
  RegExpMatch? innerMatch = innerPattern.firstMatch(contSpecs);
  innerMatch =
      innerMatch ??
      innerPattern.firstMatch(getDefaultContainer(onlySpecs: true));
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
