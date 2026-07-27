<p align="center">
  <img src="docs/images/README_Banner.png" alt="《像素探路者》标题画面" width="100%">
</p>

<h1 align="center">像素探路者 · Pixel Pathfinder</h1>

<p align="center">
  在路线、战斗与装备之间做取舍，走完一轮又一轮不断强化的像素远征。
</p>

<p align="center">
  <a href="https://github.com/hujizhou35-cmd/pixel-pathfinder/releases/latest"><img alt="下载 v2.0.0" src="https://img.shields.io/badge/下载-v2.0.0-f2b84b"></a>
  <img alt="Windows x64" src="https://img.shields.io/badge/平台-Windows%20x64-2d78d4">
  <img alt="Godot 4.3" src="https://img.shields.io/badge/Godot-4.3-478cbf">
  <a href="LICENSE"><img alt="MIT License" src="https://img.shields.io/badge/许可-MIT-4c9a6a"></a>
</p>

<p align="center">
  <strong>简体中文</strong> · <a href="README_en.md">English</a> ·
  <a href="https://github.com/hujizhou35-cmd/pixel-pathfinder/releases">全部版本</a>
</p>

## 游戏简介

《像素探路者》是一款使用 Godot 4.3 制作的回合制像素 Roguelite。每次远征都从路线选择开始：侦察前方敌人，在商店和事件之间规划补给，通过战斗收集装备，最后挑战区域首领。五个区域通关后，角色会带着现有构筑进入更强的下一周目。

**路线选择 → 回合战斗 → 获取装备 → 调整构筑 → 挑战首领 → 强化周目**

## 核心玩法

| 系统 | 它如何影响远征 |
|---|---|
| 路线探索 | 在节点地图上移动、折返和侦察；已经完成的战斗不会重复，但道路仍可通行。 |
| 回合战斗 | 普攻、盾击、防御和药水有不同的先后手与冷却；剑、斧、弓采用不同的攻击节奏。 |
| 装备构筑 | 175 件图鉴装备覆盖六个部位，并组合稀有度、强化、词条、套装、熔炼和精铸。 |
| 元素与周目 | 雷、森、冰、火、土彼此克制并附带触发效果；通关后敌人与掉落继续成长。 |

新远征可以分配初始天赋并命名角色。游戏提供三个自动存档位；阵亡会损失部分金币并重置当前区域，但装备与其他区域进度会保留。

## 实机画面

| 路线地图 | 回合战斗 |
|---|---|
| ![路线地图](docs/images/map.png) | ![回合战斗](docs/images/combat.png) |

| 背包与构筑 | 可搜索图鉴 |
|---|---|
| ![背包](docs/images/inventory.png) | ![图鉴](docs/images/codex.png) |

| 装备界面 | 角色装备外观 |
|---|---|
| ![装备界面](docs/images/equipment.png) | ![角色装备外观](docs/images/hero.png) |

## 下载与运行

打开 [Releases](https://github.com/hujizhou35-cmd/pixel-pathfinder/releases/latest)，按需要选择：

- `PixelPathfinder-v2.0.0-Windows-x64.exe`：Windows 10/11 x64 单文件版本，双击即可运行。
- `PixelPathfinder-v2.0.0-Full.zip`：同版 EXE、完整 Godot 源码、文档与许可。
- `SHA256SUMS.txt`：下载文件的 SHA-256 校验值。

程序未进行代码签名，Windows SmartScreen 可能显示提示。存档位于 Godot 的 `user://` 目录；替换旧版前建议先备份存档。

## 操作

| 场景 | 按键 |
|---|---|
| 路线地图 | `WASD` / 方向键移动，`E` / `Enter` / `Space` 进入节点 |
| 战斗 | `1` 普攻，`2` 盾击，`3` 防御，`4` 药水 |
| 全局 | `B` 背包，`C` 图鉴，`V` 属性，`Esc` 关闭或返回 |
| 帮助 | 滚轮、方向键、`PageUp` / `PageDown`、`Home` / `End` |

## 从源码运行

需要 Godot **4.3 stable**：

```powershell
git clone https://github.com/hujizhou35-cmd/pixel-pathfinder.git
cd pixel-pathfinder
godot --editor project.godot
```

测试、导出和目录说明见 [`docs/BUILDING.md`](docs/BUILDING.md)。完整机制见 [`docs/GAMEPLAY.md`](docs/GAMEPLAY.md)，逐版变化见 [`docs/VERSION_HISTORY.md`](docs/VERSION_HISTORY.md)。

## 团队

- Jizhou Hu — 程序开发 — China Medical University
- Hebin Cui — 游戏设计 — China Medical University
- Chengyao Zhu — 程序开发 — Dalian University of Technology

项目代码及项目专用资源采用 [MIT License](LICENSE)。Godot 与内置字体的许可信息见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
