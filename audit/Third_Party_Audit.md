# Third-party audit

## Scope

- Scanned all non-import files under `assets/`.
- Searched the project source for copyright, license, attribution, source URL,
  Creative Commons, Apache, and GPL markers.
- Inspected the bundled TTF name table.
- Reviewed the Godot 4.3-stable upstream license and copyright inventory.

## Inventory

| Component | Evidence | License conclusion | Distribution action |
|---|---|---|---|
| Godot Engine 4.3 runtime | Windows export embeds the Godot runtime; export preset uses Godot 4.3 | MIT, with upstream third-party components documented in Godot `COPYRIGHT.txt` | Ship exact `LICENSE.txt` and `COPYRIGHT.txt` from `4.3-stable` in `licenses/` |
| WenQuanYi Micro Hei | `assets/fonts/wqy-microhei.ttf`, SHA-256 `4661F55D02EA656B3C9F8D4A078921B603A882B9279BF9E9CCAFE4EBACBA621E`; TTF name table reports 0.2.0-beta and Apache-2.0 | Apache License 2.0 selected from the font's licensing metadata | Ship Apache-2.0 text plus upstream release notes in `licenses/`; retain copyright notice |
| Project PNG assets | 848 PNG files supplied with the V10 project; no external attribution/license markers found | Project-specific assets under the repository MIT grant | Keep author attribution in README and MIT file |
| Audio/native plug-ins | None found | Not applicable | No notice required |
| Build-only tools | Godot editor/export templates, PowerShell, Python scripts, Git/GitHub CLI | Not redistributed as project assets | Document tool versions; do not vendor toolchains |

## Result

PASS. Required license and attribution texts are present in the repository,
referenced from `THIRD_PARTY_NOTICES.md`, and included in the Windows ZIP.
