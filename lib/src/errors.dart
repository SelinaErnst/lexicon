/// Base class for errors raised by the lexicon package.
///
/// All package-specific exceptions extend this class so callers can either
/// catch one specific problem or catch every package error at once.
abstract class LexiconException implements Exception {
  /// A short explanation of what went wrong.
  final String message;

  /// Creates a package-specific exception with [message].
  const LexiconException(this.message);

  /// Returns the exception type and message as readable text.
  @override
  String toString() => '$runtimeType: $message';
}

/// Thrown when a requested character cannot be found in a dictionary.
class CharacterNotFoundException extends LexiconException {
  /// The identifier used to look up the character.
  final dynamic identifier;

  /// Creates an exception for a character that could not be found.
  const CharacterNotFoundException(this.identifier)
    : super('No character matching "$identifier" was found in the dictionary.');
}

/// Thrown when input cannot be converted into the required dictionary data.
class InvalidDictionaryDataException extends LexiconException {
  /// The kind of data that could not be processed.
  final String dataType;

  /// The runtime type of the provided input.
  final Type inputType;

  /// Creates an exception for invalid dictionary [dataType].
  const InvalidDictionaryDataException(this.dataType, this.inputType)
    : super(
        'Cannot initialize dictionary $dataType from input of type '
        '$inputType.',
      );
}

/// Thrown when a requested category is not part of a character schema.
class UnknownCategoryException extends LexiconException {
  /// The category that could not be found.
  final String category;

  /// Creates an exception for an unknown [category].
  const UnknownCategoryException(this.category)
    : super('Category "$category" does not exist.');
}

/// Thrown when a value does not match the type required by a category.
class CategoryTypeMismatchException extends LexiconException {
  /// The affected category.
  final String category;

  /// The type expected by the category schema.
  final Type expectedType;

  /// The runtime type that was actually supplied.
  final Type actualType;

  /// Creates a type-mismatch exception for [category].
  const CategoryTypeMismatchException(
    this.category,
    this.expectedType,
    this.actualType,
  ) : super(
        'Category "$category" expects $expectedType, but received '
        '$actualType.',
      );
}

/// Thrown when a required category is missing a value.
class MissingRequiredCategoryException extends LexiconException {
  /// The required category that is missing.
  final String category;

  /// Creates an exception for a missing required [category].
  const MissingRequiredCategoryException(this.category)
    : super('Required category "$category" is missing.');
}

/// Thrown when an input value is incompatible with the modifier's declared type.
class InvalidModifierInputException extends LexiconException {
  /// The type expected by the [TextModifier].
  final Type expected;

  /// The runtime type of the supplied input.
  final Type actual;

  /// Creates an exception describing an incompatible modifier input.
  const InvalidModifierInputException({
    required this.expected,
    required this.actual,
  }) : super(
         'TextModifier<$expected> '
         'cannot process input of type $actual.',
       );
}

/// Thrown when syntax-dependent formatting is requested before syntax exists.
class SyntaxNotConfiguredException extends LexiconException {
  /// Creates a syntax-configuration exception.
  const SyntaxNotConfiguredException()
    : super('Syntax has not been configured for this text modifier.');
}

/// Thrown when a requested identifier cannot be used for a dictionary lookup.
class InvalidIdentifierException extends LexiconException {
  /// The supplied identifier value.
  final Object? identifier;

  /// Creates an exception for [identifier].
  const InvalidIdentifierException(this.identifier)
    : super('Unsupported lookup identifier: $identifier.');
}

/// Thrown when a method or one of its supported options has no implementation.
class UnimplementedFeatureException extends LexiconException {
  /// The method or feature that is missing an implementation.
  final String method;

  /// The specific mode that has no implementation.
  final String? mode;

  /// Creates an exception for an unimplemented [method] or [mode].
  const UnimplementedFeatureException(this.method, {this.mode})
    : super(
        mode == null
            ? 'No implementation is available for "$method".'
            : 'No implementation is available for "$method" '
                  'with mode "$mode".',
      );
}

/// Thrown when an operation is not supported for a particular object type.
class UnsupportedOperationException extends LexiconException {
  /// The operation that cannot be performed.
  final String operation;

  /// The type of input that is not supported by the operation.
  final Type? inputType;

  /// Creates an exception for an unsupported [operation].
  const UnsupportedOperationException(this.operation, {this.inputType})
    : super(
        inputType == null
            ? 'The operation "$operation" is not supported.'
            : 'The operation "$operation" does not support '
                  'values of type $inputType.',
      );
}

/// Thrown when an argument parameter contains an invalid value.
class InvalidArgumentException extends LexiconException {
  /// The name of the argument containing the invalid value.
  final String parameter;

  /// The invalid value supplied for the argument.
  final Object? value;

  /// The valid values accepted for the argument, when applicable.
  final Iterable<Object>? options;

  /// The name of the function receiving the argument. final String function;
  final String function;

  /// Creates an exception for an invalid argument [value]
  ///
  /// [options] can be provided to specify the values accepted for the argument.
  InvalidArgumentException(
    this.parameter,
    this.value, {
    this.options,
    this.function = '',
  }) : super(
         options == null
             ? 'Invalid value for "$parameter": $value'
                   '${function.isEmpty ? "" : ' in $function'}.'
             : 'Invalid value for "$parameter": $value'
                   '${function.isEmpty ? '' : ' in $function'}. '
                   'Must be one of: ${options.join(', ')}.',
       );
}

/// Thrown when a required argument is missing.
class MissingArgumentException extends LexiconException {
  /// The name of the missing argument.
  final String parameter;

  /// The name of the function requiring the argument.
  final String function;

  /// The expected type of the argument, when known.
  final Type? expected;

  /// Creates an exception for a missing argument.
  MissingArgumentException(
    this.parameter, {
    this.function = '',
    this.expected,
  }) : super(
         'Missing required argument "$parameter"'
         '${function.isEmpty ? '' : ' for $function'}'
         '${expected == null ? '' : '. Expected type: $expected'}.',
       );
}

/// Thrown when a required dictionary file cannot be found.
class FileNotFoundException extends LexiconException {
  /// The path of the file that could not be found.
  final String path;

  /// Creates an exception for a missing file at [path].
  const FileNotFoundException(this.path)
    : super('Dictionary file was not found: "$path".');
}

/// Thrown when a dictionary file uses an unsupported format.
class UnsupportedFileFormatException extends LexiconException {
  /// The file format that is not supported.
  final String format;

  /// Creates an exception for an unsupported [format].
  const UnsupportedFileFormatException(this.format)
    : super('Dictionary file format "$format" is not supported.');
}

/// Thrown when dictionary data cannot be parsed from a supported file.
class DictionaryParseException extends LexiconException {
  /// The file that could not be parsed.
  final String path;

  /// Creates an exception for a parsing failure in [path].
  const DictionaryParseException(this.path)
    : super('Failed to parse dictionary data from "$path".');
}

/// Thrown when dictionary data cannot be written to a file.
class DictionaryWriteException extends LexiconException {
  /// The path of the file that could not be written.
  final String path;

  /// Creates an exception for a failed write operation.
  const DictionaryWriteException(this.path)
    : super('Failed to write dictionary data to "$path".');
}
