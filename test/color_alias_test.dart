import 'package:flutter_test/flutter_test.dart';
import 'package:project_color_palette/generator/color_alias.dart';
import 'package:project_color_palette/generator/palette_exception.dart';

void main() {
  group('aliasToIdentifier', () {
    test('keeps the alias readable across every separator designers use', () {
      expect(aliasToIdentifier('text/primary'), 'textPrimary');
      expect(aliasToIdentifier('gray-100'), 'gray100');
      expect(aliasToIdentifier('background_subtle'), 'backgroundSubtle');
      expect(aliasToIdentifier('Blue Gray 50'), 'blueGray50');
      expect(
          aliasToIdentifier('action/primary-pressed'), 'actionPrimaryPressed');
      expect(aliasToIdentifier('  text / on-brand  '), 'textOnBrand');
    });

    test('existing camelCase survives untouched', () {
      // The old converter lower-cased the whole alias, producing
      // `colorPrimarybuttonbg` and destroying every word boundary.
      expect(aliasToIdentifier('primaryButtonBg'), 'primaryButtonBg');
      expect(aliasToIdentifier('brandAccentSubtle'), 'brandAccentSubtle');
    });

    test('SCREAMING_CASE folds to the same name as lower case', () {
      expect(aliasToIdentifier('TEXT/PRIMARY'), 'textPrimary');
      expect(aliasToIdentifier('PRIMARY'), 'primary');
    });

    test('aliases that cannot be identifiers get a color prefix', () {
      expect(aliasToIdentifier('100'), 'color100');
      expect(aliasToIdentifier('new'), 'colorNew');
      expect(aliasToIdentifier('class'), 'colorClass');
      expect(aliasToIdentifier('static'), 'colorStatic');
      // A static member may not shadow an Object member.
      expect(aliasToIdentifier('hashCode'), 'colorHashCode');
      expect(aliasToIdentifier('to-string'), 'colorToString');
    });

    test('names in avoid are pushed out of the way', () {
      expect(
        aliasToIdentifier('byAlias', avoid: const {'byAlias'}),
        'colorByAlias',
      );
      expect(
        aliasToIdentifier('SemanticLight', avoid: const {'semanticLight'}),
        'colorSemanticLight',
      );
    });

    test('colorPrefix restores the pre-2.0.0 style', () {
      expect(
        aliasToIdentifier('text/primary', colorPrefix: true),
        'colorTextPrimary',
      );
      expect(aliasToIdentifier('white', colorPrefix: true), 'colorWhite');
    });

    test('an alias with nothing usable in it throws', () {
      for (final alias in <String>['///', '한글토큰', '   ']) {
        expect(
          () => aliasToIdentifier(alias),
          throwsA(isA<PaletteFormatException>()
              .having((e) => e.message, 'message', contains('"code"'))),
          reason: 'expected "$alias" to be rejected',
        );
      }
    });
  });

  group('validateExplicitIdentifier', () {
    test('a usable name is returned untouched', () {
      for (final code in <String>['brandBlue', 'TEXT_1', 'gray100', r'a$b']) {
        expect(validateExplicitIdentifier(code), code);
      }
    });

    test('a name that will not compile is rejected', () {
      for (final code in <String>[
        '1st', // leading digit
        'text primary', // space
        'text-primary', // hyphen
        'text/primary', // slash
        '브랜드파랑', // non-ASCII
        '_hidden', // private to the generated file
        '', // empty
      ]) {
        expect(
          () => validateExplicitIdentifier(code),
          throwsA(isA<PaletteFormatException>()),
          reason: 'expected code "$code" to be rejected',
        );
      }
    });

    test('a Dart keyword or Object member is rejected', () {
      for (final code in <String>['new', 'class', 'static', 'hashCode']) {
        expect(
          () => validateExplicitIdentifier(code),
          throwsA(isA<PaletteFormatException>()
              .having((e) => e.message, 'message', contains('keyword'))),
          reason: 'expected code "$code" to be rejected',
        );
      }
    });
  });

  group('classNameForFileName', () {
    test('derives a PascalCase class name', () {
      expect(classNameForFileName('color_test.csv'), 'ColorTest');
      expect(classNameForFileName('semantic_light.csv'), 'SemanticLight');
      expect(classNameForFileName('COLOR_TEST.csv'), 'ColorTest');
      expect(classNameForFileName('color-primitive.csv'), 'ColorPrimitive');
    });

    test('survives file names the old split(_) crashed on', () {
      // `word[0]` on an empty segment used to throw RangeError.
      expect(classNameForFileName('_color.csv'), 'Color');
      expect(classNameForFileName('color__main.csv'), 'ColorMain');
      expect(classNameForFileName('color.main.csv'), 'ColorMain');
      expect(classNameForFileName('.csv'), 'ColorPalette');
      expect(classNameForFileName('2024_palette.csv'), 'Palette2024Palette');
    });
  });
}
