class_name TitleView
extends Control

# ============================================================
# 标题画面
# ============================================================

var _title_label: Label
var _subtitle: Label
var _btn_continue: Button
var _hero_rect: TextureRect
var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# 暗化遮罩
	var dim = ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.07, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	_title_label.position = Vector2(0, 130)
	_title_label.size = Vector2(1280, 90)
	add_child(_title_label)

	_subtitle = Label.new()
	_subtitle.text = "— 节点探索 · 回合战斗 · 装备成长 —"
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.position = Vector2(0, 224)
	_subtitle.size = Vector2(1280, 30)
	add_child(_subtitle)

	# 主角立绘
	var hero_tex = load("res://assets/sprites/hero.png")
	if hero_tex:
		var atlas = AtlasTexture.new()
		atlas.atlas = hero_tex
		atlas.region = Rect2(0, 0, hero_tex.get_width(), hero_tex.get_height() / 4.0)
		_hero_rect = TextureRect.new()
		_hero_rect.texture = atlas
		_hero_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hero_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hero_rect.position = Vector2(556, 280)
		_hero_rect.size = Vector2(168, 196)
		_hero_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_hero_rect)

	# 按钮组
	var vbox = VBoxContainer.new()
	vbox.position = Vector2(510, 492)
	vbox.size = Vector2(260, 200)
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)

	_btn_continue = _mk_btn(vbox, "继 续 远 征", _on_continue)
	_mk_btn(vbox, "开 始 新 远 征", _on_new_game)
	_mk_btn(vbox, "帮 助", _on_help)
	_mk_btn(vbox, "退 出 游 戏", _on_quit)

	var ver = Label.new()
	ver.text = "v2.0 · 加强版"
	ver.add_theme_font_size_override("font_size", 13)
	ver.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	ver.position = Vector2(1160, 692)
	add_child(ver)

func _mk_btn(parent: Control, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(260, 44)
	b.add_theme_font_size_override("font_size", 20)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call()
	)
	parent.add_child(b)
	return b

func refresh() -> void:
	_btn_continue.visible = GameState.has_save()

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_title_label.position.y = 130 + sin(_t * 1.4) * 6.0
	if _hero_rect:
		_hero_rect.position.y = 280 + sin(_t * 2.0) * 4.0

func _on_continue() -> void:
	if GameState.load_game():
		SignalBus.show_toast.emit("已读取存档 — 欢迎回来，探路者")
	else:
		SignalBus.show_toast.emit("存档读取失败")
		refresh()

func _on_new_game() -> void:
	GameState.start_new_game()

func _on_help() -> void:
	SignalBus.show_modal.emit("help", {})

func _on_quit() -> void:
	get_tree().quit()
