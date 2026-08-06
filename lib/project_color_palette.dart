/// CSV to Flutter color palette code generation.
///
/// Normal use needs no import at all — add the package, drop CSVs in
/// `assets/color_palette/` and run `build_runner`. These exports are here for
/// tooling and tests that want to drive the generator directly.
library project_color_palette;

export 'generator/color_alias.dart'
    show aliasToIdentifier, classNameForFileName, validateExplicitIdentifier;
export 'generator/hex_color.dart' show hexToArgbLiteral;
export 'generator/palette_exception.dart';
export 'generator/palette_options.dart';
export 'generator/palette_source_builder.dart'
    show
        AliasValueSource,
        PaletteSourceBuilder,
        aliasMapName,
        decodeCsvBytes,
        scanAliases;
