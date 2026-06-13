# upgrade max4 设计规格（v7.0）

像素探路者（Godot 4.6，全程序化）。本规格实现 `upgrade max4.md` 三阶段改动。
存档 version 7（新增 cycle-boss 进度字段）。

## 贯穿要求：文档同步
每一项机制改动都必须同步更新以下处的说明文案，保证逻辑/数值一致、不自相矛盾：
- 帮助页 `modal_layer._build_help`
- 图鉴机制页 `modal_layer._codex_mechanics`
- 装备/精铸/熔炼相关按钮 tooltip 与弹窗正文（含参考图 `f4b07…` 所示"精铸"描述）

---

## 阶段一 — 周目 Boss 与终局 CG

### CG 资源
- 拷贝 `../final CG/0-9.png` → `assets/cg/19.png … 28.png`（并生成 .import）。
- 映射：
  - 19 = fc0 噩梦苏醒旁白
  - 20/21 = 八岐大蛇 遇见/战败
  - 22/23 = 九尾狐 遇见/战败
  - 24/25 = 巨大三头石像 遇见/战败
  - 26/27 = 终末虚空兽 遇见/战败
  - 28 = fc9 新周目欢迎
- `GameData.CG_DATA`：改写 13 文案（删"欢迎新周目"段，结尾"……这一刻，他以为远征已经结束。"）；新增 19-28 条目，title+text 取自 `final CG/CG字幕.md`。

### 周目 Boss 数据 `GameData.CYCLE_BOSSES`（4 条）
每条：`{ key, name, sprite, palette, traits, hp_mult, atk_mult, def_mult, encounter_cg, defeat_cg }`
- orochi 八岐大蛇 → 20/21
- kitsune 九尾狐 → 22/23
- colossus 巨大三头石像 → 24/25
- voidbeast 终末虚空兽 → 26/27

选择规则（按已通关周目数 `cleared_cycle`）：0→orochi,1→kitsune,2→colossus,3→voidbeast，≥4→四者随机。

### 流程（`game_state.gd`）
区域 5 最终 Boss 战胜后，`region_clear()` 仍播 `CG_FINALE [11,12,13]`，随后改为进入周目 Boss 序列而非直接 `_region_clear_continue`：
1. `_on_cg_finished("region_clear")`（且 region==末区）→ 选定周目 boss，存 `_cycle_boss_key`，播 `[19, encounter_cg]`，tag `cycle_encounter`。
2. CG 完 → 启动周目 Boss 战（`CombatManager.setup_cycle_boss(cycle, boss_def)`），设 `_in_cycle_boss = true`。
3. 战胜（`combat_ended(true)` 且 `_in_cycle_boss`）→ 播 `[defeat_cg, 28]`，tag `cycle_victory`。
4. CG 完（tag `cycle_victory`）→ `_region_clear_continue()`（cycle++ / 通关弹窗 / 新周目）。清 `_in_cycle_boss`。
5. 战败给周目 Boss：照常 `player_defeated()`（cycle 未 +1，region 仍末区，回区域 5 起点重打）；清 `_in_cycle_boss`。

### 周目 Boss 战斗
- `CombatManager.setup_cycle_boss`：构造单一 foe（custom name/sprite/palette/traits），stats 以 `enemy_stats_for`(region=末区, cycle) 为基底再乘 boss 段，最终 ≈ 区域 Boss 1.5×，并随 cycle 成长；护盾遵守阶段三上限。foe 带 `cycle_boss=true`、`cycle_sprite=key`。
- 精灵：`pixel_art.gd` 新增 `cycle_boss_texture(sprite_key, palette)` + `_draw_orochi/_draw_kitsune/_draw_colossus/_draw_voidbeast`，独特剪影、加大画布、`_apply_outline` 描边、2 帧呼吸动画。
- `combat_view._make_enemy_slot`：`e.get("cycle_boss")` → 用 `cycle_boss_texture`。

### CG 配乐（1.3）
- `sfx.gd` 新增两段更响配乐：`_cg_music_tense`（遇见，紧张低沉）、`_cg_music_triumph`（战胜，慷慨激昂），音量约 -6dB（默认叙事 -13dB 不变）。
- `start_cg_music(mood="narrative")`；`cg_layer.play` 依 tag 选 mood：`cycle_encounter`→tense，`cycle_victory`→triumph，其余→narrative。

---

## 阶段二 — 背包重做（`modal_layer._build_bag`）

整体放大（加宽 bag 弹窗面板）。两段式：

**上半（HBox）**
- 左：英雄立绘 `PixelArt.hero_texture(GameState.equipment)` + 名称 `hero_name` + 等阶 + 属性概览（生命/攻击/防御/暴击/闪避等）+「属性详情」按钮（→ stats 弹窗）。
- 右：6 装备槽（weapon, helmet, chest, hands, pants, boots）图标盒，点击→ `equip_detail`。

**下半（物品栏）**
- 头部："物品栏 X/容量"、分类页签（全部/武器/衣物/配饰）、一键整理按钮。
- 物品**每行 3 件**网格；每格折叠态显示图标+名称+稀有度色；点击展开显示特性词条 + 操作按钮（装备/强化/分解(+精粹)/熔炼/精铸/出售）。展开态互斥或独立（实现从简：点击 toggle 该格展开）。
- 词条精华区保留（可置于物品栏下方）。

### 精铸增量（2.2，`game_state.refine_item`）
- 改为：`tier_eff = min(best_eff, tier_eff+1)`；扣 5 精粹；`stats = baseline_stats(item, tier_eff)`；`value` 更新。每次只 +1 区域。
- 文案：按钮"精铸 +1区域(5精粹)"、tooltip、帮助、图鉴、参考图所示描述全部改为"每 5 精粹精铸一次提升 1 个区域基准"。

### 熔炼自选词条（2.3）
- `game_state.smelt_bag_item(index, affix_key)`：按传入词条提取（不再随机）。
- `modal_layer._build_smelt`：列出该装备每条词条按钮，点选即提取（沿用 purge 交互）。

---

## 阶段三 — 怪物护盾上限

`combat_state.gd` 新增 `_cap_enemy_shield(e)`：`e.shield = min(e.shield, max(1, floor(e.maxhp*0.6)))`，在所有怪物护盾获取处（初始/shielded/guard/bash/shield_phase）调用；`combat_manager` 初始护盾同样封顶。图鉴机制页"护盾"说明加注"怪物护盾 ≤ 生命上限 60%"。

---

## 验证
1. `godot --headless --path . --import`（刷新 class 缓存）。
2. 冒烟测试 `test/smoke_test.tscn`：周目 boss 选择/护盾上限/精铸增量/熔炼自选 逻辑断言。
3. 截图自检 `test/shot_test.tscn`：背包新布局、周目 Boss 精灵、CG。
4. 导出 `build/PixelPathfinder.exe`。

## 存档兼容
- version 7：新增 `_in_cycle_boss`/`_cycle_boss_key` 不入存档（运行态）；旧档 load 默认无周目 boss。
- 旧档 `seen_cgs` 自动含 intro；CG 19-28 不入 seen-gate（每周目都播）。
