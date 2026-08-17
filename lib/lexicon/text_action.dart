import 'package:logging/logging.dart';

final Logger _log = Logger('TextActEngine');

class TextAction<T extends Object> {
  T _input;
  T result;
  String? _fullCommand;
  String? _colorVal;

  Map<String, dynamic>? mapSyntax;
  Map<String, dynamic>? mapColor;
  Map<String, dynamic>? mapColorFav;

  TextAction? _actString;

  TextAction(this._input, {this.mapColor, this.mapSyntax, this.mapColorFav})
    : result = _input,
      _fullCommand = null,
      _colorVal = null;

  TextAction<T> setSyntax({
    Map<String, dynamic>? mapSyntax,
    Map<String, dynamic>? mapColor,
    Map<String, dynamic>? mapColorFav,
  }) {
    this.mapSyntax = mapSyntax;
    this.mapColor = mapColor;
    this.mapColorFav = mapColorFav;
    return this;
  }

  bool _hasSyntax() => mapColor != null && mapSyntax != null;

  void _warnMissingSyntax() {
    if (!_hasSyntax()) throw AssertionError('Syntax has not been added yet.');
  }
  // void  _warnMissingFavourites(){
  //   if (!_hasSyntax()) throw AssertionError('Favourite Colors have not been added yet.');
  // }

  TextAction<T> set(T input, {String? command, String? color}) {
    _input = input;
    result = input;
    if (command != null) _fullCommand = getFullCommand(command);
    if (color != null) _colorVal = _getColor(color);
    return this;
  }

  T get input => _input;

  TextAction<String> get actString {
    if (_actString == null) {
      _actString = TextAction<String>(
        '',
        mapSyntax: mapSyntax,
        mapColor: mapColor,
      );
    } else if (!_actString!._hasSyntax()) {
      _actString!.setSyntax(
        mapColor: mapColor,
        mapSyntax: mapSyntax,
        mapColorFav: mapColorFav,
      );
    }
    _actString!.set('', command: command, color: color);
    return _actString as TextAction<String>;
  }

  /* ================================================================ */
  /*                            ATTRIBUTES                            */
  /* ================================================================ */

  static final String _defaultCommand = 'normal';
  static final String _colorCommand = 'color';

  set command(String newCommand) => _fullCommand = getFullCommand(newCommand);

  String? get command {
    final currentCommand = _fullCommand;
    if (currentCommand == null) return null;
    if (currentCommand == _defaultCommand) return _defaultCommand;
    return currentCommand;
  }

  String? getFullCommand(String? cmd) {
    if (cmd == null || cmd == _defaultCommand) {
      return cmd;
    }

    _warnMissingSyntax();

    for (final commandSyntax in mapSyntax!.entries) {
      if (cmd == commandSyntax.key) return commandSyntax.key;
      final dynamic commandInfo = commandSyntax.value;
      if (commandInfo is Map && commandInfo.containsKey('caller')) {
        final dynamic caller = commandInfo['caller'];
        if (caller is List) {
          if (caller.contains(cmd)) return commandSyntax.key;
        }
      }
    }
    throw ArgumentError('Invalid command "$cmd".');
  }

  bool _isCommand(String? fullCommand) {
    if (fullCommand == null) return false;
    _warnMissingSyntax();
    if (mapSyntax!.containsKey(fullCommand)) return true;
    return false;
  }

  List<String> getSyntax({String? cmd}) {
    String? targetedCommand;
    if (cmd != null) {
      targetedCommand = getFullCommand(cmd);
    } else {
      targetedCommand = _fullCommand;
    }

    if (_isCommand(targetedCommand)) {
      _warnMissingSyntax();
      return List<String>.from(
        mapSyntax![targetedCommand]['syntax'] as List<dynamic>,
      );
    }
    _log.warning('Could not get syntax from command "$command"');
    return [];
  }

  String? get color => _colorVal;

  set color(String newColor) => _colorVal = _getColor(newColor);

  String? _getColor(String? col) {
    if (col == null) return null;
    if (_isColor(col)) return col;
    if (_isFavColor(col)) {
      _warnMissingSyntax();
      col = mapColorFav![col] as String;
    }
    if (_isColorName(col)) {
      _warnMissingSyntax();
      final colorVal = mapColor![col] as String;
      return colorVal;
    }
    throw ArgumentError('Invalid color "$col".');
  }

  bool _isColor(String col) {
    _warnMissingSyntax();
    if (mapColor!.containsValue(col)) return true;
    return false;
  }

  bool _isColorName(String col) {
    _warnMissingSyntax();
    if (mapColor!.containsKey(col)) return true;
    if (mapColorFav is Map && mapColorFav!.containsKey(col)) return true;
    return false;
  }

  bool _isFavColor(String col) {
    if (mapColorFav is Map && mapColorFav!.containsKey(col)) return true;
    return false;
  }

  String _frameText(String text, List<String> syntax) {
    String framedText = text;
    if (syntax.length == 2) {
      framedText = '${syntax.first}$framedText${syntax.last}';
    } else if (syntax.length == 1) {
      framedText = '${syntax.first}$framedText';
    }
    return framedText;
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

  TextAction<T> applySyntax({List<String> commandList = const []}) {
    result = _process((text) {
      if (commandList.isEmpty) {
        return actString.set(text, command: _fullCommand).applyCommand().result;
      }
      return actString.set(text).applySyntaxCommands(commandList).result;
    }, ignoreEmpty: false);
    return this;
  }

  TextAction<T> applyCommand() {
    result = _process((text) {
      final List<String> activeSyntax = getSyntax(cmd: command);
      final activeColor = color;
      if (text.isEmpty) return text;
      String processed = text;
      if (command == _colorCommand && activeColor != null) {
        processed = '$activeColor$processed';
      }
      processed = _frameText(processed, activeSyntax);
      return processed;
    });
    return this;
  }

  TextAction<T> applySyntaxCommands(dynamic commands) {
    result = _process((text) {
      String applied = text;
      if (commands is List) {
        for (final String cmd in commands as List<String>) {
          applied = actString.set(applied, command: cmd).applyCommand().result;
        }
      } else {
        applied = actString
            .set(applied, command: commands as String)
            .applyCommand()
            .result;
      }
      return applied;
    });
    return this;
  }
}
