# V10 release task change log

## Runtime changes

- `scripts/ui/title_view.gd`
  - Moved hero upward by 20 logical pixels.
  - Replaced the overflowing button geometry with a named 282 px group at
    y=434 and 6 px separation.
  - Added stable control names for automated bounds testing.
- `scripts/ui/modal_layer.gd`
  - Bounded and centered Help at 900×620.
  - Added a vertical ScrollContainer and dedicated inner content VBox.
  - Kept title and Close/Esc outside the scrolling region.
  - Added keyboard scrolling.

No combat, equipment, map generation, game data, or save implementation file
changed.

## Validation/release changes

- Added V2 UI regression scene and runtime evidence.
- Updated Windows export versions to `2.0.0.0`.
- Added explicit rcedit resolution, x64/embedded-PCK checks, ZIP packaging,
  and SHA-256 generation.
- Added bilingual README, real runtime screenshots, changelog, release notes,
  MIT license, third-party notices, and exact upstream license files.
- Updated `.gitignore` to exclude builds, releases, toolchains, executables,
  archives, saves, secrets, and backups.
