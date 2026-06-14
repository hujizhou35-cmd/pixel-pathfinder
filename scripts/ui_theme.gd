class_name UITheme
extends RefCounted

# ============================================================
# UI 主题构建器 - 中文字体 + 像素风样式
# ============================================================

const FONT_PATH := "res://assets/fonts/wqy-microhei.ttf"

const C_BG        := Color("#10131e")
const C_PANEL     := Color("#1a2030")
const C_PANEL_HI  := Color("#242c42")
const C_BORDER    := Color("#3c4a6a")
const C_GOLD      := Color("#f4c454")
const C_TEXT      := Color("#e8ecf4")
const C_TEXT_DIM  := Color("#9aa4bc")
const C_HP        := Color("#e85a5a")
const C_HP_BG     := Color("#3a1820")
const C_SHIELD    := Color("#5ab4e8")
const C_GREEN     := Color("#6fce62")
const C_DANGER    := Color("#c44a3a")

static func get_font() -> Font:
	var f = load(FONT_PATH)
	if f:
		return f
	return ThemeDB.fallback_font

static func build_theme() -> Theme:
	var theme = Theme.new()
	var font = get_font()
	theme.default_font = font
	theme.default_font_size = 17

	# 按钮样式
	theme.set_stylebox("normal", "Button", flat_box(C_PANEL_HI, C_BORDER, 2, 8, 6))
	theme.set_stylebox("hover", "Button", flat_box(Color("#2f3a58"), C_GOLD, 2, 8, 6))
	theme.set_stylebox("pressed", "Button", flat_box(Color("#161c2c"), C_GOLD, 2, 8, 6))
	theme.set_stylebox("disabled", "Button", flat_box(Color("#181c28"), Color("#2a3044"), 2, 8, 6))
	theme.set_stylebox("focus", "Button", flat_box(Color(0, 0, 0, 0), C_GOLD, 1, 8, 6))
	theme.set_color("font_color", "Button", C_TEXT)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", C_GOLD)
	theme.set_color("font_disabled_color", "Button", Color("#5a6278"))

	# 面板样式
	theme.set_stylebox("panel", "PanelContainer", flat_box(Color(0.1, 0.125, 0.185, 0.96), C_BORDER, 2, 14, 12))
	theme.set_stylebox("panel", "Panel", flat_box(Color(0.08, 0.1, 0.15, 0.85), C_BORDER, 1, 8, 6))

	# 标签
	theme.set_color("font_color", "Label", C_TEXT)

	# RichTextLabel
	theme.set_color("default_color", "RichTextLabel", C_TEXT)

	# 滚动条收窄
	var sb = flat_box(Color("#3c4a6a"), Color(0, 0, 0, 0), 0, 3, 3)
	theme.set_stylebox("grabber", "VScrollBar", sb)
	theme.set_stylebox("grabber_highlight", "VScrollBar", sb)
	theme.set_stylebox("grabber_pressed", "VScrollBar", sb)
	theme.set_stylebox("scroll", "VScrollBar", flat_box(Color(0, 0, 0, 0.25), Color(0, 0, 0, 0), 0, 3, 3))

	return theme

static func flat_box(bg: Color, border: Color, border_w: int, margin_h: int, margin_v: int) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(3)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v
	s.content_margin_bottom = margin_v
	return s

static func bar_style(fill: Color) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = fill
	s.set_corner_radius_all(2)
	return s

static func rarity_color(rarity: int) -> Color:
	return GameData.get_rarity_color(rarity)
