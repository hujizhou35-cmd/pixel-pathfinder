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
	for e in GameState.combat_state.enemies:
		e.acted = true   # 阻止先手怪干扰定向测试

func _run() -> void:
	var modal = main_node.modal_layer

	# ---- 1. 新游戏（带起名与天赋点） ----
	GameState.start_new_game(2, "测试勇者", { "vit": 4, "str": 3, "tough": 2, "agi": 1 })
	await _frames()
	_check(GameState.current_state == GameState.State.MAP, "新游戏进入地图（区域3开局）")
	_check(GameState.region == 2 and GameState.cycle == 0, "全地图开放：区域3 · 1周目")
	_check(GameState.has_save(), "开局即有存档")
	_check(GameState.hero_name == "测试勇者", "角色名已记录")
	var stats0 = GameState.get_player_stats()
	_check(stats0.atk == GameData.PLAYER_BASE["atk"] + 3 + 5, "力量天赋 +3 攻击（初始剑 5 攻）实际 %d" % stats0.atk)
	_check(stats0.def >= 2 + 2, "坚韧天赋 +2 防御 实际 %d" % stats0.def)
	_check(stats0.crit == GameData.PLAYER_BASE["crit"] + 2, "敏捷天赋 +2%% 暴击 实际 %d" % stats0.crit)
	_check(GameState.max_hp >= GameData.PLAYER_BASE["max_hp"] + 4 * 8, "生命天赋 +32 最大生命 实际 %d" % GameState.max_hp)

	# ---- 2. 路线地图：连线 / 相邻移动 / 折返 ----
	var nodes: Array = GameState.current_map.nodes
	var rows: Array = GameState.current_map.rows
	_check(rows.size() == 5, "地图 5 排（底排→首领）")
	var start_adj = GameState.get_adjacent_ids()
	_check(GameState.hero_pos == -1 and start_adj.size() == rows[0].size(), "起点可走向底排全部 %d 个节点" % start_adj.size())
	# 连通性：每个非顶排节点都有向上的边
	var edges_ok = true
	for r in range(rows.size() - 1):
		for n in rows[r]:
			if n.next.is_empty():
				edges_ok = false
	_check(edges_ok, "每个节点都有向上的路线")
	# 上排节点都有来路
	var inbound_ok = true
	for r in range(1, rows.size()):
		for u in rows[r]:
			var found = false
			for n in rows[r - 1]:
				if n.next.has(u.id):
					found = true
			if not found:
				inbound_ok = false
	_check(inbound_ok, "每个上排节点都有来路（不会出现死路）")
	# 旧存档(v4)地图没有连线 → ensure_links 自动补织（修复点完战斗后卡死）
	var legacy_rows = []
	var lid = 0
	for rc in [4, 4, 4, 1]:
		var lrow = []
		for c in range(rc):
			lrow.append({ "id": lid, "row": legacy_rows.size(), "col": c, "type": 0, "next": [], "visited": false, "foes": [] })
			lid += 1
		legacy_rows.append(lrow)
	MapGenerator.ensure_links(legacy_rows)
	var relink_ok = true
	for r in range(legacy_rows.size() - 1):
		for n in legacy_rows[r]:
			if n.next.is_empty():
				relink_ok = false
	_check(relink_ok, "旧存档地图自动补织连线（修复战斗后卡死）")
	# 移动与折返
	var first_id = int(start_adj[0])
	_check(GameState.move_hero(first_id), "小人移动到底排节点")
	_check(GameState.hero_pos == first_id, "小人位置已更新")
	var adj2 = GameState.get_adjacent_ids()
	_check(not GameState.move_hero(9999), "不能跳到不相邻节点")
	if adj2.size() > 0:
		var up_id = int(adj2[0])
		GameState.move_hero(up_id)
		_check(GameState.get_adjacent_ids().has(first_id), "可折返回刚刚的位置")
		GameState.move_hero(first_id)
	_check(GameState.hero_pos == first_id, "折返成功")

	var battle_node = null
	var boss_node = null
	var shop_node = null
	var foes_ok = true
	for n in nodes:
		if n.type in [GameData.NodeType.BATTLE, GameData.NodeType.ELITE, GameData.NodeType.BOSS]:
			if n.foes.is_empty():
				foes_ok = false
			if n.type == GameData.NodeType.BATTLE and battle_node == null:
				battle_node = n
		if n.type == GameData.NodeType.BOSS:
			boss_node = n
		if n.type == GameData.NodeType.SHOP:
			shop_node = n
	_check(foes_ok, "所有战斗节点都预掷了怪物构成")
	_check(boss_node != null and battle_node != null and shop_node != null, "地图包含首领/战斗/商店节点")

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

	# ---- 3. 装备库 175 件 + 新槽位 ----
	_check(ItemCatalog.all_entries().size() == 175, "装备图鉴库共 175 件 (实际 %d)" % ItemCatalog.all_entries().size())
	for slot in ["helmet", "pants", "boots"]:
		var g = EquipmentFactory.generate_item(0, slot)
		_check(g.slot == slot and g.has("element") and g.stats.def + g.stats.hp > 0, "新槽位 %s 装备生成正常" % slot)
	var gen = EquipmentFactory.generate_item(0, "weapon")
	_check(gen.has("element") and gen.has("family") and gen.has("catalog_id"), "生成装备含元素/基底/图鉴信息")
	# 新槽位 +5 独特生效
	var helm = EquipmentFactory.build_from_entry(ItemCatalog.get_entry("earth_战盔"), 2, GameData.Rarity.COMMON)
	helm["affixes"] = []
	helm.level = 5
	var pants5 = EquipmentFactory.build_from_entry(ItemCatalog.get_entry("wood_链甲裤"), 2, GameData.Rarity.COMMON)
	pants5["affixes"] = []
	pants5.level = 5
	var boots5 = EquipmentFactory.build_from_entry(ItemCatalog.get_entry("water_铁头靴"), 2, GameData.Rarity.COMMON)
	boots5["affixes"] = []
	boots5.level = 5
	var eq6 = { "weapon": null, "armor": null, "helmet": helm, "pants": pants5, "boots": boots5, "accessory": null }
	var s6 = EquipmentModifier.calculate_total_stats(eq6)
	_check(s6.shield_start >= 12, "头盔 +5：开战护盾 +12 (实际 %d)" % s6.shield_start)
	_check(s6.regen >= 3, "裤子 +5：每回合恢复 3 (实际 %d)" % s6.regen)
	_check(s6.dodge_chance >= 15, "鞋 +5：闪避 15%% (实际 %d)" % s6.dodge_chance)

	# ---- 4. 元素克制（西式改名后 key 不变） ----
	_check(absf(GameData.element_mult("metal", "wood") - 1.3) < 0.001, "闪电克森林 ×1.3")
	_check(absf(GameData.element_mult("wood", "metal") - 0.8) < 0.001, "森林被闪电克 ×0.8")
	_check(absf(GameData.element_mult("fire", "fire") - 1.0) < 0.001, "同元素 ×1.0")
	_check(GameData.element_name("metal") == "闪电" and GameData.element_name("water") == "寒冰", "元素显示名已西化")

	# ---- 5. 怪物词条与战斗风格 ----
	var tough_foe = { "key": "slime", "elite": false, "boss": false, "affixes": ["tough"], "element": "wood" }
	var plain_foe = { "key": "slime", "elite": false, "boss": false, "affixes": [], "element": "wood" }
	var st_t = CombatManager.enemy_stats_for(tough_foe, 0, 0)
	var st_p = CombatManager.enemy_stats_for(plain_foe, 0, 0)
	_check(st_t.hp == roundi(st_p.hp * 1.5), "魁梧词条：生命 ×1.5 (%d→%d)" % [st_p.hp, st_t.hp])
	var st_c1 = CombatManager.enemy_stats_for(plain_foe, 0, 1)
	_check(st_c1.hp > st_p.hp, "周目缩放：2周目怪物更强 (%d→%d)" % [st_p.hp, st_c1.hp])
	var guard = CombatManager.build_enemy({ "key": "guardian", "elite": false, "boss": false, "affixes": ["shielded"], "element": "metal" }, 0, 0)
	_check(guard.shield > 0, "结界词条：开场自带护盾 (%d)" % guard.shield)
	_check(guard.style == "bash", "守护者为盾击风格")
	var wolf_e = CombatManager.build_enemy({ "key": "wolf", "elite": false, "boss": false, "affixes": [], "element": "wood" }, 0, 0)
	_check(wolf_e.style == "feral", "灰狼为先手风格")

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

	# ---- 8. 套装效果（六槽位计数） ----
	var sw = EquipmentFactory.build_from_entry(ItemCatalog.get_entry("metal_长剑"), 2, GameData.Rarity.COMMON)
	var hm2 = EquipmentFactory.build_from_entry(ItemCatalog.get_entry("water_铁盔"), 2, GameData.Rarity.COMMON)
	sw["prefix"] = "风暴"
	hm2["prefix"] = "风暴"
	sw["affixes"] = []
	hm2["affixes"] = []
	var eq_test = { "weapon": sw, "armor": null, "helmet": hm2, "pants": null, "boots": null, "accessory": null }
	var sets = EquipmentModifier.get_active_sets(eq_test)
	_check(sets.size() == 1 and sets[0].prefix == "风暴" and sets[0].count == 2, "武器+头盔同前缀 2 件激活套装")

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

	# ---- 10. 背包：扩容 32 + 整理排序 ----
	_check(GameData.PLAYER_BASE["bag_capacity"] == 32, "背包容量 32")
	GameState.bag.clear()
	GameState.bag.append(EquipmentFactory.generate_item(0, "accessory", GameData.Rarity.COMMON))
	GameState.bag.append(EquipmentFactory.generate_item(0, "weapon", GameData.Rarity.LEGENDARY))
	GameState.bag.append(EquipmentFactory.generate_item(0, "boots", GameData.Rarity.COMMON))
	GameState.bag.append(EquipmentFactory.generate_item(0, "weapon", GameData.Rarity.COMMON))
	GameState.sort_bag()
	_check(str(GameState.bag[0].slot) == "weapon" and int(GameState.bag[0].rarity) == GameData.Rarity.LEGENDARY, "整理：武器在前且稀有度降序")
	_check(str(GameState.bag[3].slot) == "accessory", "整理：配饰排最后")

	# ---- 11. 弹窗堆栈：奖励之上开背包不丢战利品 ----
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

	# ---- 12. 各弹窗构建无报错 ----
	for t in [["help", {}], ["stats", {}], ["saves", {}], ["region_select", {"in_run": true}],
			["new_run_setup", {"region": 0}], ["perk_choice", {"offers": ["berserker", "giant", "sharpeye"]}],
			["bag", {"filter": "weapon"}], ["bag", {"filter": "clothes"}],
			["codex", {"tab": "equip"}], ["codex", {"tab": "affix"}], ["codex", {"tab": "perk"}],
			["codex", {"tab": "monster"}], ["codex", {"tab": "boss"}], ["codex", {"tab": "event"}],
			["codex", {"tab": "element"}]]:
		SignalBus.show_modal.emit(t[0], t[1])
		await _frames(3)
		_check(modal.is_open(), "弹窗 %s/%s 构建成功" % [t[0], str(t[1].get("tab", t[1].get("filter", "")))])
		modal.close_all()
	await _frames()
	GameState.change_state(GameState.State.MAP)

	# ---- 13. 事件引擎 ----
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

	# ---- 14. 战斗：先后手 + 冷却 + 弓连击 + 元素被动 ----
	GameState.current_node_idx = -1
	GameState.change_state(GameState.State.MAP)
	GameState.enter_node(battle_node)
	await _frames(4)
	_check(GameState.current_state == GameState.State.COMBAT, "通过节点进入战斗")
	_check(GameState.hero_pos == battle_node.id, "进入节点后小人位置同步")
	var enemies = GameState.combat_state.enemies
	_check(enemies.size() == battle_node.foes.size(), "实战怪物数量与预览一致")
	_check(enemies[0].maxhp == prev.hp, "实战 HP 与预览一致 (%d)" % enemies[0].maxhp)
	var cv = main_node.combat_view
	_check(cv._enemy_slots.size() == enemies.size(), "敌人槽位构建")
	_check(cv._hero_atlas.atlas != null, "英雄合成精灵已生成")
	_check(cv._hero_atlas.atlas.get_width() == 40, "英雄精灵为高分辨率 40×52（战士比例）")
	_check(PixelArt.item_icon(GameState.equipment.weapon) != null, "装备像素图标生成")
	_check(PixelArt.item_icon(helm) != null and PixelArt.item_icon(boots5) != null, "新槽位图标生成")

	var cn = main_node.combat_node

	# 元素被动逐一验证（直接调用结算函数 → 被动真实生效）
	var dummy = enemies[0]
	dummy.weaken = 0
	cn._apply_elem_proc("water", dummy, 0, GameState.get_player_stats(), 10)
	_check(int(dummy.weaken) == 2, "「冰缚」生效：敌人减攻 2 回合")
	dummy.burn = 0
	cn._apply_elem_proc("fire", dummy, 0, GameState.get_player_stats(), 10)
	_check(int(dummy.burn) > 0 and int(dummy.burn_dmg) > 0, "「引燃」生效：灼烧已挂上")
	var sh_b = int(GameState.combat_state.shield)
	cn._apply_elem_proc("earth", dummy, 0, GameState.get_player_stats(), 10)
	_check(int(GameState.combat_state.shield) > sh_b, "「岩盾」生效：获得护盾")
	GameState.hp = maxi(1, GameState.hp - 10)
	var hp_b = GameState.hp
	cn._apply_elem_proc("wood", dummy, 0, GameState.get_player_stats(), 20)
	_check(GameState.hp > hp_b, "「回春」生效：恢复生命")

	# 盾击先后手：弓（非剑）→ 后手；剑 → 先手
	var bow_w = EquipmentFactory.build_from_entry(ItemCatalog.get_entry("wood_长弓"), 2, GameData.Rarity.COMMON)
	bow_w["affixes"] = []
	GameState.equipment.weapon = bow_w
	GameState._recalc_stats()
	_force_player_turn()
	GameState.combat_state.skill_cooldown = 0
	cn.player_skill(0)
	_check(bool(GameState.combat_state.get("last_action_slow", false)), "弓盾击为后手动作")
	var sword_w = EquipmentFactory.build_from_entry(ItemCatalog.get_entry("metal_长剑"), 2, GameData.Rarity.COMMON)
	sword_w["affixes"] = []
	GameState.equipment.weapon = sword_w
	GameState._recalc_stats()
	_force_player_turn()
	GameState.combat_state.skill_cooldown = 0
	cn.player_skill(0)
	_check(not bool(GameState.combat_state.get("last_action_slow", true)), "剑盾击为先手动作（剑专属）")

	# 弓连击：暴击后连击数增加
	GameState.equipment.weapon = bow_w
	GameState._recalc_stats()
	_force_player_turn()
	GameState.combat_state.bow_combo = 0
	for e in GameState.combat_state.enemies:
		e.hp = maxi(e.hp, 99999)
		e.maxhp = maxi(e.maxhp, 99999)
		e.affixes = []   # 去掉虚体等词条，避免闪避干扰暴击计数
	# 直接模拟：本次行动暴击 2 次
	GameState.combat_state.crits_this_action = 0
	var crit_stats = GameState.get_player_stats()
	crit_stats.crit = 100   # 必定暴击
	cn._do_hit(0, 1.0, crit_stats, "bow")
	cn._do_hit(0, 1.0, crit_stats, "bow")
	_check(int(GameState.combat_state.crits_this_action) == 2, "暴击计数正确 (%d)" % int(GameState.combat_state.crits_this_action))

	# 防御冷却
	_force_player_turn()
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

	# ---- 15. 商店 9 件 + 可重复进入 ----
	GameState.open_shop()
	await _frames(3)
	_check(GameState.shop_stock.size() == 9, "商店 9 件商品 (实际 %d)" % GameState.shop_stock.size())
	var has_new_slot = false
	for it in GameState.shop_stock:
		if str(it.slot) in ["helmet", "pants", "boots"]:
			has_new_slot = true
	_check(has_new_slot, "商店包含头盔/裤子/鞋商品")
	modal.close_all()
	GameState.change_state(GameState.State.MAP)
	shop_node.visited = true
	_check(GameState.can_enter_node(shop_node), "已访问的商店可重复进入")
	if battle_node:
		_check(not GameState.can_enter_node(battle_node), "已结束的战斗不可再进入")

	# ---- 16. 存档/读档（含天赋/名字/perks/小人位置） ----
	GameState.essences.append({ "affix": "crit", "from": "测试" })
	GameState.perks.append("giant")
	GameState.change_state(GameState.State.MAP)
	GameState.save_game()
	var gold_before = GameState.gold
	var ok = GameState.load_game()
	await _frames(2)
	_check(ok and GameState.gold == gold_before, "读档恢复金币")
	_check(GameState.essences.size() == 1 and GameState.essences[0].affix == "crit", "读档恢复词条精华")
	_check(GameState.hero_name == "测试勇者", "读档恢复角色名")
	_check(int(GameState.talents["vit"]) == 4 and int(GameState.talents["str"]) == 3, "读档恢复天赋点")
	_check(GameState.perks.has("giant"), "读档恢复天赋词条")
	_check(GameState.hero_pos == battle_node.id, "读档恢复小人位置")
	_check(GameState.equipment.weapon.has("element"), "读档后装备元素保留")
	var foes_after_load = true
	for n in GameState.current_map.nodes:
		if n.type in [GameData.NodeType.BATTLE, GameData.NodeType.ELITE, GameData.NodeType.BOSS] and n.foes.is_empty():
			foes_after_load = false
	_check(foes_after_load, "读档后战斗节点怪物构成保留")

	# 天赋词条数值生效
	var hp_no_perk = GameState.max_hp
	GameState.perks.clear()
	GameState._recalc_stats()
	var hp_without = GameState.max_hp
	GameState.perks.append("giant")
	GameState._recalc_stats()
	_check(GameState.max_hp > hp_without and GameState.max_hp == hp_no_perk, "「巨人血脉」天赋词条 +15%% 生命真实生效 (%d→%d)" % [hp_without, GameState.max_hp])

	# ---- 16b. 天赋词条节奏：仅区域 2/5 里程碑后可选；上限 5 可替换 ----
	GameState.region = 0
	GameState.change_state(GameState.State.REWARD)
	GameState.region_clear()
	await _frames(3)
	_check(modal._current_type == "region_clear", "区域 1 通关不弹天赋（非里程碑）")
	modal.close_all()
	GameState.perks = ["giant", "ironwall", "sharpeye", "brutal", "windrunner"]
	GameState.choose_perk("berserker")
	await _frames(3)
	_check(modal._current_type == "perk_replace", "词条满 5 条选新词条 → 弹出替换选择")
	modal.close_all()
	GameState.replace_perk("giant", "berserker")
	await _frames(2)
	_check(GameState.perks.has("berserker") and not GameState.perks.has("giant") and GameState.perks.size() == 5, "替换成功且上限保持 5 条")
	modal.close_all()
	GameState.perks = ["berserker"]   # 留出空位，供下一节追加

	# ---- 17. 无限周目：通关第 5 区（里程碑）→ 天赋三选一 → 强化周目 ----
	GameState.region = 4
	GameState.change_state(GameState.State.REWARD)
	GameState.region_clear()
	await _frames(4)
	_check(modal._current_type == "perk_choice", "区域 5（里程碑）通关后弹出天赋三选一")
	var offers: Array = modal._current_data.get("offers", [])
	_check(offers.size() == 3, "天赋词条三选一 (实际 %d)" % offers.size())
	var pick = str(offers[0])
	modal.close_all()
	GameState.choose_perk(pick)
	await _frames(4)
	_check(GameState.perks.has(pick), "已选天赋词条入库")
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
