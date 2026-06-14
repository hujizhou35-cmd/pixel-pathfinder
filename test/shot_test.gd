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

	# 敌人精灵画廊：逐一渲染所有怪物精灵，验证细节美化
	var gallery = Control.new()
	gallery.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gbg = ColorRect.new()
	gbg.color = Color("#23303a")
	gbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	gallery.add_child(gbg)
	main_node.add_child(gallery)
	var keys = ["slime", "lavablob", "wolf", "scorpion", "spirit", "elemental", "construct", "yeti", "bandit", "bandit2", "mummy", "guardian"]
	# 每只用各自真实配色，验证「保留原色 + 丰富细节」
	var gpals = {
		"slime": { "p": Color("#6fce62"), "d": Color("#2f6b24"), "e": Color("#eafff0"), "a": Color("#1f4a18") },
		"lavablob": { "p": Color("#ff7a3a"), "d": Color("#a8341e"), "e": Color("#ffe7a0"), "a": Color("#5a1408") },
		"wolf": { "p": Color("#9aa0ad"), "d": Color("#4a4e5a"), "e": Color("#ffffff"), "a": Color("#33373f") },
		"scorpion": { "p": Color("#c49a6a"), "d": Color("#6e4a2a"), "e": Color("#ffe0b0"), "a": Color("#3a2410") },
		"spirit": { "p": Color("#9fb6e8"), "d": Color("#46597f"), "e": Color("#eef4ff"), "a": Color("#2a3550") },
		"elemental": { "p": Color("#5aa7e8"), "d": Color("#2b5a8a"), "e": Color("#cfeaff"), "a": Color("#163553") },
		"construct": { "p": Color("#8b8f9c"), "d": Color("#44485a"), "e": Color("#9be8ff"), "a": Color("#2c2f3c") },
		"yeti": { "p": Color("#d9e6f2"), "d": Color("#7e95ad"), "e": Color("#7ad9ff"), "a": Color("#52677d") },
		"bandit": { "p": Color("#b07a4e"), "d": Color("#5a3a22"), "e": Color("#ffd23a"), "a": Color("#9a3b34") },
		"bandit2": { "p": Color("#7a8ec4"), "d": Color("#3a4670"), "e": Color("#ffd23a"), "a": Color("#2a3358") },
		"mummy": { "p": Color("#cdbf9e"), "d": Color("#7e7152"), "e": Color("#7fe8ff"), "a": Color("#4a4030") },
		"guardian": { "p": Color("#aeb6c6"), "d": Color("#545c70"), "e": Color("#ffe07a"), "a": Color("#d8434a") },
	}
	for gi in range(keys.size()):
		var gtex = PixelArt.enemy_texture(keys[gi], gpals[keys[gi]])
		var ga = AtlasTexture.new()
		ga.atlas = gtex
		ga.region = Rect2(0, 0, gtex.get_width(), gtex.get_height() / 2.0)
		var gr = TextureRect.new()
		gr.texture = ga
		gr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		gr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gr.custom_minimum_size = Vector2(180, 180)
		gr.position = Vector2(40 + (gi % 6) * 200, 60 + (gi / 6) * 240)
		gr.size = Vector2(180, 180)
		gallery.add_child(gr)
		var gl = Label.new()
		gl.text = keys[gi]
		gl.position = gr.position + Vector2(0, 184)
		gl.size = Vector2(180, 20)
		gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		gallery.add_child(gl)
	await _wait(0.3)
	await _shot("01b_enemy_gallery")
	gallery.queue_free()
	await _wait(0.2)

	# 装备图标画廊：各部位 × 元素，验证 20×20 精修图标
	var ig = Control.new()
	ig.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var igbg = ColorRect.new()
	igbg.color = Color("#1a2230")
	igbg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ig.add_child(igbg)
	main_node.add_child(ig)
	var fams = ["短剑", "巨剑", "刺剑", "巨斧", "长弓", "劲弩", "板甲", "龙鳞甲", "锁子甲", "骑士盔", "龙首盔", "战盔", "板甲腿铠", "龙鳞腿甲", "疾风靴", "龙行靴", "铁头靴", "秘语契珠", "圣辉遗物", "铜纹戒指", "银辉徽章", "木刻护符"]
	var elems = ["metal", "fire", "water", "wood", "earth"]
	for fi in range(fams.size()):
		var itx = PixelArt.item_icon({ "family": fams[fi], "element": elems[fi % elems.size()] })
		var ir = TextureRect.new()
		ir.texture = itx
		ir.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ir.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ir.position = Vector2(40 + (fi % 8) * 150, 50 + (fi / 8) * 175)
		ir.size = Vector2(120, 120)
		ig.add_child(ir)
		var il = Label.new()
		il.text = fams[fi]
		il.position = ir.position + Vector2(0, 122)
		il.size = Vector2(120, 18)
		il.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		ig.add_child(il)
	await _wait(0.3)
	await _shot("01c_icon_gallery")
	ig.queue_free()
	await _wait(0.2)

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
	await _wait(0.8)
	await _shot("02c_cg_intro1")
	# 翻到序章后段与区域进入 CG（验证字幕暗带淡化后可读性）
	for i in range(4):
		main_node.cg_layer._on_next()
		await _wait(0.1)
		main_node.cg_layer._on_next()   # 第一次补全字幕，第二次翻页
		await _wait(0.3)
	await _shot("02d_cg_intro5")
	main_node.cg_layer._on_next()
	await _wait(0.1)
	main_node.cg_layer._on_next()
	await _wait(0.5)
	await _shot("02e_cg_region_enter")
	main_node.cg_layer.skip_all()
	await _wait(0.3)
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

	# 周目大 Boss 压轴战：四只新程序化精灵逐一截图
	GameState.region = 4
	GameState.cycle = 0
	for k in range(GameData.CYCLE_BOSSES.size()):
		var bdef = GameData.CYCLE_BOSSES[k]
		GameState.combat_state = CombatManager.setup_cycle_boss(0, bdef)
		SignalBus.combat_started.emit(GameState.combat_state.enemies)
		SignalBus.view_changed.emit("combat")
		await _wait(0.7)
		await _shot("07b_cycleboss_%d_%s" % [k, str(bdef.key)])
	# 周目大 Boss 登场 CG（验证新 CG 资源链路）
	SignalBus.play_cg.emit([19, 20], "cycle_encounter")
	await _wait(0.6)
	await _shot("07c_cycleboss_cg")
	main_node.cg_layer.skip_all()
	await _wait(0.3)
	GameState.region = 0
	GameState.change_state(GameState.State.MAP)
	SignalBus.view_changed.emit("map")
	await _wait(0.3)

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
	# 展开第 1 件物品 → 验证折叠/展开（名称+特性+操作按钮）
	SignalBus.show_modal.emit("bag", { "expanded": [0] })
	await _wait(0.4)
	await _shot("09a_bag_expanded")
	modal.close_all()
	SignalBus.show_modal.emit("bag", { "filter": "clothes" })
	await _wait(0.4)
	await _shot("09b_bag_clothes_filter")
	modal.close_all()
	# 已穿戴装备详情：验证脱下/强化/精铸/熔炼/出售/分解全套按钮
	SignalBus.show_modal.emit("equip_detail", { "slot": "weapon", "item": GameState.equipment.weapon })
	await _wait(0.4)
	await _shot("09d_equip_detail_actions")
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

	# 图鉴：装备库 / 搜索 / 机制页 / 怪物 / 元素
	SignalBus.show_modal.emit("codex", { "tab": "equip" })
	await _wait(0.5)
	await _shot("10_codex_equip100")
	modal.close_all()
	SignalBus.show_modal.emit("codex", { "tab": "equip", "query": "连击", "q": "连击" })
	await _wait(0.5)
	await _shot("10a_codex_search")
	modal.close_all()
	SignalBus.show_modal.emit("codex", { "tab": "monster", "locate": "史莱姆" })
	await _wait(0.6)
	await _shot("10a2_codex_locate")
	modal.close_all()
	SignalBus.show_modal.emit("codex", { "tab": "mech" })
	await _wait(0.4)
	await _shot("10b_codex_mechanics")
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
