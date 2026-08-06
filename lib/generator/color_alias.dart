/*
 * Copyright (c) 2024. AQoong(cooldnjsdn@gmail.com) All rights reserved.
 */

import 'palette_exception.dart';

final _separators = RegExp(r'[^A-Za-z0-9]+');
final _hasLetter = RegExp(r'[A-Za-z]');
final _leadingDigit = RegExp(r'^[0-9]');

/// Must start with a letter: a leading `_` would make the member private to the
/// generated file, and a leading `$` is legal but not something anyone means.
final _explicitIdentifier = RegExp(r'^[A-Za-z][A-Za-z0-9_$]*$');

/// Names that cannot be used for a `static const` member of a class: Dart
/// reserved words, built-in identifiers, and the `Object` members a static
/// member is not allowed to shadow.
const _unusableNames = <String>{
  // Reserved words.
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue', 'default',
  'do', 'else', 'enum', 'extends', 'false', 'final', 'finally', 'for', 'if',
  'in', 'is', 'new', 'null', 'rethrow', 'return', 'super', 'switch', 'this',
  'throw', 'true', 'try', 'var', 'void', 'while', 'with',
  // Built-in and contextual identifiers.
  'abstract', 'as', 'async', 'augment', 'await', 'base', 'covariant',
  'deferred', 'dynamic', 'export', 'external', 'factory', 'function', 'get',
  'hide', 'implements', 'import', 'interface', 'late', 'library', 'mixin',
  'on', 'operator', 'part', 'required', 'sealed', 'set', 'show', 'static',
  'sync', 'typedef', 'when', 'yield',
  // Object members — a static member may not share their name.
  'hashCode', 'noSuchMethod', 'runtimeType', 'toString',
};

/// Turns a designer alias into a valid Dart identifier.
///
/// The rule is deliberately small enough to state in one sentence to whoever
/// maintains the CSV: *every non-alphanumeric run is a word boundary, and the
/// words become lowerCamelCase.* So `text/primary` becomes `textPrimary`,
/// `gray-100` becomes `gray100`, `Blue Gray 50` becomes `blueGray50`, and an
/// alias that is already camelCase — `brandAccentSubtle` — comes out unchanged.
///
/// The point is not that the alias is reproduced verbatim; it is that the
/// mapping is predictable in both directions, so a designer and a developer can
/// agree on it without either of them reading this code.
///
/// A `color` prefix is added only when it is unavoidable (the alias starts with
/// a digit, or would collide with a Dart keyword or a name in [avoid]) or when
/// [colorPrefix] asks for it.
String aliasToIdentifier(
  String alias, {
  bool colorPrefix = false,
  Set<String> avoid = const <String>{},
}) {
  final words = splitWords(alias);
  if (words.isEmpty) {
    throw PaletteFormatException(
      'No Dart name can be derived from the alias "$alias" — Dart identifiers '
      'are ASCII only. Give this row a "code" column value, or ask for an '
      'alias that contains letters or digits.',
    );
  }

  final head = words.first;
  var identifier = head[0].toLowerCase() + head.substring(1);
  for (final word in words.skip(1)) {
    identifier += capitalize(word);
  }

  if (colorPrefix ||
      _leadingDigit.hasMatch(identifier) ||
      _unusableNames.contains(identifier) ||
      avoid.contains(identifier)) {
    identifier = 'color${capitalize(identifier)}';
  }
  // Only reachable when `colorPrefix` is on and the prefixed name is taken.
  if (avoid.contains(identifier)) {
    identifier = '${identifier}Color';
  }
  return identifier;
}

/// Checks a member name written explicitly in the CSV's code column.
///
/// Unlike [aliasToIdentifier] this does not massage the input. Somebody chose
/// this name on purpose, so a name that will not compile is reported rather than
/// quietly rewritten.
String validateExplicitIdentifier(String code) {
  if (!_explicitIdentifier.hasMatch(code)) {
    throw PaletteFormatException(
      'The code "$code" is not usable as a Dart member name. It has to start '
      'with a letter and contain only letters, digits and underscores.',
    );
  }
  if (_unusableNames.contains(code)) {
    throw PaletteFormatException(
      'The code "$code" is a Dart keyword or a member of Object, so it cannot '
      'name a color.',
    );
  }
  return code;
}

/// Derives the palette class name from the CSV file name.
///
/// `semantic_light.csv` becomes `SemanticLight`.
String classNameForFileName(String fileName) {
  var name = fileName;
  if (name.toLowerCase().endsWith('.csv')) {
    name = name.substring(0, name.length - '.csv'.length);
  }

  final words = splitWords(name);
  if (words.isEmpty) return 'ColorPalette';

  final className = words.map(capitalize).join();
  return _leadingDigit.hasMatch(className) ? 'Palette$className' : className;
}

/// Splits on every non-alphanumeric run — `/`, `-`, `_`, `.` and whitespace all
/// act as word boundaries, which covers how design tools export token names.
///
/// SCREAMING_CASE words are folded to lower case so `TEXT/PRIMARY` and
/// `text/primary` produce the same identifier; mixed-case words are left alone
/// so an alias that is already camelCase does not get re-cased.
List<String> splitWords(String value) {
  return value
      .split(_separators)
      .where((word) => word.isNotEmpty)
      .map((word) => word == word.toUpperCase() && _hasLetter.hasMatch(word)
          ? word.toLowerCase()
          : word)
      .toList();
}

/// Upper-cases the first character only, leaving the rest of [word] alone.
String capitalize(String word) =>
    word.isEmpty ? word : word[0].toUpperCase() + word.substring(1);
