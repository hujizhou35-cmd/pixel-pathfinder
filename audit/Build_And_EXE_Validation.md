# Build and EXE validation

## Final build

- Date: 2026-07-27
- Godot: `4.3.stable.official.77dcf97d8`
- Export preset: `Windows Desktop`
- Architecture: x86_64 (`PE Machine 0x8664`)
- PCK mode: embedded
- Sidecar `.pck` files: 0
- rcedit: 2.0.0
- FileVersion: `2.0.0.0`
- ProductVersion: `2.0.0.0`
- ProductName: `Pixel Pathfinder`
- CompanyName: `Pixel Pathfinder Contributors`
- Copyright: `Copyright (c) 2026 Jizhou Hu, Hebin Cui, Chengyao Zhu`

## Release assets

| File | Bytes | SHA-256 |
|---|---:|---|
| `PixelPathfinder_v2.0.0_Windows_x64.exe` | 163,884,672 | `2C637A575C07C54636FE898598F8CD553EBB7CB0EDDCD2F7607DA293E4CA527E` |
| `PixelPathfinder_v2.0.0_Windows_x64.zip` | 109,112,433 | `AB63E7BE141BDD5B14DE08038C9797115ED3C7227BD3CC305D055E61B8EDAEEA` |

`SHA256SUMS.txt` contains the same two values.

## ZIP validation

The ZIP contains one top-level directory and eight files:

- Windows x64 EXE
- `README.txt`
- Project `LICENSE`
- `THIRD_PARTY_NOTICES.md`
- Godot MIT license
- Godot third-party copyright/license inventory
- WenQuanYi Micro Hei Apache-2.0 text
- WenQuanYi Micro Hei upstream README/credits

## Build-gate history

The first formal export generated a valid x86_64 embedded-PCK executable, but
the gate rejected it because Godot could not find rcedit and the PE reported
FileVersion `4.3`. That artifact was not published. The build script was
updated to locate/call rcedit explicitly and read the PE version resources
back before packaging. The repeat export passed with both versions at
`2.0.0.0`.

## Clean launch

The final ZIP was extracted into a new directory and its EXE launched from
that extracted directory. It exited with code 0 after 180 frames, created no
sidecar PCK, and required no files outside the eight packaged files.

Result: **PASS**
