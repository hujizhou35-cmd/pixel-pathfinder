class_name HudPanel
extends Control

# ============================================================
# HUD - 顶部状态栏 + 右侧装备栏
# 地图与战斗视图均可见
# ============================================================

const SLOT_ICON := {
	"sword": "sword", "bow": "bow", "axe": "axe",
	"armor": "armor", "amulet": "amulet",
}

var _hp_bar: Panel
var _hp_text: Label
var _shield_lbl: Label
var _gold_lbl: Label
var _potion_btn: Button
var _region_lbl: Label
var _mute_btn: Button
var _slot_buttons: Dictionary = {}   # slot -> {btn, icon, lvl, style}
var _show_equipment: bool = true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_top_bar()
	_build_side_panel()

	SignalBus.hp_changed.connect(_on_hp)
	SignalBus.shield_changed.connect(_on_shield)
	SignalBus.gold_changed.connect(_on_gold)
	SignalBus.potion_changed.connect(_on_potion)
	SignalBus.region_changed.connect(_on_region)
	SignalBus.equipment_changed.connect(func(_s, _i): refresh_equipment())
	SignalBus.combat_started.connect(func(_e): _shield_lbl.visible = true)
	SignalBus.combat_ended.connect(func(_v): _shield_lbl.text = ""; _shield_lbl.visible = false)

func _build_top_bar() -> void:
	var bar = Panel.new()
	bar.position = Vector2(0, 0)
	bar.size = Vector2(1280, 52)
	var style = UITheme.flat_box(Color(0.05, 0.065, 0.1, 0.88), UITheme.C_BORDER, 1, 4, 2)
	style.set_corner_radius_all(0)
	bar.add_theme_stylebox_override("panel", style)
	add_child(bar)

	# HP 条
	var hp_caption = Label.new()
	hp_caption.text = "生命"
	hp_caption.add_theme_font_size_override("font_size", 14)
	hp_caption.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	hp_caption.position = Vector2(16, 15)
	bar.add_child(hp_caption)

	var hp_bg = Panel.new()
	hp_bg.add_theme_stylebox_override("panel", UITheme.bar_style(UITheme.C_HP_BG))
	hp_bg.position = Vector2(60, 16)
	hp_bg.size = Vector2(220, 20)
	bar.add_child(hp_bg)
	_hp_bar = Panel.new()
	_hp_bar.add_theme_stylebox_override("panel", UITheme.bar_style(UITheme.C_HP))
	_hp_bar.position = Vector2(60, 16)
	_hp_bar.size = Vector2(220, 20)
	bar.add_child(_hp_bar)
	_hp_text = Label.new()
	_hp_text.add_theme_font_size_override("font_size", 14)
	_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_hp_text.add_theme_constant_override("outline_size", 4)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.position = Vector2(60, 16)
	_hp_text.size = Vector2(220, 20)
	bar.add_child(_hp_text)

	# 护盾
	_shield_lbl = Label.new()
	_shield_lbl.add_theme_font_size_override("font_size", 15)
	_shield_lbl.add_theme_color_override("font_color", UITheme.C_SHIELD)
	_shield_lbl.position = Vector2(292, 15)
	_shield_lbl.size = Vector2(110, 22)
	bar.add_child(_shield_lbl)

	# 金币
	var coin_icon = _icon_rect("coin", Vector2(430, 14), 24)
	bar.add_child(coin_icon)
	_gold_lbl = Label.new()
	_gold_lbl.add_theme_font_size_override("font_size", 17)
	_gold_lbl.add_theme_color_override("font_color", UITheme.C_GOLD)
	_gold_lbl.position = Vector2(460, 13)
	_gold_lbl.size = Vector2(90, 24)
	bar.add_child(_gold_lbl)

	# 药水按钮
	_potion_btn = Button.new()
	_potion_btn.position = Vector2(560, 8)
	_potion_btn.custom_minimum_size = Vector2(110, 36)
	_potion_btn.size = Vector2(110, 36)
	_potion_btn.add_theme_font_size_override("font_size", 15)
	_potion_btn.tooltip_text = "在地图上饮用药水 (恢复40%生命)"
	_potion_btn.pressed.connect(func():
		Sfx.play("click")
		GameState.use_potion_on_map()
	)
	bar.add_child(_potion_btn)

	# 区域信息
	_region_lbl = Label.new()
	_region_lbl.add_theme_font_size_override("font_size", 16)
	_region_lbl.position = Vector2(690, 13)
	_region_lbl.size = Vector2(250, 24)
	bar.add_child(_region_lbl)

	# 切换区域（全地图开放）
	var region_btn = Button.new()
	region_btn.text = "换区"
	region_btn.position = Vector2(948, 8)
	region_btn.custom_minimum_size = Vector2(72, 36)
	region_btn.size = Vector2(72, 36)
	region_btn.add_theme_font_size_override("font_size", 14)
	region_btn.tooltip_text = "全部 5 个区域已开放，可随时切换（地图界面）"
	region_btn.pressed.connect(func():
		Sfx.play("click")
		if GameState.current_state == GameState.State.MAP:
			SignalBus.show_modal.emit("region_select", { "in_run": true })
		else:
			SignalBus.show_toast.emit("只能在地图界面切换区域")
	)
	bar.add_child(region_btn)

	# 静音
	_mute_btn = Button.new()
	_mute_btn.text = "♪ 音效"
	_mute_btn.position = Vector2(1052, 8)
	_mute_btn.custom_minimum_size = Vector2(86, 36)
	_mute_btn.size = Vector2(86, 36)
	_mute_btn.add_theme_font_size_override("font_size", 14)
	_mute_btn.pressed.connect(func():
		var m = Sfx.toggle_mute()
		_mute_btn.text = "× 静音" if m else "♪ 音效"
	)
	bar.add_child(_mute_btn)

	# 菜单(返回标题)
	var menu_btn = Button.new()
	menu_btn.text = "标题"
	menu_btn.position = Vector2(1146, 8)
	menu_btn.custom_minimum_size = Vector2(76, 36)
	menu_btn.size = Vector2(76, 36)
	menu_btn.add_theme_font_size_override("font_size", 14)
	menu_btn.tooltip_text = "保存并返回标题画面"
	menu_btn.pressed.connect(func():
		Sfx.play("click")
		if GameState.current_state == GameState.State.MAP:
			GameState.save_game()
			SignalBus.view_changed.emit("title")
		else:
			SignalBus.show_toast.emit("只能在地图界面返回标题")
	)
	bar.add_child(menu_btn)

func _build_side_panel() -> void:
	var panel = Panel.new()
	panel.position = Vector2(1196, 60)
	panel.size = Vector2(76, 600)
	panel.name = "SidePanel"
	add_child(panel)

	# 六个装备槽位：武器 / 铠甲 / 头盔 / 裤子 / 鞋 / 配饰
	var slots = GameData.EQUIP_SLOTS
	for i in range(slots.size()):
		var slot = slots[i]
		var b = Button.new()
		b.position = Vector2(8, 8 + i * 64)
		b.custom_minimum_size = Vector2(60, 58)
		b.size = Vector2(60, 58)
		b.tooltip_text = GameData.slot_name(slot)
		b.pressed.connect(func():
			Sfx.play("click")
			var it = GameState.equipment.get(slot)
			if it:
				SignalBus.show_modal.emit("equip_detail", { "slot": slot, "item": it })
			else:
				SignalBus.show_toast.emit("「%s」槽位暂无装备" % GameData.slot_name(slot))
		)
		panel.add_child(b)

		var icon = TextureRect.new()
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		icon.offset_left = 8
		icon.offset_top = 6
		icon.offset_right = -8
		icon.offset_bottom = -10
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(icon)

		var slot_tag = Label.new()
		slot_tag.text = GameData.slot_name(slot)
		slot_tag.add_theme_font_size_override("font_size", 10)
		slot_tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
		slot_tag.position = Vector2(3, 42)
		slot_tag.size = Vector2(30, 14)
		slot_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(slot_tag)

		var lvl = Label.new()
		lvl.add_theme_font_size_override("font_size", 12)
		lvl.add_theme_color_override("font_color", UITheme.C_GOLD)
		lvl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		lvl.add_theme_constant_override("outline_size", 3)
		lvl.position = Vector2(32, 40)
		lvl.size = Vector2(26, 16)
		lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		lvl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(lvl)

		_slot_buttons[slot] = { "btn": b, "icon": icon, "lvl": lvl }

	var util_defs = [
		["背包", "打开背包 [B]（32 格 · 分类查看 · 一键整理）", func(): SignalBus.show_modal.emit("bag", {})],
		["属性", "查看属性详情 [V]：基础 + 装备 + 天赋 = 总计", func(): SignalBus.show_modal.emit("stats", {})],
		["图鉴", "远征图鉴 [C]：装备 · 词条 · 天赋 · 怪物 · 首领", func(): SignalBus.show_modal.emit("codex", { "tab": "equip" })],
		["帮助", "", func(): SignalBus.show_modal.emit("help", {})],
	]
	for i in range(util_defs.size()):
		var ud = util_defs[i]
		var ub = Button.new()
		ub.text = ud[0]
		ub.position = Vector2(8, 396 + i * 50)
		ub.custom_minimum_size = Vector2(60, 42)
		ub.size = Vector2(60, 42)
		ub.add_theme_font_size_override("font_size", 15)
		if str(ud[1]) != "":
			ub.tooltip_text = ud[1]
		var cb: Callable = ud[2]
		ub.pressed.connect(func():
			Sfx.play("click")
			cb.call()
		)
		panel.add_child(ub)

func _icon_rect(name_: String, pos: Vector2, size_px: int) -> TextureRect:
	var tr = TextureRect.new()
	tr.texture = load("res://assets/sprites/icons/%s.png" % name_)
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.position = pos
	tr.size = Vector2(size_px, size_px)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr

# ------------------------------------------------------------
# 刷新
# ------------------------------------------------------------
func refresh_all() -> void:
	_on_hp(GameState.hp, GameState.max_hp)
	_on_gold(GameState.gold)
	_on_potion(GameState.potions)
	_on_region(GameState.region)
	refresh_equipment()
	_shield_lbl.text = ""

func _on_hp(cur: int, mx: int) -> void:
	var pct = clampf(float(cur) / float(maxi(1, mx)), 0.0, 1.0)
	_hp_bar.size.x = 220.0 * pct
	_hp_text.text = "%d / %d" % [cur, mx]

func _on_shield(s: int) -> void:
	_shield_lbl.text = ("◈ 护盾 %d" % s) if s > 0 else ""

func _on_gold(g: int) -> void:
	_gold_lbl.text = str(g)

func _on_potion(n: int) -> void:
	_potion_btn.text = "药水 ×%d" % n
	_potion_btn.disabled = n <= 0

func _on_region(r: int) -> void:
	var biome = GameData.get_biome(r)
	var cyc = ("周目%d · " % (GameState.cycle + 1)) if GameState.cycle > 0 else ""
	_region_lbl.text = "%s区域 %d/%d · %s" % [cyc, r + 1, GameData.BIOMES.size(), biome.name]

func refresh_equipment() -> void:
	for slot in _slot_buttons:
		var entry = _slot_buttons[slot]
		var it = GameState.equipment.get(slot)
		if it:
			entry.icon.texture = PixelArt.item_icon(it)
			entry.icon.visible = true
			entry.lvl.text = "+%d" % it.level if it.level > 0 else ""
			var rc = UITheme.rarity_color(it.rarity)
			entry.btn.add_theme_stylebox_override("normal", UITheme.flat_box(UITheme.C_PANEL_HI, rc, 2, 4, 4))
			entry.btn.add_theme_stylebox_override("hover", UITheme.flat_box(Color("#2f3a58"), rc, 3, 4, 4))
		else:
			entry.icon.visible = false
			entry.lvl.text = ""
			entry.btn.remove_theme_stylebox_override("normal")
			entry.btn.remove_theme_stylebox_override("hover")
