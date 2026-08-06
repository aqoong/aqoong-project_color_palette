## 0.0.1
* *.csv file in assets

## 1.0.0
* refactor project_color_palette package
* The CSV files must be located in the assets/color_palette folder and can only be read if the CSV file name contains "color".
* A color class is generated based on each CSV file name, and the generated class will have a .g.dart extension in the lib/palette folder.

## 1.0.1
* update build.yaml, build process log

## 1.0.2
* add License info in README.md

## 2.0.0

### Fixed
* **A CSV with more than one color generated uncompilable Dart.** The closing
  brace of the class was written inside the row loop, so every color after the
  first landed outside the class body. A CSV with no data rows produced a class
  with no closing brace at all.
* **LF-only CSV files were not parsed.** The `csv` package defaults to a `\r\n`
  end of line and does not detect anything else, so an export from Google
  Sheets, Numbers or macOS parsed as a single row and produced an empty class.
  CRLF, LF and CR are all handled now.
* **Numeric aliases and values crashed the generator.** `100` was parsed as an
  `int` and threw on the `String` cast; a value written as `000000` lost its
  leading zeros. Number parsing is now off.
* **A CSV without a comment column threw `RangeError`**, and the failure was
  swallowed into a warning, so the build reported success while generating
  nothing. Missing columns are tolerated and real errors now fail the build.
* **Color values are validated.** `#RRGGBBAA`, `#RGB` and `#RGBA` are supported
  (8 digit values were previously turned into 10 digit garbage), and anything
  unparseable fails the build with the row number instead of emitting broken
  Dart.
* Non-UTF-8 and UTF-16 CSVs now report what to do about it instead of throwing a
  bare `FormatException`; a UTF-8 byte order mark is stripped.
* A multi-line comment cell no longer pushes its tail out of the comment and
  into the code.
* File names containing dots no longer violate the declared `build_extensions`;
  the output path comes from build_runner instead of `split('.').first`.
* `_toCamelCase` no longer throws `RangeError` on file names with leading or
  doubled underscores.

### Changed (breaking)
* Member names follow one stated rule — every non-alphanumeric run is a word
  boundary, and the words become lowerCamelCase — and drop the forced `color`
  prefix: `colorWhite` → `white`, `colorPrimarybuttonbg` → `primaryButtonBg`.
  An alias that is already camelCase is not re-cased. Set `color_prefix: true`
  to keep the old prefix.
* CSV file names no longer have to contain "color". Every `*.csv` under
  `assets/color_palette/` is generated.
* Two aliases mapping to the same Dart name, or a repeated alias, is now an
  error rather than a silent overwrite.
* A malformed CSV fails the build (`log.severe`) instead of logging a warning.

### Added
* **Light and dark modes.** A CSV can carry one value per mode
  (`alias,light,dark`) instead of a single `value` column. `semantic.csv` then
  generates `SemanticLight` and `SemanticDark` — still plain `static const`, so
  const contexts and theme-independent colors are unaffected — plus a
  `Semantic extends ThemeExtension<Semantic>` with `light`/`dark` constants,
  `of(context)`, `copyWith` and `lerp`. A row missing one of its mode values is
  a build error naming the row and the mode.
* An optional `code` column holding a member name agreed between designer and
  developer. Where it has a value it overrides the derived name and is taken
  literally, which is how non-ASCII aliases, name collisions and deliberate
  renames are handled. Invalid codes fail the build.
* `byAlias`, a `Map<String, Color>` keyed by the alias exactly as written in the
  CSV, for iterating a palette or looking a color up by a string.
* Columns are matched by header name (`name`/`alias`/`token`, `value`/`hex`,
  `code`/`dart name`, `comment`/`description`/...) in any order, falling back to
  column order with a warning.
* Builder options: `color_prefix`, `hex_alpha_position`, `generate_alias_map`.
* Generated files carry a `DO NOT MODIFY BY HAND` header, `ignore_for_file` and
  `coverage:ignore-file`, plus a doc comment per color showing the original
  alias and its CSV comment.
* A test suite. The multi-color brace bug survived to 1.0.2 because
  `test/palette_test.dart` was an empty `main()`.

### Internal
* Reads through `buildStep` instead of `dart:io`, and no longer globs every
  asset once per input. `glob` is no longer a dependency.
* Generated source is run through `dart_style`, so the output is canonical
  regardless of how long the color names are and `dart format` in the consuming
  project leaves it alone. The formatter also has to parse the source, so a
  generator that emits broken Dart now fails at build time rather than in
  somebody else's compile step.
* The declared SDK floor moves to 3.4.0, which is what `dart_style` 3 requires.
