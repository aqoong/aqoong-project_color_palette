/*
 * Copyright (c) 2024. AQoong(cooldnjsdn@gmail.com) All rights reserved.
 */

import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:dart_style/dart_style.dart';

import 'color_alias.dart';
import 'hex_color.dart';
import 'palette_exception.dart';
import 'palette_options.dart';

/// Name of the generated alias lookup map.
const aliasMapName = 'byAlias';

const _utf8Bom = <int>[0xEF, 0xBB, 0xBF];

/// Header labels understood for each column, normalised by [_normalizeHeader].
const _nameHeaders = <String>{'name', 'alias', 'token', 'key', 'colorname'};
const _valueHeaders = <String>{
  'value',
  'hex',
  'hexcode',
  'color',
  'colour',
  'colorvalue',
};
const _codeHeaders = <String>{
  'code',
  'codename',
  'dart',
  'dartname',
  'identifier',
  'member',
};
const _commentHeaders = <String>{
  'comment',
  'comments',
  'description',
  'desc',
  'memo',
  'note',
  'remark',
};

/// Recognised theme mode columns, mapped to the Dart name they get.
///
/// A CSV that uses these instead of a single `value` column describes one color
/// per mode per row, which is how a designer looks at light and dark: side by
/// side, not in two files that have to be kept in step.
const _modeHeaders = <String, String>{
  'light': 'light',
  'lightmode': 'light',
  'day': 'light',
  'dark': 'dark',
  'darkmode': 'dark',
  'night': 'dark',
};

/// Members the generated `ThemeExtension` defines itself.
const _extensionMembers = <String>{'of', 'copyWith', 'lerp'};

final _whitespaceRun = RegExp(r'\s+');
final _headerNoise = RegExp(r'[\s_\-/.]');

final _formatter = DartFormatter(
  languageVersion: DartFormatter.latestLanguageVersion,
);

/// Runs the generated source through `dart_style`.
///
/// Two reasons, and the second one matters more: the output is canonical no
/// matter how long the color names are, so `dart format` in the consuming
/// project leaves it alone; and the formatter has to parse the source first, so
/// a generator that emits broken Dart fails here instead of in somebody else's
/// compile step. The brace bug this package shipped in 1.0.x would not have
/// survived a single build.
String _formatSource(String source) {
  try {
    return _formatter.format(source);
  } on FormatterException catch (error) {
    throw PaletteFormatException(
      'The generated Dart could not be parsed, which makes this a bug in '
      'project_color_palette rather than a problem with the CSV. '
      'Please report it.\n$error',
    );
  }
}

/// Decodes raw CSV bytes as UTF-8, tolerating a byte order mark.
///
/// Excel — Korean Excel in particular — defaults to a legacy code page rather
/// than UTF-8, so a decode failure gets a message that says how to fix the
/// file instead of a bare `FormatException`.
String decodeCsvBytes(List<int> bytes) {
  if (bytes.length >= 2 &&
      ((bytes[0] == 0xFF && bytes[1] == 0xFE) ||
          (bytes[0] == 0xFE && bytes[1] == 0xFF))) {
    throw PaletteFormatException(
      'The CSV starts with a UTF-16 byte order mark. Re-save it as '
      '"CSV UTF-8 (Comma delimited)".',
    );
  }

  var data = bytes;
  if (data.length >= 3 &&
      data[0] == _utf8Bom[0] &&
      data[1] == _utf8Bom[1] &&
      data[2] == _utf8Bom[2]) {
    data = data.sublist(3);
  }

  try {
    return const Utf8Decoder().convert(data);
  } on FormatException catch (error) {
    throw PaletteFormatException(
      'The CSV is not valid UTF-8 (${error.message}). Excel saves CSV in a '
      'legacy code page by default (CP949 on Korean Windows); re-save it as '
      '"CSV UTF-8 (Comma delimited)".',
    );
  }
}

/// Turns one CSV palette into Dart source.
///
/// Deliberately free of `build` and `dart:io` so the whole generator can be
/// exercised by plain unit tests — the multi-color brace bug this replaces
/// existed because nothing but a single-row example ever ran through it.
class PaletteSourceBuilder {
  PaletteSourceBuilder({this.options = const PaletteOptions()});

  final PaletteOptions options;

  String build({
    required String csvFileName,
    required String csvContent,
    void Function(String message)? onWarning,
  }) {
    final rows = _parseRows(csvContent);
    final baseName = classNameForFileName(csvFileName);

    if (rows.isEmpty) {
      onWarning?.call('The CSV is empty; generating an empty palette.');
      return _formatSource(_render(
        csvFileName: csvFileName,
        baseName: baseName,
        modes: const [_Mode(name: '', index: 1)],
        entries: const <_ColorEntry>[],
      ));
    }

    final columns = _resolveColumns(rows.first, onWarning);
    final modes = columns.modes;
    final entries = <_ColorEntry>[];
    final takenAliases = <String>{};
    final takenNames = <String, String>{};
    final reserved = _reservedNames(baseName, modes);

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      // Row numbers are 1-based and include the header, matching what the
      // designer sees in the spreadsheet.
      final rowNumber = i + 1;

      final alias = _cell(row, columns.name);
      final code = columns.code == null ? '' : _cell(row, columns.code!);
      final comment =
          columns.comment == null ? '' : _cell(row, columns.comment!);
      final values = [for (final mode in modes) _cell(row, mode.index)];

      // Spreadsheets happily export trailing `,,,` rows; those are not errors.
      if (alias.isEmpty && values.every((value) => value.isEmpty)) continue;
      if (alias.isEmpty) {
        throw PaletteFormatException(
          'row $rowNumber: the color value "${values.join(', ')}" has no name.',
        );
      }
      // A duplicate alias would also produce a duplicate `byAlias` key, which
      // is a compile error in a const map.
      if (!takenAliases.add(alias)) {
        throw PaletteFormatException(
          'row $rowNumber: the alias "$alias" appears more than once.',
        );
      }

      final literals = <String>[];
      for (var m = 0; m < modes.length; m++) {
        final mode = modes[m];
        if (values[m].isEmpty) {
          throw PaletteFormatException(
            'row $rowNumber: "$alias" has no '
            '${mode.name.isEmpty ? '' : '${mode.name} '}value.',
          );
        }
        try {
          literals.add(hexToArgbLiteral(
            values[m],
            alphaPosition: options.hexAlphaPosition,
          ));
        } on PaletteFormatException catch (error) {
          throw PaletteFormatException(
            'row $rowNumber'
            '${mode.name.isEmpty ? '' : ' (${mode.name})'}: ${error.message}',
          );
        }
      }

      // A `code` value is a name the designer and the developer agreed on, so
      // it wins over the derived one and is taken literally.
      final String identifier;
      try {
        identifier = code.isEmpty
            ? aliasToIdentifier(
                alias,
                colorPrefix: options.colorPrefix,
                avoid: reserved,
              )
            : validateExplicitIdentifier(code);
      } on PaletteFormatException catch (error) {
        throw PaletteFormatException('row $rowNumber: ${error.message}');
      }

      if (reserved.contains(identifier)) {
        throw PaletteFormatException(
          'row $rowNumber: the code "$identifier" is already used by the '
          'generated palette itself. Pick a different one.',
        );
      }

      // Two aliases landing on one Dart name is reported, never silently
      // renamed: an auto-generated fallback name is not one anybody would
      // guess, and one of the two colors would look like it went missing.
      final previous = takenNames[identifier];
      if (previous != null) {
        throw PaletteFormatException(
          'row $rowNumber: "$alias" and "$previous" both map to the Dart name '
          '"$identifier". Rename one of them, or set a "code" value.',
        );
      }
      takenNames[identifier] = alias;

      entries.add(_ColorEntry(
        alias: alias,
        identifier: identifier,
        literals: literals,
        comment: _oneLine(comment),
      ));
    }

    return _formatSource(_render(
      csvFileName: csvFileName,
      baseName: baseName,
      modes: modes,
      entries: entries,
    ));
  }

  /// Names the generated code uses itself, so a color cannot take them.
  Set<String> _reservedNames(String baseName, List<_Mode> modes) {
    return <String>{
      baseName,
      for (final mode in modes) _modeClassName(baseName, mode),
      if (options.generateAliasMap) aliasMapName,
      if (modes.length > 1) ...[
        for (final mode in modes) mode.name,
        ..._extensionMembers,
      ],
    };
  }

  List<List<dynamic>> _parseRows(String csvContent) {
    // The csv package defaults to a `\r\n` end of line and does not detect
    // anything else, so an LF-only export (Google Sheets, Numbers, macOS) used
    // to parse as a single giant row. Normalise first, then pin `eol`.
    final normalized =
        csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

    // `shouldParseNumbers: false` keeps `100` and `000000` as strings; number
    // parsing used to turn numeric aliases into `int` and blow up on cast, and
    // stripped the leading zeros off hex values written without a `#`.
    return const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
      convertEmptyTo: '',
    ).convert(normalized);
  }

  _Columns _resolveColumns(
    List<dynamic> header,
    void Function(String message)? onWarning,
  ) {
    final labels = header.map((cell) => _normalizeHeader(cell)).toList();
    final used = <int>{};

    int? indexOf(Set<String> candidates) {
      for (var i = 0; i < labels.length; i++) {
        if (used.contains(i)) continue;
        if (candidates.contains(labels[i])) {
          used.add(i);
          return i;
        }
      }
      return null;
    }

    final name = indexOf(_nameHeaders);
    final code = indexOf(_codeHeaders);

    // Mode columns take precedence: a CSV that names its modes is describing a
    // themed palette, and a leftover `value` column would be ambiguous.
    final modes = <_Mode>[];
    final seenModes = <String>{};
    for (var i = 0; i < labels.length; i++) {
      if (used.contains(i)) continue;
      final mode = _modeHeaders[labels[i]];
      if (mode == null) continue;
      if (!seenModes.add(mode)) {
        throw PaletteFormatException(
          'The header row has more than one "$mode" column.',
        );
      }
      used.add(i);
      modes.add(_Mode(name: mode, index: i));
    }

    final value = modes.isEmpty ? indexOf(_valueHeaders) : null;
    final comment = indexOf(_commentHeaders);

    if (name == null || (modes.isEmpty && value == null)) {
      onWarning?.call(
        'Could not find a name column and a value column in the header row '
        '(${header.join(', ')}). Falling back to column order: 1st = name, '
        '2nd = value, 3rd = comment.',
      );
      return const _Columns(
        name: 0,
        modes: [_Mode(name: '', index: 1)],
        comment: 2,
      );
    }

    return _Columns(
      name: name,
      modes: modes.isEmpty ? [_Mode(name: '', index: value!)] : modes,
      code: code,
      comment: comment,
    );
  }

  String _render({
    required String csvFileName,
    required String baseName,
    required List<_Mode> modes,
    required List<_ColorEntry> entries,
  }) {
    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln("// Generated by project_color_palette from '$csvFileName'.")
      ..writeln('//')
      ..writeln('// ignore_for_file: type=lint')
      ..writeln('// coverage:ignore-file')
      ..writeln()
      ..writeln("import 'package:flutter/material.dart';");

    for (var m = 0; m < modes.length; m++) {
      buffer.writeln();
      _writeColorClass(
        buffer,
        className: _modeClassName(baseName, modes[m]),
        csvFileName: csvFileName,
        mode: modes[m],
        modeIndex: m,
        entries: entries,
      );
    }

    if (modes.length > 1) {
      buffer.writeln();
      _writeThemeExtension(buffer, baseName, modes, entries);
    }

    return buffer.toString();
  }

  void _writeColorClass(
    StringBuffer buffer, {
    required String className,
    required String csvFileName,
    required _Mode mode,
    required int modeIndex,
    required List<_ColorEntry> entries,
  }) {
    buffer
      ..writeln('/// Color palette generated from `$csvFileName`'
          '${mode.name.isEmpty ? '' : ' (${mode.name} mode)'}.')
      ..writeln('///')
      ..writeln('/// Contains ${entries.length} '
          '${entries.length == 1 ? 'color' : 'colors'}.')
      ..writeln('class $className {')
      ..writeln('  const $className._();');

    for (final entry in entries) {
      buffer
        ..writeln()
        ..writeln('  /// `${_docSafe(entry.alias)}`'
            '${entry.comment.isEmpty ? '' : ' - ${_docSafe(entry.comment)}'}')
        ..writeln('  static const Color ${entry.identifier} = '
            'Color(${entry.literals[modeIndex]});');
    }

    if (options.generateAliasMap) {
      buffer
        ..writeln()
        ..writeln('  /// Every color in this palette, keyed by its alias')
        ..writeln('  /// exactly as written in the CSV.');
      if (entries.isEmpty) {
        buffer.writeln(
          '  static const Map<String, Color> $aliasMapName = '
          '<String, Color>{};',
        );
      } else {
        buffer.writeln(
          '  static const Map<String, Color> $aliasMapName = <String, Color>{',
        );
        for (final entry in entries) {
          buffer.writeln(
            "    '${_escapeString(entry.alias)}': ${entry.identifier},",
          );
        }
        buffer.writeln('  };');
      }
    }

    // Exactly once, outside the loop.
    buffer.writeln('}');
  }

  /// Emits a `ThemeExtension` that switches between the mode classes.
  ///
  /// The per-mode classes above stay exactly as they are, so a color that does
  /// not depend on the theme is still reachable as a `static const` usable in a
  /// const context. This is the opt-in layer for the ones that do.
  void _writeThemeExtension(
    StringBuffer buffer,
    String baseName,
    List<_Mode> modes,
    List<_ColorEntry> entries,
  ) {
    final modeClasses = {
      for (final mode in modes) mode.name: _modeClassName(baseName, mode),
    };

    buffer
      ..writeln('/// The palette above, resolved through the active theme.')
      ..writeln('///')
      ..writeln('/// Register it once:')
      ..writeln('///')
      ..writeln('/// ```dart')
      ..writeln('/// ThemeData(extensions: const [$baseName.'
          '${modes.first.name}])')
      ..writeln('/// ```')
      ..writeln('///')
      ..writeln('/// then read it with `$baseName.of(context).'
          '${entries.isEmpty ? 'someColor' : entries.first.identifier}`.')
      ..writeln('class $baseName extends ThemeExtension<$baseName> {')
      ..writeln('  const $baseName({');
    for (final entry in entries) {
      buffer.writeln('    required this.${entry.identifier},');
    }
    buffer.writeln('  });');

    for (final mode in modes) {
      buffer
        ..writeln()
        ..writeln('  /// The ${mode.name} mode palette.')
        ..writeln('  static const $baseName ${mode.name} = $baseName(');
      for (final entry in entries) {
        buffer.writeln('    ${entry.identifier}: '
            '${modeClasses[mode.name]}.${entry.identifier},');
      }
      buffer.writeln('  );');
    }

    for (final entry in entries) {
      buffer
        ..writeln()
        ..writeln('  /// `${_docSafe(entry.alias)}`'
            '${entry.comment.isEmpty ? '' : ' - ${_docSafe(entry.comment)}'}')
        ..writeln('  final Color ${entry.identifier};');
    }

    buffer
      ..writeln()
      ..writeln('  /// The palette registered on the closest [Theme].')
      ..writeln('  static $baseName of(BuildContext context) =>')
      ..writeln('      Theme.of(context).extension<$baseName>()!;')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  $baseName copyWith({');
    for (final entry in entries) {
      buffer.writeln('    Color? ${entry.identifier},');
    }
    buffer.writeln('  }) {');
    buffer.writeln('    return $baseName(');
    for (final entry in entries) {
      buffer.writeln('      ${entry.identifier}: ${entry.identifier} ?? '
          'this.${entry.identifier},');
    }
    buffer
      ..writeln('    );')
      ..writeln('  }')
      ..writeln()
      ..writeln('  @override')
      ..writeln('  $baseName lerp('
          'covariant ThemeExtension<$baseName>? other, double t) {')
      ..writeln('    if (other is! $baseName) return this;')
      ..writeln('    return $baseName(');
    for (final entry in entries) {
      buffer.writeln('      ${entry.identifier}: Color.lerp('
          '${entry.identifier}, other.${entry.identifier}, t)!,');
    }
    buffer
      ..writeln('    );')
      ..writeln('  }')
      ..writeln('}');
  }
}

String _modeClassName(String baseName, _Mode mode) =>
    mode.name.isEmpty ? baseName : '$baseName${capitalize(mode.name)}';

/// One value column. [name] is empty for a CSV with a single unnamed `value`
/// column, which is the non-themed shape.
class _Mode {
  const _Mode({required this.name, required this.index});

  final String name;
  final int index;
}

class _Columns {
  const _Columns({
    required this.name,
    required this.modes,
    this.code,
    this.comment,
  });

  final int name;

  /// One entry per value column, in the order they appear in the CSV.
  final List<_Mode> modes;

  /// Optional column holding a member name agreed between designer and
  /// developer. Overrides the derived name when it has a value.
  final int? code;
  final int? comment;
}

class _ColorEntry {
  _ColorEntry({
    required this.alias,
    required this.identifier,
    required this.literals,
    required this.comment,
  });

  final String alias;
  final String identifier;

  /// One `0xAARRGGBB` literal per mode, in the same order as the modes.
  final List<String> literals;
  final String comment;
}

String _cell(List<dynamic> row, int index) {
  if (index < 0 || index >= row.length) return '';
  return (row[index]?.toString() ?? '').trim();
}

String _normalizeHeader(dynamic cell) =>
    (cell?.toString() ?? '').toLowerCase().replaceAll(_headerNoise, '');

/// Collapses a cell to a single line — a multi-line comment cell would
/// otherwise push its tail out of the `///` comment and into the code.
String _oneLine(String value) => value.replaceAll(_whitespaceRun, ' ').trim();

String _docSafe(String value) => _oneLine(value).replaceAll('`', "'");

String _escapeString(String value) => _oneLine(value)
    .replaceAll(r'\', r'\\')
    .replaceAll("'", r"\'")
    .replaceAll(r'$', r'\$');
