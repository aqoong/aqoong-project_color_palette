/*
 * Copyright (c) 2024. AQoong(cooldnjsdn@gmail.com) All rights reserved.
 */

import 'dart:convert';

import 'package:csv/csv.dart';

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

final _whitespaceRun = RegExp(r'\s+');
final _headerNoise = RegExp(r'[\s_\-/.]');

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
    final className = classNameForFileName(csvFileName);

    if (rows.isEmpty) {
      onWarning?.call('The CSV is empty; generating an empty palette.');
      return _render(csvFileName, className, const <_ColorEntry>[]);
    }

    final columns = _resolveColumns(rows.first, onWarning);
    final entries = <_ColorEntry>[];
    final takenAliases = <String>{};
    final takenNames = <String, String>{};
    // Names the generated class already uses. A member may not share the class'
    // own name, and `byAlias` is emitted alongside the colors.
    final reserved = <String>{
      className,
      if (options.generateAliasMap) aliasMapName,
    };

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      // Row numbers are 1-based and include the header, matching what the
      // designer sees in the spreadsheet.
      final rowNumber = i + 1;

      final alias = _cell(row, columns.name);
      final value = _cell(row, columns.value);
      final code = columns.code == null ? '' : _cell(row, columns.code!);
      final comment =
          columns.comment == null ? '' : _cell(row, columns.comment!);

      // Spreadsheets happily export trailing `,,,` rows; those are not errors.
      if (alias.isEmpty && value.isEmpty) continue;
      if (alias.isEmpty) {
        throw PaletteFormatException(
          'row $rowNumber: the color value "$value" has no name.',
        );
      }
      if (value.isEmpty) {
        throw PaletteFormatException('row $rowNumber: "$alias" has no value.');
      }
      // A duplicate alias would also produce a duplicate `byAlias` key, which
      // is a compile error in a const map.
      if (!takenAliases.add(alias)) {
        throw PaletteFormatException(
          'row $rowNumber: the alias "$alias" appears more than once.',
        );
      }

      final String literal;
      try {
        literal = hexToArgbLiteral(
          value,
          alphaPosition: options.hexAlphaPosition,
        );
      } on PaletteFormatException catch (error) {
        throw PaletteFormatException('row $rowNumber: ${error.message}');
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
        literal: literal,
        comment: _oneLine(comment),
      ));
    }

    return _render(csvFileName, className, entries);
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

    int? indexOf(Set<String> candidates, Set<int> used) {
      for (var i = 0; i < labels.length; i++) {
        if (used.contains(i)) continue;
        if (candidates.contains(labels[i])) return i;
      }
      return null;
    }

    final used = <int>{};
    final name = indexOf(_nameHeaders, used);
    if (name != null) used.add(name);
    final value = indexOf(_valueHeaders, used);
    if (value != null) used.add(value);
    final code = indexOf(_codeHeaders, used);
    if (code != null) used.add(code);
    final comment = indexOf(_commentHeaders, used);

    if (name == null || value == null) {
      onWarning?.call(
        'Could not find a name column and a value column in the header row '
        '(${header.join(', ')}). Falling back to column order: 1st = name, '
        '2nd = value, 3rd = comment.',
      );
      return const _Columns(name: 0, value: 1, comment: 2);
    }
    return _Columns(name: name, value: value, code: code, comment: comment);
  }

  String _render(
    String csvFileName,
    String className,
    List<_ColorEntry> entries,
  ) {
    final buffer = StringBuffer()
      ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
      ..writeln("// Generated by project_color_palette from '$csvFileName'.")
      ..writeln('//')
      ..writeln('// ignore_for_file: type=lint')
      ..writeln('// coverage:ignore-file')
      ..writeln()
      ..writeln("import 'package:flutter/material.dart';")
      ..writeln()
      ..writeln('/// Color palette generated from `$csvFileName`.')
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
            'Color(${entry.literal});');
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
    return buffer.toString();
  }
}

class _Columns {
  const _Columns({
    required this.name,
    required this.value,
    this.code,
    this.comment,
  });

  final int name;
  final int value;

  /// Optional column holding a member name agreed between designer and
  /// developer. Overrides the derived name when it has a value.
  final int? code;
  final int? comment;
}

class _ColorEntry {
  _ColorEntry({
    required this.alias,
    required this.identifier,
    required this.literal,
    required this.comment,
  });

  final String alias;
  final String identifier;
  final String literal;
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
