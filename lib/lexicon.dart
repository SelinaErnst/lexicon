/// A pure Dart package for background character dictionaries and grammar rules.
library lexicon;

export 'src/dictionary.dart';
export 'src/character.dart';
export 'src/rule.dart';
export 'src/sentence.dart';
export 'src/text_modifier.dart';

export 'src/dictionary_io.dart'
    if (dart.library.html) 'src/dictionary_io_stub.dart';
    // if (dart.library.js_interop) 'src/dictionary_io_stub.dart';