import 'package:example/main.dart';
import 'package:example/palette/color_primitive.g.dart';
import 'package:example/palette/semantic.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('single mode CSV generates plain static consts', () {
    expect(ColorPrimitive.blue500, const Color(0xFF2C6BED));
    expect(ColorPrimitive.transparent, const Color(0x00FFFFFF));
    expect(ColorPrimitive.byAlias['gray-100'], ColorPrimitive.gray100);
  });

  test('light and dark columns generate one class each', () {
    expect(SemanticLight.textPrimary, const Color(0xFF212529));
    expect(SemanticDark.textPrimary, const Color(0xFFF1F3F5));
    expect(SemanticLight.overlayScrim, const Color(0x80000000));
    expect(SemanticDark.overlayScrim, const Color(0xB3000000));

    // The alias the designer wrote is the map key in both modes, including the
    // ones that could never be Dart identifiers.
    expect(SemanticLight.byAlias['text/primary'], SemanticLight.textPrimary);
    expect(SemanticDark.byAlias['100'], SemanticDark.color100);
    expect(SemanticDark.byAlias['new'], SemanticDark.colorNew);
    // `경고/배경` gets its name from the CSV's code column.
    expect(SemanticLight.byAlias['경고/배경'], SemanticLight.warningSurface);
  });

  test('the ThemeExtension is built from the mode classes', () {
    expect(Semantic.light.textPrimary, SemanticLight.textPrimary);
    expect(Semantic.dark.textPrimary, SemanticDark.textPrimary);

    expect(
      Semantic.light.copyWith(textPrimary: const Color(0xFF123456)).textPrimary,
      const Color(0xFF123456),
    );
    // lerp at the endpoints returns the endpoints.
    expect(Semantic.light.lerp(Semantic.dark, 0).textPrimary,
        SemanticLight.textPrimary);
    expect(Semantic.light.lerp(Semantic.dark, 1).textPrimary,
        SemanticDark.textPrimary);
  });

  testWidgets('Semantic.of resolves through the active theme', (tester) async {
    await tester.pumpWidget(const MyApp());

    BuildContext contextOf(Finder finder) => tester.element(finder);
    final screen = find.byType(PaletteScreen);

    expect(
        Semantic.of(contextOf(screen)).textPrimary, SemanticLight.textPrimary);
    expect(find.text('text/primary'), findsOneWidget);
    expect(find.text('경고/배경'), findsOneWidget);

    // Toggling the mode swaps the whole palette without touching a widget.
    await tester.tap(find.byTooltip('Toggle light / dark'));
    await tester.pumpAndSettle();

    expect(
        Semantic.of(contextOf(screen)).textPrimary, SemanticDark.textPrimary);
  });
}
