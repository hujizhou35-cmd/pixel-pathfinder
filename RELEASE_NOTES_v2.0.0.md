# Pixel Pathfinder v2.0.0 / 像素探路者 v2.0.0

This release repairs the two blocking UI defects, publishes the complete V10
source and post-fix runtime evidence, and provides a portable Windows x64
single-executable build.

本次发行修复了两个阻断级 UI 问题，发布完整 V10 源码与修复后真实运行证据，
并提供 Windows x64 免安装单 EXE。

## Highlights / 重点

- The complete six-button title group, including Exit Game, is visible at
  1280×720 with or without a save.
- Help now uses a fixed title, a scrollable content region, and a fixed
  `Close [Esc]` button.
- Mouse wheel, arrows, PageUp/PageDown, Home, End, Esc, and modal-stack return
  were verified.
- Windows FileVersion and ProductVersion are both `2.0.0.0`; the public tag is
  `v2.0.0`; the established in-game label remains
  `v5.0 · 远征路线版`.
- 标题页“退出游戏”完整可见；Help 可滚动且关闭按钮固定；Esc 与叠层返回正常。

## Downloads / 下载

| Asset | Purpose |
|---|---|
| `PixelPathfinder_v2.0.0_Windows_x64.exe` | Portable Windows 10/11 x64 executable with embedded PCK |
| `PixelPathfinder_v2.0.0_Windows_x64.zip` | Recommended download with executable, README, MIT license, and third-party notices |
| `SHA256SUMS.txt` | SHA-256 integrity values for the EXE and ZIP |

Verify on PowerShell:

```powershell
Get-FileHash .\PixelPathfinder_v2.0.0_Windows_x64.zip -Algorithm SHA256
```

## Verification / 验证

- V2 UI runtime regression: 97/97 assertions passed.
- Physical window coverage: 1280×720, 1366×768, 1600×900, 1920×1080.
- Full gameplay smoke suite: all checks passed.
- Protected gameplay, combat, equipment, data, and save scripts: 0 differences.
- Windows output: x86_64 PE, embedded PCK, no sidecar `.pck`.
- Runtime screenshots were captured after the fix; no concept art is presented
  as gameplay.

## Compatibility and saves / 兼容性与存档

- Target: Windows 10/11 x64.
- Existing three-slot saves are not migrated or rewritten by this UI fix.
- Backing up saves before replacing an older executable is still recommended.

## Known limitations / 已知限制

- The executable is not code-signed, so Windows SmartScreen may show a warning.
- This release provides a portable build, not an installer.
- The game renders through a 1280×720 logical viewport and scales it to larger
  physical windows by design.

## Team

- Jizhou Hu — programming code — China Medical University
- Hebin Cui — game design planning — China Medical University
- Chengyao Zhu — programming code — Dalian University of Technology

Project license: [MIT](LICENSE). Third-party notices:
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
