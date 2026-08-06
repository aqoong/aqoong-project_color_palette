/*
 * Copyright (c) 2024. AQoong(cooldnjsdn@gmail.com) All rights reserved.
 */

import 'package:build/build.dart';

import 'palette_options.dart';
import 'palette_source_builder.dart';

/// Reads one CSV asset through the build system and writes the palette it
/// describes.
class CsvToFile {
  CsvToFile({
    required this.buildStep,
    required this.csvAssetId,
    this.options = const PaletteOptions(),
  });

  final BuildStep buildStep;
  final AssetId csvAssetId;
  final PaletteOptions options;

  Future<void> write({void Function(String message)? onWarning}) async {
    // Read through `buildStep`, not `dart:io`. `File(assetId.path)` only ever
    // resolved because the CSV happened to live in the root package and the
    // build ran from that directory.
    final bytes = await buildStep.readAsBytes(csvAssetId);

    final source = PaletteSourceBuilder(options: options).build(
      csvFileName: csvAssetId.pathSegments.last,
      csvContent: decodeCsvBytes(bytes),
      onWarning: onWarning,
    );

    // build_runner derives this from `buildExtensions`, so the output always
    // satisfies the declared contract — including file names containing dots,
    // which `split('.').first` used to mangle into an unexpected output.
    await buildStep.writeAsString(buildStep.allowedOutputs.single, source);
  }
}
