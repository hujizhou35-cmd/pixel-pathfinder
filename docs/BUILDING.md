# 从源码运行、测试与导出

## 环境

- Godot Engine 4.3 stable。
- Windows 导出需要匹配的 Godot 4.3 Windows x64 Export Templates。
- 一键发行脚本需要 PowerShell 5.1+ 与 `rcedit-x64.exe`。

## 打开项目

```powershell
git clone https://github.com/hujizhou35-cmd/pixel-pathfinder.git
cd pixel-pathfinder
godot --editor project.godot
```

首次打开时 Godot 会生成 `.godot/` 缓存。该目录不会提交到 Git。

## 测试

```powershell
godot --headless --path . res://tests/smoke_test.tscn
godot --headless --path . res://tests/visual_integration_test.tscn
godot --path . res://tests/v2_ui_test.tscn
```

测试截图写入 `tests/shots*`，属于可再生成输出，不进入仓库。

## Windows x64 导出

```powershell
.\tools\release\build_windows.ps1 `
  -GodotExe "C:\path\to\Godot_v4.3-stable_win64_console.exe" `
  -RceditExe "C:\path\to\rcedit-x64.exe"
```

脚本依次执行导入、玩法冒烟测试、视觉集成测试和嵌入式 PCK 导出，并检查 PE 架构、Windows 文件版本与 SHA-256。输出位于 `release/`，构建报告位于 `build/reports/`。

## 源码目录

```text
assets/    运行时美术、字体和资源导入配置
scenes/    Godot 场景
scripts/   玩法、战斗、装备、地图、特效与 UI
tests/     可重复执行的测试场景与脚本
docs/      玩法、版本、构建和美术管线文档
tools/     资源验证与发行工具
licenses/  第三方许可原文
```
