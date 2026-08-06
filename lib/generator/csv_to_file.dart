/*
 * Copyright (c) 2024. AQoong(cooldnjsdn@gmail.com) All rights reserved.
 */

import 'package:build/build.dart';
import 'package:glob/glob.dart';

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
    final csvContent = decodeCsvBytes(bytes);
    final csvFileName = csvAssetId.pathSegments.last;

    final source = PaletteSourceBuilder(
      options: options,
      aliasIndex: await _aliasIndex(csvFileName, csvContent),
    ).build(
      csvFileName: csvFileName,
      csvContent: csvContent,
      onWarning: onWarning,
    );

    // build_runner derives this from `buildExtensions`, so the output always
    // satisfies the declared contract — including file names containing dots,
    // which `split('.').first` used to mangle into an unexpected output.
    await buildStep.writeAsString(buildStep.allowedOutputs.single, source);
  }

  /// Aliases declared by every CSV next to this one, for `{alias}` references.
  ///
  /// Skipped entirely unless this CSV actually contains a `{`, so a palette that
  /// uses no references never pays for reading its siblings. Reading them
  /// through `buildStep` also registers them as inputs, so editing a primitive
  /// rebuilds the palettes that reference it.
  Future<Map<String, List<AliasValueSource>>> _aliasIndex(
    String csvFileName,
    String csvContent,
  ) async {
    if (!csvContent.contains('{')) {
      return const <String, List<AliasValueSource>>{};
    }

    final index = <String, List<AliasValueSource>>{};
    void add(Map<String, AliasValueSource> aliases) {
      aliases.forEach((alias, aliasSource) {
        index.putIfAbsent(alias, () => <AliasValueSource>[]).add(aliasSource);
      });
    }

    // This file first, and without re-reading it.
    add(scanAliases(csvFileName, csvContent));

    final path = csvAssetId.path;
    final separator = path.lastIndexOf('/');
    final folder = separator == -1 ? '' : path.substring(0, separator + 1);

    final siblings = await buildStep.findAssets(Glob('$folder*.csv')).toList();
    for (final sibling in siblings) {
      if (sibling == csvAssetId) continue;
      add(scanAliases(
        sibling.pathSegments.last,
        decodeCsvBytes(await buildStep.readAsBytes(sibling)),
      ));
    }
    return index;
  }
}
