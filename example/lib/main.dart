import 'package:flutter/material.dart';

import 'palette/color_primitive.g.dart';
import 'palette/semantic.g.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _mode = ThemeMode.light;

  void _toggleMode() {
    setState(() {
      _mode = _mode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'project_color_palette',
      themeMode: _mode,
      // `Semantic` is the generated ThemeExtension; `Semantic.light` and
      // `Semantic.dark` are built from the light and dark columns of the CSV.
      theme: _themeFor(Brightness.light, Semantic.light),
      darkTheme: _themeFor(Brightness.dark, Semantic.dark),
      home: PaletteScreen(onToggleMode: _toggleMode),
    );
  }

  ThemeData _themeFor(Brightness brightness, Semantic palette) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: palette.backgroundDefault,
      colorScheme: ColorScheme.fromSeed(
        // A mode-independent color is still a plain `static const`, so it works
        // in a const context and needs no BuildContext.
        seedColor: ColorPrimitive.blue500,
        brightness: brightness,
      ),
      extensions: [palette],
    );
  }
}

class PaletteScreen extends StatelessWidget {
  const PaletteScreen({super.key, required this.onToggleMode});

  final VoidCallback onToggleMode;

  @override
  Widget build(BuildContext context) {
    // Mode-aware colors come from the extension.
    final palette = Semantic.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.actionPrimary,
        foregroundColor: palette.textOnBrand,
        title: const Text('Generated palettes'),
        actions: [
          IconButton(
            onPressed: onToggleMode,
            icon: Icon(
              Theme.of(context).brightness == Brightness.light
                  ? Icons.dark_mode
                  : Icons.light_mode,
            ),
            tooltip: 'Toggle light / dark',
          ),
        ],
      ),
      body: ListView(
        children: [
          // Iterating `byAlias` keeps the designer's original alias strings,
          // including the ones that are not valid Dart identifiers.
          _PaletteSection(
            title: 'semantic.csv (active mode)',
            colors: Theme.of(context).brightness == Brightness.light
                ? SemanticLight.byAlias
                : SemanticDark.byAlias,
          ),
          const _PaletteSection(
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
    final palette = Semantic.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: palette.backgroundSubtle,
          child: Text(
            title,
            style: TextStyle(
              color: palette.textSecondary,
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
    final palette = Semantic.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: palette.borderDefault)),
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
                border: Border.all(color: palette.borderDefault),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                alias,
                style: TextStyle(color: palette.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
