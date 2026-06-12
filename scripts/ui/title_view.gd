class_name TitleView
extends Control

# ============================================================
# 标题画面
# ============================================================

var _title_label: Label
var _subtitle: Label
var _btn_continue: Button
var _slot_label: Label
var _hero_rect: TextureRect
var _hero_atlas: AtlasTexture
var _t: float = 0.0

func _refresh_hero_portrait() -> void:
	var tex = PixelArt.hero_texture(GameState.equipment)
	_hero_atlas.atlas = tex
	_hero_atlas.region = Rect2(0, 0, tex.get_width(), tex.get_height() / 4.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# 暗化遮罩
	var dim = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# 标题
	_title_label = Label.new()
	_title_label.text = "像 素 探 路 者"
	_title_label.add_theme_font_size_override("font_size", 64)
	_title_label.add_theme_color_override("font_color", UITheme.C_GOLD)
	_title_label.add_theme_color_override("font_outline_color", Color("#3a2808"))
	_title_label.add_theme_constant_override("outline_size", 8)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.position = Vector2(0, 110)
	_title_label.size = Vector2(1280, 90)
	add_child(_title_label)

	_subtitle = Label.new()
	_subtitle.text = "— 节点探索 · 回合战斗 · 装备成长 —"
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position = Vector2(0, 204)
	_subtitle.size = Vector2(1280, 30)
	add_child(_subtitle)

	# 主角立绘（程序化合成，读档后随装备变化）
	_hero_atlas = AtlasTexture.new()
	_hero_rect = TextureRect.new()
	_hero_rect.texture = _hero_atlas
	_hero_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_rect.position = Vector2(556, 252)
	_hero_rect.size = Vector2(168, 180)
	_hero_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero_rect)
	_refresh_hero_portrait()

	# 按钮组
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(510, 440)
	vbox.size = Vector2(260, 260)
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_btn_continue = _mk_btn(vbox, "继 续 远 征", _on_continue)
	_mk_btn(vbox, "开 始 新 远 征", _on_new_game)
	_mk_btn(vbox, "存 档 位", _on_saves)
	_mk_btn(vbox, "图 鉴", _on_codex)
	_mk_btn(vbox, "帮 助", _on_help)
	_mk_btn(vbox, "退 出 游 戏", _on_quit)

	_slot_label = Label.new()
	_slot_label.add_theme_font_size_override("font_size", 14)
	_slot_label.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	_slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_slot_label.position = Vector2(0, 408)
	_slot_label.size = Vector2(1280, 22)
	add_child(_slot_label)

	var ver = Label.new()
	ver.text = "v5.0 · 远征路线版"
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	ver.position = Vector2(1130, 692)
	add_child(ver)

func _mk_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 42)
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call()
	)
	parent.add_child(b)
	return b

func refresh() -> void:
	_btn_continue.visible = GameState.has_save()
	_refresh_hero_portrait()
	var info = GameState.get_slot_info(GameState.save_slot)
	if info.is_empty():
		_slot_label.text = "当前存档位 %d（空）" % (GameState.save_slot + 1)
	else:
		var cyc = ("周目%d · " % (int(info.get("cycle", 0)) + 1)) if int(info.get("cycle", 0)) > 0 else ""
		_slot_label.text = "当前存档位 %d · %s · %s区域 %d · %s · 金币 %d" % [
			GameState.save_slot + 1, str(info.get("hero_name", "冒险者")), cyc, info.region + 1,
			GameData.get_biome(info.region).name, info.gold,
		]

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_title_label.position.y = 110 + sin(_t * 1.4) * 6.0
	if _hero_rect:
		_hero_rect.position.y = 252 + sin(_t * 2.0) * 4.0

func _on_continue() -> void:
	if GameState.load_game():
		SignalBus.show_toast.emit("已读取存档 — 欢迎回来，探路者")
	else:
		SignalBus.show_toast.emit("存档读取失败")
		refresh()

func _on_new_game() -> void:
	SignalBus.show_modal.emit("region_select", { "in_run": false })

func _on_saves() -> void:
	SignalBus.show_modal.emit("saves", {})

func _on_codex() -> void:
	SignalBus.show_modal.emit("codex", { "tab": "equip" })

func _on_help() -> void:
	SignalBus.show_modal.emit("help", {})

func _on_quit() -> void:
	get_tree().quit()
