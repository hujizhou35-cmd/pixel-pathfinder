class_name CGLayer
extends Control

# ============================================================
# 剧情 CG 层 - 全屏展示 CG 图 + 字幕逐字浮现 + 「下一步」按钮
# 用法：SignalBus.play_cg.emit([1, 2], "tag")
#       播完后发出 SignalBus.cg_finished(tag)
# 点击「下一步」时若字幕未显示完则先补全，再次点击进入下一张
# ============================================================

var _queue: Array = []       # 待播放的 CG id 列表
var _tag: String = ""
var _pic: TextureRect
var _dim_bottom: ColorRect
var _title_lbl: Label
var _text_lbl: RichTextLabel
var _next_btn: Button
var _typing: bool = false
var _type_tween: Tween = null

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 100

	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.02, 0.05, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)

	_pic = TextureRect.new()
	_pic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pic)

	# 底部字幕暗带（淡化处理：不遮挡配图下半部分，文字靠描边保证可读）
	_dim_bottom = ColorRect.new()
	_dim_bottom.color = Color(0, 0, 0, 0.34)
	_dim_bottom.position = Vector2(0, 520)
	_dim_bottom.size = Vector2(1280, 200)
	_dim_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim_bottom)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 24)
	_title_lbl.add_theme_color_override("font_color", UITheme.C_GOLD)
	_title_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_title_lbl.add_theme_constant_override("outline_size", 5)
	_title_lbl.position = Vector2(90, 532)
	_title_lbl.size = Vector2(1100, 32)
	_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title_lbl)

	_text_lbl = RichTextLabel.new()
	_text_lbl.bbcode_enabled = false
	_text_lbl.add_theme_font_size_override("normal_font_size", 17)
	_text_lbl.add_theme_color_override("default_color", Color("#f2f5fa"))
	_text_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_text_lbl.add_theme_constant_override("outline_size", 5)
	_text_lbl.position = Vector2(90, 570)
	_text_lbl.size = Vector2(1100, 120)
	_text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_lbl.scroll_active = false
	add_child(_text_lbl)

	_next_btn = Button.new()
	_next_btn.text = "下 一 步"
	_next_btn.custom_minimum_size = Vector2(150, 44)
	_next_btn.position = Vector2(1090, 656)
	_next_btn.add_theme_font_size_override("font_size", 17)
	_next_btn.pressed.connect(_on_next)
	add_child(_next_btn)

func is_playing() -> bool:
	return visible

## 播放一组 CG；结束后发出 cg_finished(tag)
func play(ids: Array, tag: String) -> void:
	if ids.is_empty():
		SignalBus.cg_finished.emit(tag)
		return
	_queue = ids.duplicate()
	_tag = tag
	visible = true
	# 周目大 Boss 终局 CG 用更响、更具情绪的专属配乐
	var mood := "narrative"
	if tag == "cycle_encounter":
		mood = "tense"
	elif tag == "cycle_victory":
		mood = "triumph"
	Sfx.start_cg_music(mood)
	_show_current()

func _show_current() -> void:
	var id = int(_queue[0])
	var data = GameData.get_cg(id)
	var tex = load("res://assets/cg/%d.png" % id)
	_pic.texture = tex
	_title_lbl.text = str(data.get("title", ""))
	_text_lbl.text = str(data.get("text", ""))
	_next_btn.text = "下 一 步" if _queue.size() > 1 else "继 续"
	# 画面淡入 + 字幕逐字浮现
	_pic.modulate.a = 0.0
	var tw = create_tween()
	tw.tween_property(_pic, "modulate:a", 1.0, 0.45)
	_text_lbl.visible_ratio = 0.0
	_typing = true
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	var dur = clampf(_text_lbl.text.length() * 0.035, 1.2, 5.0)
	_type_tween.tween_property(_text_lbl, "visible_ratio", 1.0, dur)
	_type_tween.tween_callback(func(): _typing = false)

func _on_next() -> void:
	Sfx.play("click")
	# 字幕未显示完 → 先补全
	if _typing:
		if _type_tween:
			_type_tween.kill()
		_text_lbl.visible_ratio = 1.0
		_typing = false
		return
	_queue.pop_front()
	if _queue.is_empty():
		_finish()
	else:
		_show_current()

func _finish() -> void:
	visible = false
	_pic.texture = null
	Sfx.stop_cg_music()
	var t = _tag
	_tag = ""
	SignalBus.cg_finished.emit(t)

## 测试用：跳过整段 CG
func skip_all() -> void:
	if not visible:
		return
	_queue.clear()
	if _type_tween:
		_type_tween.kill()
	_typing = false
	_finish()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_E]:
			_on_next()
			get_viewport().set_input_as_handled()
