<p align="center">
  <img src="screenshots/README_Banner.png" alt="Pixel Pathfinder title screen" width="100%">
</p>

<h1 align="center">Pixel Pathfinder · 像素探路者</h1>

<p align="center">
  A route-planning pixel RPG with turn-based combat, equipment-driven builds,
  five elemental regions, and endless expedition cycles.
</p>

<p align="center">
  <a href="https://github.com/hujizhou35-cmd/pixel-pathfinder/releases/tag/v2.0.0"><img alt="Release v2.0.0" src="https://img.shields.io/badge/release-v2.0.0-f2b84b"></a>
  <img alt="Windows x64" src="https://img.shields.io/badge/platform-Windows%20x64-2d78d4">
  <img alt="Godot 4.3" src="https://img.shields.io/badge/Godot-4.3-478cbf">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/license-MIT-4c9a6a"></a>
</p>

<p align="center">
  <strong>English</strong> · <a href="README_zh.md">简体中文</a> ·
  <a href="https://github.com/hujizhou35-cmd/pixel-pathfinder/releases/latest">Latest release</a>
</p>

## Play the Windows build

1. Open the [v2.0.0 release](https://github.com/hujizhou35-cmd/pixel-pathfinder/releases/tag/v2.0.0).
2. Download `PixelPathfinder_v2.0.0_Windows_x64.zip`.
3. Verify it against `SHA256SUMS.txt`, extract it, and run
   `PixelPathfinder_v2.0.0_Windows_x64.exe`.

The release is a portable Windows 10/11 x64 build. It has no installer and no
sidecar PCK: the game data is embedded in the executable.

> Version note: `v2.0.0` is the public GitHub release version. The title screen
> intentionally keeps the established in-game content label
> `v5.0 · 远征路线版`.

## What is in the expedition?

- Explore node-based routes across five regions, with revisitable paths,
  scouting, shops, events, elites, and bosses.
- Fight turn-based battles with attack, shield bash, guard, and potion actions.
- Build around 175 catalogued equipment entries, six equipment slots, rarity,
  upgrades, affixes, forging, smelting, and five elemental relationships.
- Allocate starting talents, earn milestone perks, and keep progressing through
  strengthened endless cycles.
- Use three save slots with automatic progress saving and retained equipment.
- Read the searchable codex for equipment, affixes, monsters, bosses, events,
  elements, and combat mechanics.

## v2.0.0 UI fixes

- The complete six-button title group—including **Exit Game**—now stays within
  the 1280×720 logical canvas with or without a save.
- The Help window now has a fixed title, a keyboard/mouse-scrollable content
  region, and a fixed `Close [Esc]` button.
- The modal stack still restores the underlying dialog after Help closes.
- Runtime regression covered 1280×720, 1366×768, 1600×900, and 1920×1080
  physical window sizes.

## Real runtime screenshots

All images below were captured from the post-fix Godot runtime. The banner is
the real title screen, not a concept image.

| Title | Route map |
|---|---|
| ![Title screen](screenshots/title_v2.png) | ![Route map](screenshots/map.png) |

| Combat | Inventory |
|---|---|
| ![Combat](screenshots/combat.png) | ![Inventory](screenshots/inventory.png) |

| Searchable codex | Equipment interface |
|---|---|
| ![Codex](screenshots/codex.png) | ![Equipment](screenshots/equipment.png) |

<p align="center">
  <img src="screenshots/hero.png" alt="Runtime equipment appearance matrix" width="360">
</p>

## Controls

| Context | Input |
|---|---|
| Route map | `WASD` or arrow keys to move, `E` / `Enter` / `Space` to enter |
| Combat | `1` attack, `2` shield bash, `3` guard, `4` potion |
| Global | `B` inventory, `C` codex, `V` stats, `Esc` close/back |
| Help | Mouse wheel, arrows, `PageUp` / `PageDown`, `Home` / `End` |

## Run from source

Requirements:

- Godot Engine **4.3 stable** with the Windows x64 export templates.
- PowerShell 5.1+ for the release build script.

```powershell
git clone https://github.com/hujizhou35-cmd/pixel-pathfinder.git
cd pixel-pathfinder
godot --editor project.godot
```

Build, test, export, and stage the Windows release assets:

```powershell
.\build_windows.ps1 -GodotExe "C:\path\to\Godot_v4.3-stable_win64_console.exe"
```

The script runs the gameplay smoke test and visual integration test, exports an
x86_64 PE with embedded PCK, validates Windows file/product version
`2.0.0.0`, and creates:

- `release/PixelPathfinder_v2.0.0_Windows_x64.exe`
- `release/PixelPathfinder_v2.0.0_Windows_x64.zip`
- `release/SHA256SUMS.txt`

Targeted UI regression:

```powershell
godot --path . res://test/v2_ui_test.tscn
```

## Verification evidence

- V2 UI regression: **97 assertions passed**.
- Full gameplay smoke suite: all checks passed.
- Protected gameplay/data/save scripts: **0 hash differences**.
- Release checks include x86_64 PE, embedded PCK, file/product version,
  SHA-256, ZIP contents, and a clean launch from the tagged source.
- Detailed local evidence is kept in [`audit/`](audit/) and release
  verification in [`docs/`](docs/).

## Repository layout

```text
assets/       Game art, data, localization, and bundled font
scenes/       Godot scenes
scripts/      Gameplay, combat, equipment, FX, and UI code
test/         Smoke, visual, screenshot, and V2 UI regression scenes
screenshots/  Post-fix runtime screenshots used by this README
licenses/     Exact upstream third-party license/copyright texts
audit/        Reproducible task evidence and hash audits
docs/         Release and verification documents
```

## Team

- **Jizhou Hu** — programming code — China Medical University
- **Hebin Cui** — game design planning — China Medical University
- **Chengyao Zhu** — programming code — Dalian University of Technology

## License and third-party software

Pixel Pathfinder project code and project-specific assets are released under
the [MIT License](LICENSE).

The Windows binary includes the MIT-licensed Godot Engine runtime and embeds
WenQuanYi Micro Hei 0.2.0-beta under Apache-2.0. Copyright notices, exact
upstream texts, file hashes, and audit scope are recorded in
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) and [`licenses/`](licenses/).
