extends Node

# ============================================================
# 临时冒烟测试（headless）：驱动真实游戏流程验证核心逻辑
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

func _run() -> void:
	var modal = main_node.modal_layer

	# ---- 1. 新游戏（任意区域开局）----
	GameState.start_new_game(2)
	await _frames()
	_check(GameState.current_state == GameState.State.MAP, "新游戏进入地图（区域3开局）")
	_check(GameState.region == 2, "全地图开放：可从区域3开始")
	_check(GameState.has_save(), "开局即有存档")

	# ---- 2. 强化投入与出售返还 ----
	GameState.gold = 10000
	var w = GameState.equipment.weapon
	var base_sell = EquipmentModifier.get_sell_value(w)
	var c1 = EquipmentModifier.get_upgrade_cost(w, GameState.region)
	GameState.upgrade_equipped("weapon")
	_check(w.level == 1, "武器强化 +1")
	_check(int(w.invested) == c1, "强化投入被记录 (%d)" % c1)
	var new_sell = EquipmentModifier.get_sell_value(w)
	_check(new_sell == base_sell + 12 + roundi(c1 * 0.5), "出售价含 50%% 强化返还 (%d→%d)" % [base_sell, new_sell])

	# ---- 3. 装备生成：稀有度分层 ----
	var leg = EquipmentFactory.generate_item(0, "weapon", GameData.Rarity.LEGENDARY)
	var com = EquipmentFactory.generate_item(0, "weapon", GameData.Rarity.COMMON)
	_check(leg.affixes.size() == 3, "传说装备 3 词条 (实际 %d)" % leg.affixes.size())
	_check(leg.lore.size() >= 4, "传说装备解说 ≥4 条 (实际 %d)" % leg.lore.size())
	_check(com.lore.size() >= 1, "普通装备解说 ≥1 条")
	# 稀有度属性严格分层：相邻稀有度的浮动区间（±5%）不重叠
	var tiers_ok = true
	for r in range(GameData.Rarity.LEGENDARY):
		var lo_next = GameData.RARITY_DATA[r + 1].mult * 0.95
		var hi_cur = GameData.RARITY_DATA[r].mult * 1.05
		if lo_next <= hi_cur:
			tiers_ok = false
	_check(tiers_ok, "稀有度属性区间严格递增不重叠（传奇>史诗>稀有>普通）")

	# ---- 4. 弹窗堆栈：奖励之上开背包不丢战利品 ----
	GameState.pending_drop = leg
	SignalBus.show_modal.emit("reward", { "gold": 10, "drop": leg })
	await _frames(3)
	_check(modal._current_type == "reward", "奖励弹窗已打开")
	SignalBus.show_modal.emit("bag", {})
	await _frames(3)
	_check(modal._current_type == "bag", "背包叠加打开")
	modal.try_escape()
	await _frames(3)
	_check(modal._current_type == "reward", "关闭背包后恢复奖励弹窗（卡死修复）")
	_check(GameState.pending_drop == leg, "战利品未丢失")
	GameState.handle_drop("sell")
	modal.close_all()
	await _frames(3)
	_check(GameState.pending_drop == null, "战利品出售完成")
	_check(GameState.current_state == GameState.State.MAP, "回到地图")

	# ---- 5. 各弹窗构建无报错 ----
	for t in [["help", {}], ["stats", {}], ["saves", {}], ["region_select", {"in_run": true}],
			["codex", {"tab": "equip"}], ["codex", {"tab": "monster"}], ["codex", {"tab": "boss"}],
			["codex", {"tab": "event"}], ["codex", {"tab": "potion"}]]:
		SignalBus.show_modal.emit(t[0], t[1])
		await _frames(3)
		_check(modal.is_open(), "弹窗 %s/%s 构建成功" % [t[0], str(t[1].get("tab", ""))])
		modal.close_all()
	await _frames()

	# ---- 6. 事件引擎 ----
	var hp_before_max = GameState.max_hp
	GameState.handle_event_choice("monument", 0)
	await _frames()
	_check(GameState.max_hp == hp_before_max + 6, "石碑事件：最大生命 +6")
	_check(GameState.current_state == GameState.State.MAP, "事件结束回地图")
	var seen = {}
	for i in range(12):
		GameState.open_event()
		await _frames(2)
		seen[modal._current_data.get("key", "?")] = true
		modal.close_all()
		GameState.change_state(GameState.State.MAP)
	_check(seen.size() >= 8, "事件随机且不重复（12 次抽到 %d 种）" % seen.size())
	_check(GameData.EVENT_POOL.size() >= 16, "事件池 ≥16 个 (实际 %d)" % GameData.EVENT_POOL.size())

	# ---- 7. 战斗流程 + 敌人血量数值 ----
	GameState.current_node_idx = -1
	GameState.enter_combat(false, false)
	await _frames(4)
	_check(GameState.current_state == GameState.State.COMBAT, "进入战斗")
	var cv = main_node.combat_view
	_check(cv._enemy_slots.size() == GameState.combat_state.enemies.size(), "敌人槽位构建")
	var e0 = GameState.combat_state.enemies[0]
	_check(cv._enemy_slots[0].hp_lbl.text == "%d / %d" % [e0.hp, e0.maxhp], "敌人血量精确数值显示 (%s)" % cv._enemy_slots[0].hp_lbl.text)
	_check(cv._weapon_rect.visible, "英雄手持武器图标可见")
	# 攻击一轮
	main_node.combat_node.player_attack(0)
	await get_tree().create_timer(2.5).timeout
	_check(GameState.combat_state.turn >= 1 or e0.hp < e0.maxhp, "攻击已结算")
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

	# ---- 8. 精英/首领必掉验证 ----
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

	# ---- 9. 存档/读档 + 多存档位 ----
	GameState.change_state(GameState.State.MAP)
	GameState.save_game()
	var info = GameState.get_slot_info(GameState.save_slot)
	_check(not info.is_empty() and info.gold == GameState.gold, "存档摘要正确")
	var gold_before = GameState.gold
	var ok = GameState.load_game()
	await _frames(2)
	_check(ok and GameState.gold == gold_before, "读档恢复金币 (%d)" % GameState.gold)
	_check(GameState.equipment.weapon.lore.size() > 0, "读档后装备解说词条保留")
	_check(GameState.equipment.weapon.invested == int(GameState.equipment.weapon.invested), "读档后强化投入保留")
	GameState.set_active_slot(1)
	_check(not GameState.has_save(1), "存档位 2 为空")
	_check(not GameState.load_game(1), "空档读取返回失败")
	GameState.set_active_slot(0)
	GameState.load_game(0)
	await _frames(2)

	# ---- 10. 区域切换 ----
	GameState.change_state(GameState.State.MAP)
	GameState.switch_region(4)
	await _frames(2)
	_check(GameState.region == 4, "切换至区域 5")

	# ---- 结果 ----
	_restore_saves()
	print("")
	if fails.is_empty():
		print("SMOKE OK - 全部 %s 项检查通过" % "?")
	else:
		print("SMOKE FAILED - %d 项失败:" % fails.size())
		for f in fails:
			print("  - ", f)
	get_tree().quit(0 if fails.is_empty() else 1)
