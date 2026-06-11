extends Node

# ============================================================
# 临时截图测试：自动截取关键界面供人工检查渲染效果
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

func _run() -> void:
	var modal = main_node.modal_layer

	await _wait(0.5)
	await _shot("01_title")

	# 区域选择
	SignalBus.show_modal.emit("region_select", { "in_run": false })
	await _wait(0.4)
	await _shot("02_region_select")
	modal.close_all()

	GameState.start_new_game(0)
	await _wait(0.5)
	await _shot("03_map")

	# 战斗（剑）
	GameState.enter_combat(false, false)
	await _wait(0.8)
	await _shot("04_combat_sword")
	main_node.combat_node.player_attack(0)
	await _wait(0.25)
	await _shot("05_combat_attack")
	await _wait(2.0)

	# 换弓战斗
	var bow = EquipmentFactory.generate_item(2, "weapon", GameData.Rarity.LEGENDARY)
	while bow.key != "bow":
		bow = EquipmentFactory.generate_item(2, "weapon", GameData.Rarity.LEGENDARY)
	GameState.equipment.weapon = bow
	SignalBus.equipment_changed.emit("weapon", bow)
	await _wait(0.3)
	if main_node.combat_node and main_node.combat_node.can_player_act():
		main_node.combat_node.player_attack(0)
		await _wait(0.18)
	await _shot("06_combat_bow")
	await _wait(2.0)

	# 奖励 + 背包叠加
	GameState.pending_drop = EquipmentFactory.generate_item(2, "weapon", GameData.Rarity.LEGENDARY)
	SignalBus.show_modal.emit("reward", { "gold": 42, "drop": GameState.pending_drop })
	await _wait(0.4)
	await _shot("07_reward_legendary")
	SignalBus.show_modal.emit("bag", {})
	await _wait(0.4)
	await _shot("08_bag_over_reward")
	modal.close_all()
	GameState.pending_drop = null
	GameState.change_state(GameState.State.MAP)
	SignalBus.view_changed.emit("map")
	await _wait(0.3)

	# 图鉴 / 属性 / 存档位 / 事件
	SignalBus.show_modal.emit("codex", { "tab": "monster" })
	await _wait(0.4)
	await _shot("09_codex_monster")
	modal.close_all()
	SignalBus.show_modal.emit("stats", {})
	await _wait(0.4)
	await _shot("10_stats")
	modal.close_all()
	SignalBus.show_modal.emit("saves", {})
	await _wait(0.4)
	await _shot("11_saves")
	modal.close_all()
	GameState.open_event()
	await _wait(0.4)
	await _shot("12_event")
	modal.close_all()

	_restore_saves()
	print("SHOTS DONE")
	get_tree().quit()
