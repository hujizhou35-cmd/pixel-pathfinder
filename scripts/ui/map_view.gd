class_name MapView
extends Control

# ============================================================
# 地图视图 - 节点式探索地图
# 行 0 在底部，行 4(首领) 在顶部
# ============================================================

const ICON_BY_TYPE := {
	GameData.NodeType.BATTLE:   "swords",
	GameData.NodeType.ELITE:    "skull",
	GameData.NodeType.TREASURE: "chest",
	GameData.NodeType.SHOP:     "shop",
	GameData.NodeType.EVENT:    "question",
	GameData.NodeType.BOSS:     "crown",
}

var _node_buttons: Dictionary = {}   # id -> Button
var _node_pos: Dictionary = {}       # id -> Vector2 (中心)
var _reachable_ids: Array = []
var _hero_marker: TextureRect
var _region_label: Label
var _t: float = 0.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_region_label = Label.new()
	_region_label.add_theme_font_size_override("font_size", 26)
	_region_label.add_theme_color_override("font_color", UITheme.C_GOLD)
	_region_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	_region_label.add_theme_constant_override("outline_size", 6)
	_region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_region_label.position = Vector2(0, 64)
	_region_label.size = Vector2(1280, 40)
	_region_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_region_label)

	var hero_tex = load("res://assets/sprites/hero.png")
	if hero_tex:
		var atlas = AtlasTexture.new()
		atlas.atlas = hero_tex
		atlas.region = Rect2(0, 0, hero_tex.get_width(), hero_tex.get_height() / 4.0)
		_hero_marker = TextureRect.new()
		_hero_marker.texture = atlas
		_hero_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_hero_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_hero_marker.size = Vector2(52, 60)
		_hero_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hero_marker.visible = false
		add_child(_hero_marker)

func refresh() -> void:
	# 清理旧按钮
	for id in _node_buttons:
		_node_buttons[id].queue_free()
	_node_buttons.clear()
	_node_pos.clear()

	var map = GameState.current_map
	if not map.has("rows"):
		return

	var biome = GameData.get_biome(GameState.region)
	_region_label.text = "区域 %d / %d  ·  %s" % [GameState.region + 1, GameData.BIOMES.size(), biome.name]

	var rows: Array = map.rows
	for r in range(rows.size()):
		var row: Array = rows[r]
		var y = 596.0 - r * 112.0
		for c in range(row.size()):
			var node = row[c]
			var x = 640.0 + (c - (row.size() - 1) / 2.0) * 230.0
			_node_pos[node.id] = Vector2(x, y)
			_make_node_button(node, Vector2(x, y))

	_update_states()
	queue_redraw()

func _make_node_button(node: Dictionary, center: Vector2) -> void:
	var b = Button.new()
	b.custom_minimum_size = Vector2(76, 76)
	b.size = Vector2(76, 76)
	b.position = center - Vector2(38, 38)
	b.tooltip_text = GameData.NODE_TYPE_NAMES.get(node.type, "?")
	b.pressed.connect(func(): _on_node_pressed(node))
	add_child(b)

	var icon_name = ICON_BY_TYPE.get(node.type, "question")
	var tex = load("res://assets/sprites/icons/%s.png" % icon_name)
	if tex:
		var tr = TextureRect.new()
		tr.texture = tex
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.offset_left = 12
		tr.offset_top = 8
		tr.offset_right = -12
		tr.offset_bottom = -16
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(tr)

	var lbl = Label.new()
	lbl.text = GameData.NODE_TYPE_NAMES.get(node.type, "?")
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, 54)
	lbl.size = Vector2(76, 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lbl)

	_node_buttons[node.id] = b

func _update_states() -> void:
	_reachable_ids = _get_reachable_ids()
	var map = GameState.current_map
	for node in map.get("nodes", []):
		var b: Button = _node_buttons.get(node.id)
		if not b:
			continue
		var reachable = _reachable_ids.has(node.id)
		b.disabled = not reachable
		if node.id == GameState.current_node_idx:
			b.modulate = Color(1.0, 0.95, 0.7, 1.0)
		elif node.visited:
			b.modulate = Color(0.55, 0.55, 0.6, 0.8)
		elif reachable:
			b.modulate = Color.WHITE
		else:
			b.modulate = Color(0.7, 0.7, 0.75, 0.55)

	# 英雄标记
	if _hero_marker:
		if GameState.current_node_idx >= 0 and _node_pos.has(GameState.current_node_idx):
			var p: Vector2 = _node_pos[GameState.current_node_idx]
			_hero_marker.position = p + Vector2(30, -56)
			_hero_marker.visible = true
		else:
			_hero_marker.visible = false
	queue_redraw()

func _get_reachable_ids() -> Array:
	var raw = GameState.get_reachable_nodes()
	var ids = []
	for x in raw:
		if x is Dictionary:
			ids.append(x.id)
		else:
			ids.append(int(x))
	return ids

func _on_node_pressed(node: Dictionary) -> void:
	if not _reachable_ids.has(node.id):
		return
	Sfx.play("click")
	GameState.enter_node(node)

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# 可达节点呼吸发光
	var pulse = 0.85 + 0.15 * sin(_t * 4.0)
	for id in _reachable_ids:
		var b: Button = _node_buttons.get(id)
		if b and id != GameState.current_node_idx:
			b.modulate = Color(pulse, pulse, pulse * 0.85 + 0.15, 1.0)
	if _hero_marker and _hero_marker.visible:
		_hero_marker.position.y += sin(_t * 5.0) * 0.15

func _draw() -> void:
	var map = GameState.current_map
	if not map.has("nodes"):
		return
	for node in map.nodes:
		if not _node_pos.has(node.id):
			continue
		var from: Vector2 = _node_pos[node.id]
		for nxt in node.next:
			if not _node_pos.has(nxt):
				continue
			var to: Vector2 = _node_pos[nxt]
			var col = Color(1, 1, 1, 0.18)
			var w = 3.0
			if node.visited and _reachable_ids.has(nxt):
				col = Color(UITheme.C_GOLD.r, UITheme.C_GOLD.g, UITheme.C_GOLD.b, 0.8)
				w = 4.0
			elif node.visited:
				col = Color(1, 1, 1, 0.35)
			_draw_dotted(from + Vector2(0, -36), to + Vector2(0, 36), col, w)

func _draw_dotted(a: Vector2, b: Vector2, col: Color, width: float) -> void:
	var dir = b - a
	var length = dir.length()
	if length < 1.0:
		return
	dir = dir / length
	var seg := 10.0
	var gap := 7.0
	var d := 0.0
	while d < length:
		var e = minf(d + seg, length)
		draw_line(a + dir * d, a + dir * e, col, width)
		d = e + gap
