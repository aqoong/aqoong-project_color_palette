/*
 * Copyright (c) 2024. AQoong(cooldnjsdn@gmail.com) All rights reserved.
 */

/// Thrown when a CSV palette cannot be turned into valid Dart code.
///
/// [message] is written verbatim to the build log, so it should be actionable
/// for whoever owns the CSV — usually a designer rather than a developer.
class PaletteFormatException implements Exception {
  PaletteFormatException(this.message);

  final String message;

  @override
  String toString() => 'PaletteFormatException: $message';
}
