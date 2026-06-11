class_name MapView
extends Control

# ============================================================
# 地图视图 - 自由选关式（元气骑士式）
# - 所有未探索节点随时可进；打完首领即过区
# - 战斗/精英/首领节点点击后先弹出怪物预览，确认再进
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
var _hero_atlas: AtlasTexture
var _region_label: Label
var _hint_label: Label
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
	_region_label.position = Vector2(0, 60)
	_region_label.size = Vector2(1280, 40)
	_region_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_region_label)

	_hint_label = Label.new()
	_hint_label.text = "所有节点自由探索 · 收集完资源再去挑战首领，或直奔首领过关"
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position = Vector2(0, 98)
	_hint_label.size = Vector2(1280, 22)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)

	_hero_atlas = AtlasTexture.new()
	_hero_marker = TextureRect.new()
	_hero_marker.texture = _hero_atlas
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
	var cycle_txt = ""
	if GameState.cycle > 0:
		cycle_txt = "强化 %d 周目 · " % GameState.cycle
	_region_label.text = "%s区域 %d / %d  ·  %s" % [cycle_txt, GameState.region + 1, GameData.BIOMES.size(), biome.name]

	# 英雄标记贴图（随装备变化）
	var hero_tex = PixelArt.hero_texture(GameState.equipment)
	_hero_atlas.atlas = hero_tex
	_hero_atlas.region = Rect2(0, 0, hero_tex.get_width(), hero_tex.get_height() / 4.0)

	var rows: Array = map.rows
	for r in range(rows.size()):
		var row: Array = rows[r]
		var y = 600.0 - r * 142.0
		for c in range(row.size()):
			var node = row[c]
			var x = 620.0 + (c - (row.size() - 1) / 2.0) * 250.0
			_node_pos[node.id] = Vector2(x, y)
			_make_node_button(node, Vector2(x, y))

	_update_states()
	queue_redraw()

func _make_node_button(node: Dictionary, center: Vector2) -> void:
	var b = Button.new()
	var is_boss = node.type == GameData.NodeType.BOSS
	var bsize = Vector2(92, 92) if is_boss else Vector2(76, 76)
	b.custom_minimum_size = bsize
	b.size = bsize
	b.position = center - bsize / 2.0
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

	# 节点说明（战斗节点显示敌人数量）
	var label_text: String = GameData.NODE_TYPE_NAMES.get(node.type, "?")
	var foes: Array = node.get("foes", [])
	if node.type in [GameData.NodeType.BATTLE, GameData.NodeType.ELITE] and foes.size() > 0:
		label_text += " ×%d" % foes.size()
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, bsize.y - 22)
	lbl.size = Vector2(bsize.x, 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lbl)

	# 提示
	match node.type:
		GameData.NodeType.BATTLE, GameData.NodeType.ELITE, GameData.NodeType.BOSS:
			b.tooltip_text = "点击预览怪物情报"
		GameData.NodeType.EVENT:
			b.tooltip_text = "未知事件"
		_:
			b.tooltip_text = GameData.NODE_TYPE_NAMES.get(node.type, "?")

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
			_hero_marker.position = p + Vector2(34, -62)
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
	# 战斗类节点：先弹出怪物预览
	if node.type in [GameData.NodeType.BATTLE, GameData.NodeType.ELITE, GameData.NodeType.BOSS]:
		SignalBus.show_modal.emit("node_preview", { "node": node })
	else:
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
