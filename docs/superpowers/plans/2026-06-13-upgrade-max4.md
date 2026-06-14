# upgrade max4 (v7.0) Implementation Plan

> **For agentic workers:** Execute task-by-task. Steps use checkbox (`- [ ]`) syntax.
> **Project note:** Not a git repo → no commit steps. Verification = `--import` then headless smoke test (`test/smoke_test.tscn`) + screenshot self-check (`test/shot_test.tscn`). Run headless via `cmd /c "... > out.txt 2>&1"` then Read out.txt.

**Goal:** Implement `upgrade max4.md` 三阶段：周目 Boss+终局 CG、背包重做+精铸增量+熔炼自选、怪物护盾上限；并同步帮助/图鉴/说明文案。最终导出 windows exe。

**Architecture:** 在现有全程序化 Godot 架构上扩展：GameData(数据/CG/文案)、GameState(流程/精铸/熔炼/存档)、CombatManager+CombatState(周目 boss 战斗/护盾上限)、PixelArt(4 新 boss 精灵)、Sfx(CG 配乐)、ModalLayer(背包重做/熔炼弹窗/帮助/图鉴)、cg_layer(配乐 mood)。

**Tech Stack:** Godot 4.6 GDScript，程序化像素美术与音频。

---

## 阶段一 — 周目 Boss 与 CG

### Task 1: CG 资源与文案
**Files:** Modify `scripts/game_data.gd`; 拷贝图片到 `assets/cg/19.png..28.png`
- [ ] 拷贝 `../final CG/0.png..9.png` → `assets/cg/19.png..28.png`
- [ ] 改写 `CG_DATA[13]` text（新结尾，删欢迎段）
- [ ] 新增 `CG_DATA[19..28]`（title+text 取自 `final CG/CG字幕.md`）
- [ ] 让 Godot 导入图片：跑 `--import`，确认无报错

### Task 2: 周目 Boss 数据
**Files:** Modify `scripts/game_data.gd`
- [ ] 新增 `const CYCLE_BOSSES = [orochi,kitsune,colossus,voidbeast]`，每条 `{key,name,sprite,palette,traits,hp_mult,atk_mult,def_mult,encounter_cg,defeat_cg}`（cg: 20/21,22/23,24/25,26/27）
- [ ] 新增 `static func pick_cycle_boss(cleared_cycle:int)->Dictionary`（0-3 顺序，≥4 随机）

### Task 3: 周目 Boss 战斗构造
**Files:** Modify `scripts/combat/combat_manager.gd`
- [ ] 新增 `static func setup_cycle_boss(cycle:int, bdef:Dictionary)->Dictionary`：以末区 region、cycle 走 `enemy_stats_for`(boss=true) 取基底，再乘 `bdef.hp_mult/atk_mult/def_mult`；enemy dict 带 `cycle_boss=true, cycle_sprite=bdef.key, name=bdef.name, palette=bdef.palette, traits=bdef.traits`；初始护盾 0；scale 放大。

### Task 4: 周目 Boss 精灵
**Files:** Modify `scripts/fx/pixel_art.gd`
- [ ] 新增 `static func cycle_boss_texture(key, palette)->ImageTexture`（缓存，2 帧，`_apply_outline`）
- [ ] 新增 `_draw_orochi/_draw_kitsune/_draw_colossus/_draw_voidbeast`（独特剪影，画布约 48×52）+ `_cycle_canvas(key)`
- [ ] `combat_view._make_enemy_slot`：`e.get("cycle_boss")` → `PixelArt.cycle_boss_texture(e.cycle_sprite, e.palette)`

### Task 5: 流程接线（GameState）
**Files:** Modify `scripts/game_state.gd`
- [ ] 加运行态 `_in_cycle_boss=false`, `_cycle_boss_def=null`
- [ ] `_on_cg_finished`：tag `region_clear` 且 region==末区 → `_start_cycle_boss_intro()`（选 boss，播 `[19,encounter_cg]` tag `cycle_encounter`）
- [ ] tag `cycle_encounter` 完 → 启动 `CombatManager.setup_cycle_boss`，进入战斗状态，置 `_in_cycle_boss=true`
- [ ] 战斗胜利处理（找到 combat_ended/胜利结算入口）：若 `_in_cycle_boss` → 播 `[defeat_cg,28]` tag `cycle_victory`，**不**直接 `_region_clear_continue`
- [ ] tag `cycle_victory` 完 → `_in_cycle_boss=false` → `_region_clear_continue()`
- [ ] `player_defeated`：若 `_in_cycle_boss` → 清标志（cycle 未+1，回末区重打）
- [ ] `region_clear()`：末区不再直接走 `_region_clear_after_cg`，改由上面 CG 链驱动

### Task 6: CG 配乐 mood（1.3）
**Files:** Modify `scripts/sfx.gd`, `scripts/ui/cg_layer.gd`
- [ ] `sfx.gd`：新增 `_cg_music_tense`/`_cg_music_triumph`（更响 ~-6dB），`_make_cg_music_tense()`/`_make_cg_music_triumph()`
- [ ] `start_cg_music(mood:String="narrative")` 按 mood 选流；`stop_cg_music` 停全部
- [ ] `cg_layer.play`：tag `cycle_encounter`→tense，`cycle_victory`→triumph，否则 narrative

### 阶段一验证
- [ ] `--import` → 冒烟测试加断言：`pick_cycle_boss(0..4)`、`setup_cycle_boss` 产出 hp>区域boss、护盾遵守上限
- [ ] 截图自检：cycle_boss 精灵渲染（临时进战斗截图）

---

## 阶段二 — 背包重做与经济

### Task 7: 精铸增量（2.2）
**Files:** Modify `scripts/game_state.gd`
- [ ] `refine_item`：`var nt = min(best_eff, int(it.tier_eff)+1)`；扣 5 精粹；`it.stats=baseline_stats(it,nt); it.tier_eff=nt; it.value=baseline_value(it,nt)`；toast 显示新区域
- [ ] 冒烟测试断言：连续两次 refine → tier_eff +2

### Task 8: 熔炼自选（2.3）
**Files:** Modify `scripts/game_state.gd`, `scripts/ui/modal_layer.gd`
- [ ] `smelt_bag_item(index:int, affix_key:String)`：校验 affix 属于该装备，提取指定词条
- [ ] `_build_smelt`：每条词条一个按钮，点击 → `smelt_bag_item(idx, key)`（沿用 purge 模式）
- [ ] 冒烟测试断言：`smelt_bag_item(i,"focus")` 萃取出 focus

### Task 9: 背包重做（2.1）
**Files:** Modify `scripts/ui/modal_layer.gd`（`_build_bag`，必要时 `show()` 面板尺寸）
- [ ] bag 弹窗面板加宽加高
- [ ] 上半 HBox：左 hero 立绘+名称+等阶+属性概览+「属性详情」按钮；右 6 装备槽图标盒（点击→equip_detail）
- [ ] 下半物品栏：头部(容量/分类页签/整理) + 每行 3 件网格；格子折叠态=图标+名称(稀有度色)，点击展开 → 词条+按钮(装备/强化/分解/熔炼/精铸/出售)
- [ ] 保留词条精华区
- [ ] 截图自检：背包新布局美观、不溢出

---

## 阶段三 — 护盾上限

### Task 10: 怪物护盾上限
**Files:** Modify `scripts/combat/combat_state.gd`, `scripts/combat/combat_manager.gd`
- [ ] `combat_state` 新增 `func _cap_enemy_shield(e)`，在每处 `e.shield = ...` / `enemy_shield_changed` 前调用封顶 `min(shield, max(1, floori(maxhp*0.6)))`
- [ ] `combat_manager` 初始 `shielded` 护盾同样封顶
- [ ] 冒烟测试断言：高 cycle 下 shielded 怪 shield < maxhp*0.6

---

## 文档同步（贯穿，最后统一核对）

### Task 11: 帮助/图鉴/说明文案同步
**Files:** Modify `scripts/ui/modal_layer.gd`
- [ ] `_build_help`：精铸=每5精粹+1区域；熔炼=自选词条萃取；新增周目 Boss 提示
- [ ] `_codex_mechanics`：护盾段加"怪物护盾≤生命60%"；精铸/熔炼描述更新；周目 Boss 简介
- [ ] 精铸按钮/ tooltip、熔炼弹窗正文、装备说明（参考图所述）全部改为增量/自选口径
- [ ] grep 全工程残留旧口径（"提升到...最高区域基准"/"随机萃取"）确认无遗漏

---

## 收尾

### Task 12: 全量验证与导出
- [ ] `godot --headless --path . --import`
- [ ] 冒烟测试全绿（重定向到文件读）
- [ ] 截图自检：背包/周目Boss/CG/战斗
- [ ] `godot --headless --path . --export-release "Windows Desktop" ./build/PixelPathfinder.exe`
- [ ] 确认 exe 生成，交付路径
- [ ] 更新记忆 `pixel-pathfinder-project.md`（v7.0 改动）
