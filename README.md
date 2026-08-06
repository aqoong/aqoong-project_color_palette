# project_color_palette

This package is a tool for collaboration between designers and Flutter developers. csv to color_palette

A designer hands you a CSV of color aliases; this package turns it into Dart
under a naming rule simple enough that both sides can predict the outcome.

```csv
alias,value,description
text/primary,#212529,Default body text
action/primary,#2C6BED,
overlay/scrim,#00000080,50% black overlay
brandAccentSubtle,#E7F0FF,
```

```dart
final body = TextStyle(color: SemanticLight.textPrimary);
final button = ButtonStyle(
  backgroundColor: WidgetStatePropertyAll(SemanticLight.actionPrimary),
);
```

## How to Use

1. Add the package to `dev_dependencies` along with `build_runner`.
2. Put CSV files in `assets/color_palette/`.
3. Run `dart run build_runner build`.
4. Each CSV becomes `lib/palette/<file_name>.g.dart`, holding one class named
   after the file (`semantic_light.csv` → `class SemanticLight`).

## CSV format

The first row is a header. Columns are matched **by name**, in any order:

| Purpose | Accepted header labels |
| --- | --- |
| alias  | `name`, `alias`, `token`, `key`, `color name` |
| value  | `value`, `hex`, `hex code`, `color`, `colour` |
| light mode value | `light`, `light mode`, `day` |
| dark mode value | `dark`, `dark mode`, `night` |
| code (optional) | `code`, `code name`, `dart`, `dart name`, `identifier`, `member` |
| comment | `comment`, `description`, `desc`, `memo`, `note`, `remark` |

Use either a single `value` column or a pair of mode columns — see
[Light and dark](#light-and-dark).

If no name/value pair is recognised the generator falls back to column order
(1st = name, 2nd = value, 3rd = comment) and logs a warning.

Trailing `,,,` padding rows — which Excel loves to add — are ignored. The file
must be saved as **UTF-8**; Excel's default legacy code page (CP949 on Korean
Windows) is rejected with a message telling you to re-save as
"CSV UTF-8 (Comma delimited)". CRLF, LF and CR line endings all work.

### Color values

| Accepted | Result |
| --- | --- |
| `#RRGGBB` / `RRGGBB` | `Color(0xFFRRGGBB)` |
| `#RGB` | expanded, e.g. `#08F` → `Color(0xFF0088FF)` |
| `#RRGGBBAA` | alpha moved to the front: `#00000080` → `Color(0x80000000)` |
| `#RGBA` | expanded, then as above |

Eight digit values are read in the CSS / Figma order (`#RRGGBBAA`) by default.
Set `hex_alpha_position: leading` if your CSV uses Flutter's `#AARRGGBB` order.

Anything else — `rgba(...)`, named colors, a wrong digit count — **fails the
build** with the offending row number, rather than emitting Dart that will not
compile.

## Alias naming

The alias becomes a Dart identifier by one rule: **every non-alphanumeric run is
a word boundary, and the words become lowerCamelCase.** `/`, `-`, `_`, `.` and
spaces all separate words; an alias that is already camelCase is not re-cased.

| CSV alias | Dart name |
| --- | --- |
| `text/primary` | `textPrimary` |
| `gray-100` | `gray100` |
| `Blue Gray 50` | `blueGray50` |
| `brandAccentSubtle` | `brandAccentSubtle` |
| `TEXT/PRIMARY` | `textPrimary` |
| `100` | `color100` (an identifier cannot start with a digit) |
| `new` | `colorNew` (Dart keyword) |

Two aliases that would produce the same Dart name are a build error, not a
silent overwrite — the message names both aliases, so it is something you can
take straight back to whoever owns the CSV.

The generated file also carries the original alias in a doc comment above every
color, so the mapping stays readable from the Dart side without consulting the
CSV.

### The `code` column

The derived name is a default, not a rule you are stuck with. An optional `code`
column holds a member name that the designer and the developer have agreed on,
and it wins wherever it has a value:

```csv
alias,value,code,description
경고/배경,#FFF4E6,warningSurface,An alias with no possible Dart name
text/primary,#212529,,code left empty - derived as textPrimary
text-primary,#868E96,textSecondaryAlt,resolves a name collision
```

```dart
SemanticLight.warningSurface;
SemanticLight.byAlias['경고/배경']; // still keyed by the alias
```

This is the one place where the naming decision is written down rather than
inferred, so it is the right home for anything the automatic rule cannot or
should not decide: non-ASCII aliases (Dart identifiers are ASCII only), name
collisions, and renames you do not want to push back onto the designer.

A `code` value is taken literally — it is not re-cased — and is validated: it has
to start with a letter, contain only letters, digits and underscores, and not be
a Dart keyword. Anything else fails the build with the row number.

### Non-ASCII aliases

Dart identifiers are ASCII only, so Hangul, CJK, emoji and full-width
punctuation cannot survive into a name. What happens depends on what is left
over once they are dropped:

| Alias | `code` | Result |
| --- | --- | --- |
| `경고/배경` | `warningSurface` | `warningSurface` |
| `경고/배경` | — | **build error** — nothing usable is left |
| `경고/background` | — | `background`, with a **build warning**: the `경고` part is gone |
| `경고/background` | `warningSurface` | `warningSurface`, no warning |

The warning exists because that third row is the quiet one: a name does come
out, so nothing else would have mentioned that half the alias was discarded.
Two aliases that collapse to the same name are still a hard error.

### `byAlias`

Every palette also gets a lookup map keyed by the alias **exactly** as written
in the CSV:

```dart
final brand = SemanticLight.byAlias['text/primary'];
final gray = SemanticLight.byAlias['100'];
```

Useful for iterating a whole palette — a debug swatch screen, for example — and
for reaching a color by a string you already have.

## Light and dark

Give a row one value per mode instead of a single `value`, and the modes stay
side by side in the sheet — which is how a designer looks at them:

```csv
alias,light,dark,description
text/primary,#212529,#F1F3F5,Default body text
action/primary,#2C6BED,#4C8DFF,
```

`semantic.csv` then generates **three** classes:

```dart
SemanticLight.textPrimary   // static const, usable in a const context
SemanticDark.textPrimary    // static const
Semantic                    // ThemeExtension<Semantic>
```

The per-mode classes are ordinary `static const` holders, so a color that does
not depend on the theme costs nothing and needs no `BuildContext`. `Semantic` is
the opt-in layer for the ones that do:

```dart
MaterialApp(
  theme: ThemeData(extensions: const [Semantic.light]),
  darkTheme: ThemeData(extensions: const [Semantic.dark]),
);

// anywhere below the Theme
Text('Hi', style: TextStyle(color: Semantic.of(context).textPrimary));
```

`copyWith` and `lerp` are generated too, so the palette animates with the theme.

A row that is missing one of its mode values is a build error naming the row and
the mode; nothing silently falls back to the other mode. With only one mode
column present, just that one class is generated and no extension.

## Referencing another alias

A value of `{some-alias}` means "whatever that alias is", so a semantic palette
can be built on top of a primitive one instead of repeating hex codes:

```csv
# color_primitive.csv
name,value
gray-900,#212529
blue-500,#2C6BED
```

```csv
# semantic.csv
alias,light,dark
text/primary,{gray-900},{gray-100}
action/primary,{blue-500},{blue-400}
border/default,#DEE2E6,#343A40
```

Change `blue-500` once and every palette that references it is regenerated —
the referenced files are read through the build system, so build_runner knows
about the dependency.

* Any CSV in the same folder can be referenced; there is no ordering or import
  to declare, and a file can reference its own rows.
* References chain: `{a}` may point at an alias whose value is `{b}`. A loop is
  a build error that prints the cycle.
* An alias declared in two different CSVs is an ambiguous reference and fails
  the build naming both files.
* References resolve per mode. A referenced palette with a single `value` column
  supplies the same color to every mode; referencing a light/dark alias from a
  single-`value` palette is an error, since there would be no way to choose.
* Only a whole cell counts as a reference. `#FF{0}000` is just an invalid color.
* Literals and references mix freely in the same column.

## Options

Configure in your app's `build.yaml`:

```yaml
targets:
  $default:
    builders:
      project_color_palette:palette_generator:
        options:
          color_prefix: false
          hex_alpha_position: trailing
          generate_alias_map: true
```

| Option | Default | Meaning |
| --- | --- | --- |
| `color_prefix` | `false` | Prefix every member with `color` (`colorTextPrimary`). This was the fixed behavior before 2.0.0. |
| `hex_alpha_position` | `trailing` | `trailing` reads 8 digit values as `#RRGGBBAA`, `leading` as `#AARRGGBB`. |
| `generate_alias_map` | `true` | Emit `byAlias`. |

You can also narrow which files are read:

```yaml
        generate_for:
          - assets/color_palette/*.csv
```

## Not supported yet

* More than two modes (high contrast, brand themes).
* `ColorScheme` output. The generated `ThemeExtension` covers custom colors;
  mapping aliases onto Material's own `ColorScheme` slots is still manual.

## Migrating to 2.0.0

* Member names now keep the alias' word boundaries and no longer carry a forced
  `color` prefix: `colorWhite` → `white`, `colorPrimarybuttonbg` →
  `primaryButtonBg`. Set `color_prefix: true` to keep the old prefix (the word
  boundary fix applies either way).
* CSV file names no longer have to contain "color"; every `*.csv` in
  `assets/color_palette/` is generated.
* A malformed CSV now fails the build instead of logging a warning and quietly
  producing nothing.

## License

MIT License

Copyright (c) 2024 AQoong(cooldnjsdn@gmail.com)

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
