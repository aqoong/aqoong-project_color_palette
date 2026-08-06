/*
 * Copyright (c) 2024. AQoong(cooldnjsdn@gmail.com) All rights reserved.
 */

import 'dart:async';

import 'package:build/build.dart';

import 'csv_to_file.dart';
import 'palette_exception.dart';
import 'palette_options.dart';

Builder paletteGeneratorBuilder(BuilderOptions options) {
  final warnings = <String>[];
  PaletteOptions parsed;
  String? error;
  try {
    parsed = PaletteOptions.fromConfig(options.config, onWarning: warnings.add);
  } on PaletteFormatException catch (e) {
    // `log` is only wired up inside a build step, so option problems are
    // carried into `build()` instead of crashing the generated build script.
    parsed = const PaletteOptions();
    error = e.message;
  }
  return PaletteGenerator(
    options: parsed,
    optionWarnings: warnings,
    optionError: error,
  );
}

class PaletteGenerator extends Builder {
  PaletteGenerator({
    this.options = const PaletteOptions(),
    this.optionWarnings = const <String>[],
    this.optionError,
  });

  final PaletteOptions options;
  final List<String> optionWarnings;
  final String? optionError;

  bool _reportedOptions = false;

  @override
  Map<String, List<String>> get buildExtensions => const {
        'assets/color_palette/{{}}.csv': ['lib/palette/{{}}.g.dart'],
      };

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final input = buildStep.inputId;

    if (!_reportedOptions) {
      _reportedOptions = true;
      for (final warning in optionWarnings) {
        log.warning('project_color_palette: $warning');
      }
    }
    if (optionError != null) {
      log.severe('project_color_palette: $optionError');
      return;
    }

    try {
      await CsvToFile(
        buildStep: buildStep,
        csvAssetId: input,
        options: options,
      ).write(onWarning: (message) => log.warning('${input.path}: $message'));
    } on PaletteFormatException catch (e) {
      // SEVERE fails the build. The previous `log.warning` left a broken or
      // missing palette behind while the build still reported success.
      log.severe('${input.path}: ${e.message}');
    }
  }
}
