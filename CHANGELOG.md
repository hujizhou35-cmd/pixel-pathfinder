# Changelog

All notable public-release changes are documented here.

## [2.0.0] - 2026-07-27

### Fixed

- Repositioned the title hero and compacted the six-button title layout so the
  complete Exit button remains visible at 1280×720 with and without a save.
- Rebuilt Help as a bounded modal with a fixed title, a vertical
  `ScrollContainer`, a dedicated content `VBoxContainer`, and a fixed close
  button outside the scrolling region.
- Added keyboard scrolling for arrows, PageUp/PageDown, Home, and End while
  preserving Esc and modal-stack restoration.

### Added

- Added automated V2 UI regression with runtime screenshots across four
  physical window sizes and saved/empty title states.
- Added a bilingual GitHub homepage, post-fix runtime screenshots, release
  notes, MIT license, and audited third-party notices.
- Added reproducible Windows x64 release staging with embedded PCK, Windows
  file/product version `2.0.0.0`, ZIP packaging, and SHA-256 sums.

### Verified

- V2 UI regression: 97 assertions passed.
- Full gameplay smoke suite: all checks passed.
- Protected gameplay/data/save files: 0 differences.
- In-game content label remains `v5.0 · 远征路线版`.

[2.0.0]: https://github.com/hujizhou35-cmd/pixel-pathfinder/releases/tag/v2.0.0
