# V2 UI regression

## Reproduced defects

1. The original title button group started at y=440 with six 42 px buttons and
   five 10 px gaps: a 302 px natural height ending at y=742. The Exit button
   therefore clipped at 720p.
2. The original Help builder appended every line directly to the modal's outer
   VBox and had no ScrollContainer, causing overflow and hiding the close
   action.

The two referenced Issue image files were not present in the workspace, so
post-fix runtime reproduction is used as evidence instead of claiming the
missing attachments were inspected.

## Implemented repair

- Title hero base y: 264 → 244.
- Title button group: y=434, six 42 px buttons, 6 px gaps, bottom y=716.
- Named controls make bounds regression deterministic.
- Help hierarchy:
  - `HelpModalRoot`
  - fixed `HelpTitle`
  - `HelpScrollContainer`
  - `HelpContentVBox`
  - fixed `HelpButtonRow` / `HelpCloseButton`
- Help panel minimum: 900×620, centered inside the logical viewport.
- Keyboard scroll: arrows, PageUp/PageDown, Home, End.

## Automated evidence

Result: **97/97 assertions passed**.

Screenshots:

- `test/shots_v2_ui/title_with_save_1280x720.png`
- `test/shots_v2_ui/title_without_save_1280x720.png`
- `test/shots_v2_ui/title_1366x768.png`
- `test/shots_v2_ui/title_1600x900.png`
- `test/shots_v2_ui/title_1920x1080.png`
- `test/shots_v2_ui/help_top.png`
- `test/shots_v2_ui/help_middle.png`
- `test/shots_v2_ui/help_bottom_close_visible.png`
- `test/shots_v2_ui/help_1280x720.png`
- `test/shots_v2_ui/help_overlay_stack_return.png`

Because the project deliberately uses Godot `viewport` stretch with a
1280×720 content scale, larger physical windows retain 1280×720 render-target
captures. The test separately asserted the actual physical Window size before
checking the logical UI bounds.

## Manual visual review

- Six buttons and full Exit text visible with a save.
- Five buttons and full Exit text visible without a save.
- No hero/slot/button overlap.
- Help title and close remain fixed at top/middle/bottom positions.
- Scrollbar position changes correctly and text remains readable.
- Underlying modal returns after Help closes.

Result: **PASS**
