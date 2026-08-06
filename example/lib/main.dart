import 'package:flutter/material.dart';

import 'palette/color_primitive.g.dart';
import 'palette/semantic_light.g.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'project_color_palette',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: SemanticLight.backgroundDefault,
        // `action/primary` in the CSV becomes `actionPrimary` here.
        colorScheme:
            ColorScheme.fromSeed(seedColor: SemanticLight.actionPrimary),
      ),
      home: const PaletteScreen(),
    );
  }
}

class PaletteScreen extends StatelessWidget {
  const PaletteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: SemanticLight.actionPrimary,
        foregroundColor: SemanticLight.textOnBrand,
        title: const Text('Generated palettes'),
      ),
      body: ListView(
        children: const [
          // Iterating `byAlias` keeps the designer's original alias strings,
          // including the ones that are not valid Dart identifiers.
          _PaletteSection(
            title: 'semantic_light.csv',
            colors: SemanticLight.byAlias,
          ),
          _PaletteSection(
            title: 'color_primitive.csv',
            colors: ColorPrimitive.byAlias,
          ),
        ],
      ),
    );
  }
}

class _PaletteSection extends StatelessWidget {
  const _PaletteSection({required this.title, required this.colors});

  final String title;
  final Map<String, Color> colors;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: SemanticLight.backgroundSubtle,
          child: Text(
            title,
            style: const TextStyle(
              color: SemanticLight.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        for (final entry in colors.entries)
          _Swatch(alias: entry.key, color: entry.value),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.alias, required this.color});

  final String alias;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: SemanticLight.borderDefault)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: SemanticLight.borderDefault),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                alias,
                style: const TextStyle(color: SemanticLight.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
