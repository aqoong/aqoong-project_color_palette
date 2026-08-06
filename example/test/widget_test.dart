import 'package:example/main.dart';
import 'package:example/palette/color_primitive.g.dart';
import 'package:example/palette/semantic_light.g.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('every generated alias is rendered', (tester) async {
    await tester.pumpWidget(const MyApp());

    // Aliases that are valid Dart identifiers are reachable directly...
    expect(SemanticLight.textPrimary, const Color(0xFF212529));
    expect(SemanticLight.overlayScrim, const Color(0x80000000));
    expect(ColorPrimitive.transparent, const Color(0x00FFFFFF));

    // An alias with no possible Dart name gets one from the CSV's code column.
    expect(SemanticLight.warningSurface, const Color(0xFFFFF4E6));

    // ...and every alias, including `100` and `new`, is in the map verbatim.
    expect(SemanticLight.byAlias['text/primary'], SemanticLight.textPrimary);
    expect(SemanticLight.byAlias['100'], SemanticLight.color100);
    expect(SemanticLight.byAlias['new'], SemanticLight.colorNew);
    expect(SemanticLight.byAlias['경고/배경'], SemanticLight.warningSurface);

    expect(find.text('text/primary'), findsOneWidget);
    expect(find.text('action/primary-pressed'), findsOneWidget);
    expect(find.text('경고/배경'), findsOneWidget);
  });
}
