READY_FOR_USER_RUNTIME_REVIEW

- 实际修改：仅人物/装备视觉、直接相关 UI 颜色与整数缩放、视觉/回归测试、Windows 构建配置。
- 保护区：26/26 文件 SHA-256 不变。
- PATCH4：35 个基底族、5 元素、175 个最终图标通过注册表接入真实 `PixelArt.item_icon()` / `PixelArt.hero_texture()` 路径。
- 无装备一致性：冻结中性英雄逐像素等价测试通过。
- 头盔：五种轮廓已重绘；四类头发遮罩/每顶头盔已接入；泄漏检查为零。
- 其他穿戴：铠甲、裤子、两足鞋、配饰、弓/弩手臂层均完成四帧贴合。
- 武器与元素：短/长武器可区分；金木水火土只改变粒子层。
- 稀有度：只通过文字颜色、标签和说明体现；无边框、光环或图像变化。
- 原始测试：smoke 连续两轮及最终构建内回归通过；shot_test 生成 35 张真实运行截图。
- 新增测试：视觉集成 2618/2618 assertions；17/17 装备运行时截图；793/793 资产检查；缓存清空重导入后再通过。
- 真实运行截图：`Runtime_Screenshots/`（源为 `test/shots_equipment_runtime/`）。
- 导出命令：`Godot_v4.3-stable_win64_console.exe --headless --path . --export-release "Windows Desktop" build/PixelPathfinder.exe`
- EXE：`161752256` bytes；SHA-256 `019FF8D94364D41B7A9DD46FB9C92FA119B1EF9D92D8463D224F56BD818B6EBD`；最后写入 UTC `2026-07-27T10:03:37.4801783Z`。
- Windows 实际启动：已完成标题→新远征→序章→地图，并关闭后第二次启动。
- 单文件：x86_64 Release，PCK 已嵌入，旁置 PCK 为 0。
- 剩余 P0/P1/P2：0。
- 剩余 P3：仅不同显示环境与玩家审美下的主观体感，需用户最终运行确认。

声明：

1. 只修改了人物和装备相关视觉及其直接测试、UI颜色和构建配置；
2. 未修改游戏数值、战斗、地图、掉落、存档和装备逻辑；
3. 所有标注为运行截图的图片均来自真实 Godot 运行；
4. 最终用户只需双击 `PixelPathfinder.exe`；
5. 稀有度只通过文字颜色、标签和说明体现；
6. 最终运行体验仍由用户确认。
