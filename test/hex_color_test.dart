import 'package:flutter_test/flutter_test.dart';
import 'package:project_color_palette/generator/hex_color.dart';
import 'package:project_color_palette/generator/palette_exception.dart';
import 'package:project_color_palette/generator/palette_options.dart';

void main() {
  group('hexToArgbLiteral', () {
    test('6 digit values get an opaque alpha', () {
      expect(hexToArgbLiteral('#FFFFFF'), '0xFFFFFFFF');
      expect(hexToArgbLiteral('#2c6bed'), '0xFF2C6BED');
    });

    test('the leading # is optional', () {
      expect(hexToArgbLiteral('FFFFFF'), '0xFFFFFFFF');
      // Regression: CSV number parsing used to turn this into int 0.
      expect(hexToArgbLiteral('000000'), '0xFF000000');
      expect(hexToArgbLiteral('0xFF0000'), '0xFFFF0000');
    });

    test('3 digit shorthand expands', () {
      expect(hexToArgbLiteral('#FFF'), '0xFFFFFFFF');
      expect(hexToArgbLiteral('#08F'), '0xFF0088FF');
    });

    test('8 digit values are read as #RRGGBBAA by default', () {
      expect(hexToArgbLiteral('#00000080'), '0x80000000');
      expect(hexToArgbLiteral('#2C6BED00'), '0x002C6BED');
    });

    test('8 digit values can be read as #AARRGGBB instead', () {
      expect(
        hexToArgbLiteral('#80000000', alphaPosition: HexAlphaPosition.leading),
        '0x80000000',
      );
      expect(
        hexToArgbLiteral('#002C6BED', alphaPosition: HexAlphaPosition.leading),
        '0x002C6BED',
      );
    });

    test('4 digit shorthand carries alpha', () {
      expect(hexToArgbLiteral('#FFF8'), '0x88FFFFFF');
      expect(
        hexToArgbLiteral('#8FFF', alphaPosition: HexAlphaPosition.leading),
        '0x88FFFFFF',
      );
    });

    test('surrounding whitespace is ignored', () {
      expect(hexToArgbLiteral('  #FFFFFF '), '0xFFFFFFFF');
    });

    test('unsupported notation throws instead of emitting broken code', () {
      const rejected = <String>[
        'rgba(0, 0, 0, 0.5)',
        'rgb(0,0,0)',
        'white',
        '#GGGGGG',
        '#FFFFF',
        '#FFFFFFF',
        '#FFFFFFFFF',
        '#',
        '',
      ];
      for (final value in rejected) {
        expect(
          () => hexToArgbLiteral(value),
          throwsA(isA<PaletteFormatException>()),
          reason: 'expected "$value" to be rejected',
        );
      }
    });
  });
}
