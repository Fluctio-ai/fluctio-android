# gpt_markdown local fork

Vendored from pub `gpt_markdown` **1.3.1** (the app's pinned version) on
2026-11-19. The app depends on it via `dependency_overrides` in the root
pubspec.

## Why the fork

The package hardcodes `FontWeight.bold` (w700) for `**bold**` in its
renderers with no style-sheet knob (checked through 1.4.1). CJK glyphs
at w700 render as heavy black slabs; w600 matches the reference product's
(豆包) confident-but-quiet bold. User-approved tradeoff: a 55-file fork in
the tree, manual resync on renderer upgrades.

## The patch

One-token + structural changes, marked with `// fluctio-patch:` comments:

- **Inline bold** — `lib/plusparse/renderer.dart` (`MdBold`) and
  `lib/markdown_component.dart` (`BoldMd`, legacy pipeline): the package
  hardcodes `FontWeight.bold` (w700, a black slab in zh). Now
  `fontWeight: w500` + `FontVariation('wght', kFluctioBoldWeight)`
  (the variable-font axis delivers true intermediate values like 475 —
  `FontWeight` only quantizes to 100-steps). Tune ONE constant:
  `kFluctioBoldWeight` in renderer.dart (both pipelines read it).
- **Inline-code margin** — `InlineCodeStyle.margin` (new field,
  `inline_code.dart`): the chip is paint-only, so its `padding` grows
  into the neighbours' space and reads as an overlap. `margin` lays out
  thin placeholder spans on the run's outer edges via
  `inlineCodeSpan` (markdown_component.dart), pushing surrounding words
  aside. Default `EdgeInsets.symmetric(horizontal: 3)`.

## Resync procedure

When bumping the pinned renderer version:

1. Download the new pub archive; replace `lib/` here (keep this file,
   `pubspec.yaml`, `LICENSE`).
2. Re-apply the two `w600` edits (grep `fluctio-patch`).
3. Bump the version below 1.3.1 line in `pubspec.yaml` to
   `<new>+fluctio.1`.
4. Root `flutter pub get` (mirrored), then the full gate:
   analyze → test → a transcript visual check (bold runs).
