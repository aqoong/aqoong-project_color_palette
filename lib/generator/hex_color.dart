/*
 * Copyright (c) 2024. AQoong(cooldnjsdn@gmail.com) All rights reserved.
 */

import 'palette_exception.dart';
import 'palette_options.dart';

final _hexDigits = RegExp(r'^[0-9A-F]+$');
final _whitespace = RegExp(r'\s');

/// Converts a designer supplied hex string into a Flutter `0xAARRGGBB` literal.
///
/// Accepts `#RGB`, `#RGBA`, `#RRGGBB` and `#RRGGBBAA`; the leading `#` (or
/// `0x`) is optional. Values that carry an alpha channel are read according to
/// [alphaPosition], which defaults to the CSS / Figma order.
///
/// Throws a [PaletteFormatException] for anything else. An unrecognised value
/// has to fail the build — emitting `Color(rgba(0,0,0,.5))` would only move the
/// error into the consumer's compile step.
String hexToArgbLiteral(
  String raw, {
  HexAlphaPosition alphaPosition = HexAlphaPosition.trailing,
}) {
  var digits = raw.trim().replaceAll(_whitespace, '').toUpperCase();
  if (digits.startsWith('#')) {
    digits = digits.substring(1);
  } else if (digits.startsWith('0X')) {
    digits = digits.substring(2);
  }

  if (digits.isEmpty || !_hexDigits.hasMatch(digits)) {
    throw PaletteFormatException(_expected(raw));
  }

  // Expand shorthand: RGB -> RRGGBB, RGBA -> RRGGBBAA.
  if (digits.length == 3 || digits.length == 4) {
    digits = digits.split('').map((digit) => '$digit$digit').join();
  }

  switch (digits.length) {
    case 6:
      return '0xFF$digits';
    case 8:
      if (alphaPosition == HexAlphaPosition.leading) return '0x$digits';
      // RRGGBBAA -> AARRGGBB
      return '0x${digits.substring(6)}${digits.substring(0, 6)}';
    default:
      throw PaletteFormatException(_expected(raw));
  }
}

String _expected(String raw) =>
    'Invalid color value "$raw". Expected a hex color such as #RRGGBB, '
    '#RRGGBBAA, #RGB or #RGBA (the leading "#" is optional). '
    'Functional notation like rgba(...) is not supported.';
