# Windows EXE 导出指南

项目已提供经过验证的 Godot 4.3 Windows x64 自动构建脚本；也可以在编辑器中手动导出。

## 路线 A：Godot 编辑器（最简单，约 5 分钟）

1. 下载 **Godot 4.3 stable**（标准版即可，无需 .NET）：https://godotengine.org/download/windows/
2. 打开 Godot → 「导入」→ 选择本项目文件夹中的 `project.godot` → 打开后先 **F5 试运行**确认正常
3. 菜单「编辑器 → 管理导出模板」→ 下载并安装 4.3 stable 导出模板（一次性，约 500MB）
4. 菜单「项目 → 导出」→ 已预置 **Windows Desktop** 预设（`export_presets.cfg`）
5. 点「导出项目」→ 输出 `build/PixelPathfinder.exe`（已配置 embed_pck，单文件即可运行）

> v2.0.0 发布要求 Windows FileVersion / ProductVersion 均为
> `2.0.0.0`。缺少 `rcedit-x64.exe` 会使版本资源不正确，不能忽略。
> 正式发布请使用下方 `build_windows.ps1`，它会显式调用并校验 rcedit。

## 路线 B：命令行自动构建（推荐）

准备 Godot 4.3、匹配的导出模板和 rcedit 后，在项目根目录执行：

```powershell
# 1. 下载 Godot 4.3 与导出模板
Invoke-WebRequest https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip -OutFile godot.zip
Expand-Archive godot.zip -DestinationPath godot
Invoke-WebRequest https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz -OutFile templates.tpz

# 2. 安装导出模板（解压到模板目录）
Expand-Archive templates.tpz -DestinationPath tpz   # tpz 实为 zip
New-Item -ItemType Directory -Force "$env:APPDATA\Godot\export_templates\4.3.stable"
Move-Item tpz\templates\* "$env:APPDATA\Godot\export_templates\4.3.stable\"

# 3. 运行测试、导出、版本校验、ZIP 与 SHA-256 封装
.\build_windows.ps1 `
  -GodotExe "..\godot\Godot_v4.3-stable_win64_console.exe" `
  -RceditExe "..\rcedit\rcedit-x64.exe"
```

Linux/macOS 上同理，项目内 `build.sh` 已写好对应流程（需 `godot` 在 PATH 中）。

## 自检清单（导出前在编辑器里跑一遍）

- 标题 → 开始新远征 → 地图出现 5 行节点
- 打一场战斗：点击敌人换目标、数字键 1-4、伤害数字、战斗日志
- 进商店买装备、B 开背包强化、宝箱与事件弹窗
- 击败首领 → 区域通关 → 下一区域背景与天气切换
- 关闭游戏重开 → 标题出现「继续远征」→ 读档回到地图原位

## 常见问题

- **中文显示为方块**：不会发生 — 字体 `assets/fonts/wqy-microhei.ttf` 已内置并设为全局主题字体。
- **导出后存档在哪**：`%APPDATA%\Godot\app_userdata\Pixel Pathfinder\pixel_pathfinder_save.json`
- **想要无控制台窗口**：导出预设中 `debug/export_console_wrapper` 改为 0（或导出对话框里取消勾选 console wrapper）。
