# Third-party notices

This file records the third-party components identified in the source tree and
Windows distribution of Pixel Pathfinder v2.0.0. Project-authored code and
project-specific game assets are licensed under the repository's
[MIT License](LICENSE); the components below retain their own licenses.

## Godot Engine 4.3

The Windows executable contains the Godot Engine runtime.

- Copyright (c) 2014-present Godot Engine contributors.
- Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
- License: MIT.
- Upstream: <https://github.com/godotengine/godot/tree/4.3-stable>
- License guidance: <https://godotengine.org/license/>
- Full engine license: [licenses/Godot-MIT.txt](licenses/Godot-MIT.txt)
- Engine third-party inventory and license texts:
  [licenses/Godot-COPYRIGHT.txt](licenses/Godot-COPYRIGHT.txt)

## WenQuanYi Micro Hei 0.2.0-beta

The UI embeds `assets/fonts/wqy-microhei.ttf`.

- Font name reported by the bundled file: WenQuanYi Micro Hei.
- Version reported by the bundled file: 0.2.0-beta.
- Copyright reported by the bundled file:
  - Digitized data copyright © 2007, Google Corporation.
  - Copyright © 2008-2009 WenQuanYi Board of Trustees and Qianqian Fang.
- License reported by the bundled file: Apache License, Version 2.0.
- Bundled file SHA-256:
  `4661F55D02EA656B3C9F8D4A078921B603A882B9279BF9E9CCAFE4EBACBA621E`.
- Upstream project: <https://wenq.org/>
- Upstream source mirror: <https://github.com/anthonyfok/fonts-wqy-microhei>
- Full selected license:
  [licenses/WenQuanYi-MicroHei-Apache-2.0.txt](licenses/WenQuanYi-MicroHei-Apache-2.0.txt)
- Upstream release notes and credits:
  [licenses/WenQuanYi-MicroHei-README.txt](licenses/WenQuanYi-MicroHei-README.txt)

## Audit result

The repository contains one font file and no third-party audio libraries,
gameplay plug-ins, native extensions, or separately sourced asset packs.
The PNG files under `assets/` are project-specific supplied/generated game
art with no external license markers in the V10 input. Runtime screenshots in
`screenshots/` are captures of this project. Build-only tools (the Godot
editor, PowerShell, Python validation scripts, Git, and GitHub CLI) are not
redistributed as project assets.

This inventory is a good-faith engineering audit, not legal advice.
