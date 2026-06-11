extends Node

# ============================================================
# 冒烟测试（headless）：驱动真实游戏流程验证核心逻辑
# 运行: godot --headless --path . res://test/smoke_test.tscn
# ============================================================

var fails: Array = []
var main_node: Control

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails.append(msg)
		print("[FAIL] ", msg)
	else:
		print("[ ok ] ", msg)

func _ready() -> void:
	_backup_saves()
	await get_tree().process_frame
	main_node = load("res://scenes/main.tscn").instantiate()
	add_child(main_node)
	await get_tree().process_frame
	await _run()

## 测试前备份真实存档，结束后恢复，避免污染玩家进度
func _backup_saves() -> void:
	for i in range(GameState.SLOT_COUNT):
		var p = "user://save_slot_%d.json" % i
		var b = p + ".bak"
		if FileAccess.file_exists(b):
			continue
		if FileAccess.file_exists(p):
			DirAccess.copy_absolute(p, b)
		else:
			var f = FileAccess.open(b, FileAccess.WRITE)
			if f:
				f.store_string("EMPTY")
				f.close()

func _restore_saves() -> void:
	for i in range(GameState.SLOT_COUNT):
		var p = "user://save_slot_%d.json" % i
		var b = p + ".bak"
		if not FileAccess.file_exists(b):
			continue
		var f = FileAccess.open(b, FileAccess.READ)
		var txt = f.get_as_text()
		f.close()
		if txt == "EMPTY":
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(p)
		else:
			DirAccess.copy_absolute(b, p)
		DirAccess.remove_absolute(b)

func _frames(n: int = 2) -> void:
	for i in range(n):
		await get_tree().process_frame

## 强行回到玩家回合（用于连续测试多个玩家动作）
func _force_player_turn() -> void:
	var cn = main_node.combat_node
	cn.busy = false
	cn.phase = 0
	GameState.combat_state.player_turn = true

func _run() -> void:
	var modal = main_node.modal_layer

	# ---- 1. 新游戏（任意区域开局）----
	GameState.start_new_game(2)
	await _frames()
	_check(GameState.current_state == GameState.State.MAP, "新游戏进入地图（区域3开局）")
	_check(GameState.region == 2 and GameState.cycle == 0, "全地图开放：区域3 · 1周目")
	_check(GameState.has_save(), "开局即有存档")

	# ---- 2. 自由选关地图 + 怪物构成预掷 ----
	var nodes: Array = GameState.current_map.nodes
	var reachable = GameState.get_reachable_nodes()
	_check(reachable.size() == nodes.size(), "自由选关：全部 %d 个节点开局可达" % nodes.size())
	var battle_node = null
	var boss_node = null
	var foes_ok = true
	for n in nodes:
		if n.type in [GameData.NodeType.BATTLE, GameData.NodeType.ELITE, GameData.NodeType.BOSS]:
			if n.foes.is_empty():
				foes_ok = false
			if n.type == GameData.NodeType.BATTLE and battle_node == null:
				battle_node = n
		if n.type == GameData.NodeType.BOSS:
			boss_node = n
	_check(foes_ok, "所有战斗节点都预掷了怪物构成")
	_check(boss_node != null and battle_node != null, "地图包含首领与战斗节点")

	# 预览数值 = 实战数值
	var foe0 = battle_node.foes[0]
	var prev = CombatManager.enemy_stats_for(foe0, GameState.region, GameState.cycle)
	var built = CombatManager.build_enemy(foe0, GameState.region, GameState.cycle)
	_check(prev.hp == built.maxhp and prev.atk == built.atk, "预览数值与实战一致 (HP %d / ATK %d)" % [prev.hp, prev.atk])

	# 关卡预览弹窗
	SignalBus.show_modal.emit("node_preview", { "node": battle_node })
	await _frames(3)
	_check(modal._current_type == "node_preview", "关卡预览弹窗构建成功")
	modal.close_all()
	await _frames()

	# ---- 3. 装备库 100 件 + 元素/品级 ----
	_check(ItemCatalog.all_entries().size() == 100, "装备图鉴库共 100 件 (实际 %d)" % ItemCatalog.all_entries().size())
	var gen = EquipmentFactory.generate_item(0, "weapon")
	_check(gen.has("element") and gen.has("family") and gen.has("catalog_id"), "生成装备含元素/基底/图鉴信息")
	var low_grade_ok = true
	for i in range(8):
		var g = EquipmentFactory.generate_item(0, "weapon")
		if int(g.grade) > 1:
			low_grade_ok = false
	_check(low_grade_ok, "区域 1 只出品级Ⅰ基底")
	GameState.cycle = 1
	var hi = EquipmentFactory.generate_item(4, "weapon")
	GameState.cycle = 0
	_check(int(hi.grade) >= 1, "周目提升装备有效区域（品级 %d）" % int(hi.grade))

	# ---- 4. 五行克制 ----
	_check(absf(GameData.element_mult("metal", "wood") - 1.3) < 0.001, "金克木 ×1.3")
	_check(absf(GameData.element_mult("wood", "metal") - 0.8) < 0.001, "木被金克 ×0.8")
	_check(absf(GameData.element_mult("fire", "fire") - 1.0) < 0.001, "同元素 ×1.0")

	# ---- 5. 怪物词条 ----
	var tough_foe = { "key": "slime", "elite": false, "boss": false, "affixes": ["tough"], "element": "wood" }
	var plain_foe = { "key": "slime", "elite": false, "boss": false, "affixes": [], "element": "wood" }
	var st_t = CombatManager.enemy_stats_for(tough_foe, 0, 0)
	var st_p = CombatManager.enemy_stats_for(plain_foe, 0, 0)
	_check(st_t.hp == roundi(st_p.hp * 1.5), "魁梧词条：生命 ×1.5 (%d→%d)" % [st_p.hp, st_t.hp])
	var st_c1 = CombatManager.enemy_stats_for(plain_foe, 0, 1)
	_check(st_c1.hp > st_p.hp, "周目缩放：2周目怪物更强 (%d→%d)" % [st_p.hp, st_c1.hp])
	var guard = CombatManager.build_enemy({ "key": "guardian", "elite": false, "boss": false, "affixes": ["shielded"], "element": "metal" }, 0, 0)
	_check(guard.shield > 0, "结界词条：开场自带护盾 (%d)" % guard.shield)

	# ---- 6. 强化投入与出售返还 ----
	GameState.gold = 10000
	var w = GameState.equipment.weapon
	var base_sell = EquipmentModifier.get_sell_value(w)
	var c1 = EquipmentModifier.get_upgrade_cost(w, GameState.region)
	GameState.upgrade_equipped("weapon")
	_check(w.level == 1, "武器强化 +1")
	_check(int(w.invested) == c1, "强化投入被记录 (%d)" % c1)
	var new_sell = EquipmentModifier.get_sell_value(w)
	_check(new_sell == base_sell + 12 + roundi(c1 * 0.5), "出售价含 50%% 强化返还 (%d→%d)" % [base_sell, new_sell])

	# ---- 7. 稀有度分层 + 解说 ----
	var leg = EquipmentFactory.generate_item(0, "weapon", GameData.Rarity.LEGENDARY)
	var com = EquipmentFactory.generate_item(0, "weapon", GameData.Rarity.COMMON)
	_check(leg.affixes.size() == 3, "传说装备 3 词条 (实际 %d)" % leg.affixes.size())
	_check(leg.lore.size() >= 4, "传说装备解说 ≥4 条 (实际 %d)" % leg.lore.size())
	_check(com.lore.size() >= 1, "普通装备解说 ≥1 条")
	var tiers_ok = true
	for r in range(GameData.Rarity.LEGENDARY):
		var lo_next = GameData.RARITY_DATA[r + 1].mult * 0.95
		var hi_cur = GameData.RARITY_DATA[r].mult * 1.05
		if lo_next <= hi_cur:
			tiers_ok = false
	_check(tiers_ok, "稀有度属性区间严格递增不重叠")

	# ---- 8. 套装效果 ----
	var sw = EquipmentFactory.build_from_entry(ItemCatalog.get_entry("metal_长剑"), 2, GameData.Rarity.COMMON)
	var ar = EquipmentFactory.build_from_entry(ItemCatalog.get_entry("water_锁子甲"), 2, GameData.Rarity.COMMON)
	sw["prefix"] = "风暴"
	ar["prefix"] = "风暴"
	sw["affixes"] = []
	ar["affixes"] = []
	var eq_test = { "weapon": sw, "armor": ar, "accessory": null }
	var sets = EquipmentModifier.get_active_sets(eq_test)
	_check(sets.size() == 1 and sets[0].prefix == "风暴" and sets[0].count == 2, "同前缀 2 件激活套装")
	var s_total = EquipmentModifier.calculate_total_stats(eq_test)
	_check(s_total.extra_hit >= 15, "风暴 2 件套：连击 +15%% (实际 %d)" % s_total.extra_hit)

	# ---- 9. 熔炼与锻打 ----
	var epic = EquipmentFactory.generate_item(0, "weapon", GameData.Rarity.EPIC)
	GameState.bag.clear()
	GameState.bag.append(epic)
	GameState.essences.clear()
	var target_affix = epic.affixes[0]
	var ok_smelt = GameState.smelt_bag_item(0, target_affix)
	_check(ok_smelt and GameState.essences.size() == 1 and GameState.bag.is_empty(), "熔炼史诗装备 → 词条精华")
	var wpn = GameState.equipment.weapon
	wpn["affixes"] = []
	var gold_b = GameState.gold
	var ok_forge = GameState.forge_essence(0, { "kind": "equip", "slot": "weapon" })
	_check(ok_forge and wpn.affixes.has(target_affix), "锻打：精华附着到武器")
	_check(GameState.gold == gold_b - GameState.get_forge_cost(), "锻打消耗金币")
	_check(GameState.essences.is_empty(), "精华已消耗")

	# ---- 10. 弹窗堆栈：奖励之上开背包不丢战利品 ----
	GameState.pending_drop = leg
	SignalBus.show_modal.emit("reward", { "gold": 10, "drop": leg })
	await _frames(3)
	_check(modal._current_type == "reward", "奖励弹窗已打开")
	SignalBus.show_modal.emit("bag", {})
	await _frames(3)
	_check(modal._current_type == "bag", "背包叠加打开")
	modal.try_escape()
	await _frames(3)
	_check(modal._current_type == "reward", "关闭背包后恢复奖励弹窗")
	_check(GameState.pending_drop == leg, "战利品未丢失")
	GameState.handle_drop("sell")
	modal.close_all()
	await _frames(3)
	_check(GameState.pending_drop == null, "战利品出售完成")
	_check(GameState.current_state == GameState.State.MAP, "回到地图")

	# ---- 11. 各弹窗构建无报错 ----
	for t in [["help", {}], ["stats", {}], ["saves", {}], ["region_select", {"in_run": true}],
			["codex", {"tab": "equip"}], ["codex", {"tab": "affix"}], ["codex", {"tab": "monster"}],
			["codex", {"tab": "boss"}], ["codex", {"tab": "event"}], ["codex", {"tab": "element"}]]:
		SignalBus.show_modal.emit(t[0], t[1])
		await _frames(3)
		_check(modal.is_open(), "弹窗 %s/%s 构建成功" % [t[0], str(t[1].get("tab", ""))])
		modal.close_all()
	await _frames()

	# ---- 12. 事件引擎 ----
	var hp_before_max = GameState.max_hp
	GameState.handle_event_choice("monument", 0)
	await _frames()
	_check(GameState.max_hp == hp_before_max + 6, "石碑事件：最大生命 +6")
	var seen = {}
	for i in range(12):
		GameState.open_event()
		await _frames(2)
		seen[modal._current_data.get("key", "?")] = true
		modal.close_all()
		GameState.change_state(GameState.State.MAP)
	_check(seen.size() >= 8, "事件随机且不重复（12 次抽到 %d 种）" % seen.size())

	# ---- 13. 战斗：预掷构成 + 冷却体系 + 状态 ----
	GameState.current_node_idx = -1
	GameState.change_state(GameState.State.MAP)
	GameState.enter_node(battle_node)
	await _frames(4)
	_check(GameState.current_state == GameState.State.COMBAT, "通过节点进入战斗")
	var enemies = GameState.combat_state.enemies
	_check(enemies.size() == battle_node.foes.size(), "实战怪物数量与预览一致")
	_check(enemies[0].maxhp == prev.hp, "实战 HP 与预览一致 (%d)" % enemies[0].maxhp)
	var cv = main_node.combat_view
	_check(cv._enemy_slots.size() == enemies.size(), "敌人槽位构建")
	var e0 = enemies[0]
	_check(cv._enemy_slots[0].hp_lbl.text == "%d / %d" % [e0.hp, e0.maxhp], "敌人血量精确数值显示")
	_check(cv._hero_atlas.atlas != null, "英雄合成精灵已生成")
	_check(PixelArt.item_icon(GameState.equipment.weapon) != null, "装备像素图标生成")

	# 防御冷却
	main_node.combat_node.player_defend()
	_check(GameState.combat_state.cooldowns.defend == GameData.COMBAT["defend_cooldown"] + 1, "防御进入冷却")
	# 药水冷却
	_force_player_turn()
	GameState.hp = maxi(1, GameState.hp - 20)
	GameState.potions = 2
	main_node.combat_node.player_potion()
	_check(GameState.combat_state.cooldowns.potion >= 2, "药水进入冷却")
	# 斧攻击冷却
	var axe = EquipmentFactory.build_from_entry(ItemCatalog.get_entry("fire_战斧"), 2, GameData.Rarity.COMMON)
	GameState.equipment.weapon = axe
	GameState._recalc_stats()
	_force_player_turn()
	main_node.combat_node.player_attack(0)
	_check(GameState.combat_state.cooldowns.attack == GameData.COMBAT["axe_cooldown"] + 1, "斧攻击后进入冷却")
	await get_tree().create_timer(2.0).timeout

	# 秒杀全部敌人 → 胜利奖励
	for e in GameState.combat_state.enemies:
		e.hp = 0
	main_node.combat_node._kill_check()
	main_node.combat_node._check_combat_end()
	await _frames(4)
	_check(GameState.current_state == GameState.State.REWARD, "战斗胜利进入奖励")
	if GameState.pending_drop:
		GameState.handle_drop("sell")
	else:
		GameState.close_reward()
	modal.close_all()
	await _frames(3)

	# ---- 14. 商店 5 件 ----
	GameState.open_shop()
	await _frames(3)
	_check(GameState.shop_stock.size() == 5, "商店 5 件商品 (实际 %d)" % GameState.shop_stock.size())
	modal.close_all()
	GameState.change_state(GameState.State.MAP)

	# ---- 15. 精英/首领必掉验证 ----
	var elite_drops = 0
	var boss_drops = 0
	for i in range(10):
		var r1 = LootSystem.calculate_combat_rewards([{ "gold_reward": 10 }], false, true)
		if r1.drop != null and r1.drop.rarity >= GameData.Rarity.RARE:
			elite_drops += 1
		var r2 = LootSystem.calculate_combat_rewards([{ "gold_reward": 10 }], true, false)
		if r2.drop != null and r2.drop.rarity >= GameData.Rarity.EPIC:
			boss_drops += 1
	_check(elite_drops == 10, "精英 100%% 掉落稀有+ (%d/10)" % elite_drops)
	_check(boss_drops == 10, "首领 100%% 掉落史诗+ (%d/10)" % boss_drops)

	# ---- 16. 存档/读档（含周目/精华/怪物构成）----
	GameState.essences.append({ "affix": "crit", "from": "测试" })
	GameState.change_state(GameState.State.MAP)
	GameState.save_game()
	var gold_before = GameState.gold
	var ok = GameState.load_game()
	await _frames(2)
	_check(ok and GameState.gold == gold_before, "读档恢复金币")
	_check(GameState.essences.size() == 1 and GameState.essences[0].affix == "crit", "读档恢复词条精华")
	_check(GameState.equipment.weapon.has("element"), "读档后装备元素保留")
	var foes_after_load = true
	for n in GameState.current_map.nodes:
		if n.type in [GameData.NodeType.BATTLE, GameData.NodeType.ELITE, GameData.NodeType.BOSS] and n.foes.is_empty():
			foes_after_load = false
	_check(foes_after_load, "读档后战斗节点怪物构成保留")

	# ---- 17. 无限周目：通关第 5 区 → 强化周目 ----
	GameState.region = 4
	GameState.change_state(GameState.State.REWARD)
	GameState.region_clear()
	await _frames(4)
	_check(GameState.cycle == 1, "通关后进入强化 1 周目")
	_check(GameState.region == 0, "新周目从区域 1 开始")
	_check(GameState.has_save(), "通关后存档保留（无限循环）")
	_check(modal._current_type == "victory", "通关弹窗显示")
	modal.close_all()
	await _frames(2)
	var cyc_enemy = CombatManager.enemy_stats_for(plain_foe, 0, GameState.cycle)
	_check(cyc_enemy.hp > st_p.hp, "新周目怪物已强化")

	# 读档保留周目
	GameState.save_game()
	GameState.load_game()
	await _frames(2)
	_check(GameState.cycle == 1, "读档恢复周目")

	# ---- 18. 区域切换 ----
	GameState.change_state(GameState.State.MAP)
	GameState.switch_region(3)
	await _frames(2)
	_check(GameState.region == 3 and GameState.cycle == 1, "切区保持周目")

	# ---- 结果 ----
	_restore_saves()
	print("")
	if fails.is_empty():
		print("SMOKE OK - 全部检查通过")
	else:
		print("SMOKE FAILED - %d 项失败:" % fails.size())
		for f in fails:
			print("  - ", f)
	get_tree().quit(0 if fails.is_empty() else 1)
