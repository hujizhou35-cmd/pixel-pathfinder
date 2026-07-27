# 装备像素资源管线

V10 将运行时程序化装备绘制替换为可审查的静态像素资源。运行时只读取注册表中的固定路径，不依赖 CSV 或 Python 动态生成。

- `assets/equipment_visuals/icons/` 保存 20×20 装备图标及元素粒子源。
- `assets/equipment_visuals/layers/` 保存 40×208 的四帧角色装备层。
- `assets/equipment_visuals/masks/` 保存头盔覆盖与可见头发遮罩。
- `assets/equipment_visuals/hero/` 保存基础身体、脸、头发、手臂和远程武器姿势。
- `assets/equipment_visuals/manifests/` 保存 175 件装备的来源与路径清单。
- `tools/` 中的校验脚本检查尺寸、透明度、路径、覆盖关系和资源完整性。

仓库不保存用于人工审阅的放大图、调试叠层和 contact sheet；这些文件可以由源资源和工具重新生成。
