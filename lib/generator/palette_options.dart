/*
 * Copyright (c) 2024. AQoong(cooldnjsdn@gmail.com) All rights reserved.
 */

import 'palette_exception.dart';

/// Where the alpha channel sits inside an 8 digit hex string.
enum HexAlphaPosition {
  /// `#RRGGBBAA` — what Figma, Sketch and CSS export. This is the default
  /// because the CSV comes from a design tool, not from Dart.
  trailing,

  /// `#AARRGGBB` — the layout Flutter's own `Color(0x...)` literal uses.
  leading,
}

/// Builder configuration, read from the `options:` block of `build.yaml`.
class PaletteOptions {
  const PaletteOptions({
    this.colorPrefix = false,
    this.hexAlphaPosition = HexAlphaPosition.trailing,
    this.generateAliasMap = true,
  });

  /// Prefix every member with `color`, e.g. `text/primary` becomes
  /// `colorTextPrimary` instead of `textPrimary`.
  ///
  /// Off by default: the class name already says these are colors, so the
  /// prefix is redundant at the call site (`SemanticLight.colorTextPrimary`).
  /// Set it to `true` to keep the naming used by package versions before 2.0.0.
  final bool colorPrefix;

  /// How to read the alpha channel of `#RRGGBBAA` / `#RGBA` values.
  final HexAlphaPosition hexAlphaPosition;

  /// Emit `static const Map<String, Color> byAlias`, keyed by the untouched
  /// alias string from the CSV.
  final bool generateAliasMap;

  static const _colorPrefixKey = 'color_prefix';
  static const _hexAlphaPositionKey = 'hex_alpha_position';
  static const _generateAliasMapKey = 'generate_alias_map';

  static const _knownKeys = <String>{
    _colorPrefixKey,
    _hexAlphaPositionKey,
    _generateAliasMapKey,
  };

  /// Parses the raw `BuilderOptions.config` map.
  ///
  /// Unknown keys are reported through [onWarning] rather than ignored, so a
  /// typo in `build.yaml` does not silently do nothing. Bad *values* throw,
  /// because falling back to a default would hide a real misconfiguration.
  factory PaletteOptions.fromConfig(
    Map<String, dynamic> config, {
    void Function(String message)? onWarning,
  }) {
    for (final key in config.keys) {
      if (!_knownKeys.contains(key)) {
        onWarning?.call(
          'Unknown option "$key". Supported options: '
          '${_knownKeys.join(', ')}.',
        );
      }
    }

    return PaletteOptions(
      colorPrefix: _readBool(config, _colorPrefixKey, false),
      generateAliasMap: _readBool(config, _generateAliasMapKey, true),
      hexAlphaPosition: _readAlphaPosition(config),
    );
  }

  static bool _readBool(
    Map<String, dynamic> config,
    String key,
    bool fallback,
  ) {
    final value = config[key];
    if (value == null) return fallback;
    if (value is bool) return value;
    throw PaletteFormatException(
      'Option "$key" must be true or false, got "$value".',
    );
  }

  static HexAlphaPosition _readAlphaPosition(Map<String, dynamic> config) {
    final value = config[_hexAlphaPositionKey];
    if (value == null) return HexAlphaPosition.trailing;
    for (final position in HexAlphaPosition.values) {
      if (position.name == value) return position;
    }
    throw PaletteFormatException(
      'Option "$_hexAlphaPositionKey" must be one of '
      '${HexAlphaPosition.values.map((e) => e.name).join(', ')}, '
      'got "$value".',
    );
  }
}
