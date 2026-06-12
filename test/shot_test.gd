extends Node

# ============================================================
# 截图测试：自动截取关键界面供人工检查渲染效果
# 运行: godot --path . res://test/shot_test.tscn
# 输出: 项目目录/test/shots/*.png
# ============================================================

var main_node: Control

func _ready() -> void:
	_backup_saves()
	await get_tree().process_frame
	main_node = load("res://scenes/main.tscn").instantiate()
	add_child(main_node)
	await get_tree().process_frame
	await _run()

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

func _shot(name_: String) -> void:
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	var dir = ProjectSettings.globalize_path("res://test/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/" + name_ + ".png")
	print("[shot] ", name_)

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _gear(entry_id: String, rar: int) -> Dictionary:
	return EquipmentFactory.build_from_entry(ItemCatalog.get_entry(entry_id), 2, rar)

func _run() -> void:
	var modal = main_node.modal_layer

	await _wait(0.5)
	await _shot("01_title")

	# 区域选择
	SignalBus.show_modal.emit("region_select", { "in_run": false })
	await _wait(0.4)
	await _shot("02_region_select")
	modal.close_all()

	# 新远征设置：起名 + 天赋点分配
	SignalBus.show_modal.emit("new_run_setup", { "region": 0, "talents": { "vit": 4, "str": 3, "tough": 2, "agi": 1 } })
	await _wait(0.4)
	await _shot("02b_new_run_setup")
	modal.close_all()

	GameState.start_new_game(0, "图鉴骑士", { "vit": 4, "str": 3, "tough": 2, "agi": 1 })
	await _wait(0.5)
	await _shot("03_map")

	# 地图移动：小人走两步（验证路线与高亮）
	var adj = GameState.get_adjacent_ids()
	if adj.size() > 0:
		main_node.map_view.handle_key(KEY_W)
		await _wait(0.4)
		main_node.map_view.handle_key(KEY_W)
		await _wait(0.4)
		await _shot("03b_map_moved")

	# 关卡预览（侦察）
	var battle_node = null
	for n in GameState.current_map.nodes:
		if n.type == GameData.NodeType.BATTLE:
			battle_node = n
			break
	if battle_node:
		SignalBus.show_modal.emit("node_preview", { "node": battle_node })
		await _wait(0.4)
		await _shot("04_node_preview")
		modal.close_all()

	# 战斗（六件套：检查英雄合成外观——头盔/裤子/鞋全部上身）
	GameState.equipment.weapon = _gear("metal_巨剑", GameData.Rarity.EPIC)
	GameState.equipment.armor = _gear("fire_板甲", GameData.Rarity.LEGENDARY)
	GameState.equipment.helmet = _gear("metal_龙首盔", GameData.Rarity.EPIC)
	GameState.equipment.pants = _gear("earth_板甲腿铠", GameData.Rarity.RARE)
	GameState.equipment.boots = _gear("fire_疾风靴", GameData.Rarity.RARE)
	GameState.equipment.accessory = _gear("water_秘语契珠", GameData.Rarity.RARE)
	GameState._recalc_stats()
	SignalBus.equipment_changed.emit("weapon", GameState.equipment.weapon)
	GameState.enter_combat(false, false)
	await _wait(0.8)
	await _shot("05_combat_sword_plate")
	main_node.combat_node.player_attack(0)
	await _wait(0.25)
	await _shot("06_combat_attack")
	await _wait(2.2)

	# 换弓 + 轻甲 + 皮帽
	GameState.equipment.weapon = _gear("wood_长弓", GameData.Rarity.LEGENDARY)
	GameState.equipment.armor = _gear("earth_皮甲", GameData.Rarity.RARE)
	GameState.equipment.helmet = _gear("wood_皮帽", GameData.Rarity.COMMON)
	GameState._recalc_stats()
	SignalBus.equipment_changed.emit("weapon", GameState.equipment.weapon)
	await _wait(0.3)
	if main_node.combat_node and main_node.combat_node.can_player_act():
		main_node.combat_node.player_attack(0)
		await _wait(0.2)
	await _shot("07_combat_bow")
	await _wait(2.2)

	# 奖励 + 背包叠加（含熔炼按钮/精华区/分类页签）
	GameState.bag.append(EquipmentFactory.generate_item(2, "weapon", GameData.Rarity.EPIC))
	GameState.bag.append(EquipmentFactory.generate_item(2, "helmet", GameData.Rarity.RARE))
	GameState.bag.append(EquipmentFactory.generate_item(2, "boots", GameData.Rarity.EPIC))
	GameState.essences.append({ "affix": "lifesteal", "from": "测试精华" })
	GameState.pending_drop = EquipmentFactory.generate_item(2, "weapon", GameData.Rarity.LEGENDARY)
	SignalBus.show_modal.emit("reward", { "gold": 42, "drop": GameState.pending_drop })
	await _wait(0.4)
	await _shot("08_reward_legendary")
	SignalBus.show_modal.emit("bag", {})
	await _wait(0.4)
	await _shot("09_bag_over_reward")
	modal.close_all()
	SignalBus.show_modal.emit("bag", { "filter": "clothes" })
	await _wait(0.4)
	await _shot("09b_bag_clothes_filter")
	modal.close_all()
	GameState.pending_drop = null
	GameState.change_state(GameState.State.MAP)
	SignalBus.view_changed.emit("map")
	await _wait(0.3)

	# 天赋三选一
	SignalBus.show_modal.emit("perk_choice", { "offers": ["berserker", "bashmaster", "elementalist"] })
	await _wait(0.4)
	await _shot("09c_perk_choice")
	modal.close_all()

	# 图鉴：装备库 100 件 / 怪物 / 五行
	SignalBus.show_modal.emit("codex", { "tab": "equip" })
	await _wait(0.5)
	await _shot("10_codex_equip100")
	modal.close_all()
	SignalBus.show_modal.emit("codex", { "tab": "monster" })
	await _wait(0.4)
	await _shot("11_codex_monster")
	modal.close_all()
	SignalBus.show_modal.emit("codex", { "tab": "element" })
	await _wait(0.4)
	await _shot("12_codex_element")
	modal.close_all()

	# 属性（含套装/五行）/ 商店 / 事件
	SignalBus.show_modal.emit("stats", {})
	await _wait(0.4)
	await _shot("13_stats")
	modal.close_all()
	GameState.open_shop()
	await _wait(0.4)
	await _shot("14_shop")
	modal.close_all()
	GameState.change_state(GameState.State.MAP)
	GameState.open_event()
	await _wait(0.4)
	await _shot("15_event")
	modal.close_all()

	_restore_saves()
	print("SHOTS DONE")
	get_tree().quit()
