class_name MapView
extends Control

# ============================================================
# 地图视图 - 有序路线地图（杀戮尖塔式）
# - 节点间以虚线相连，小人用 WASD 沿连线移动，可折返换路
# - 站上节点后按 E / 回车 / 点击节点 选择是否进入
# - 已结束的战斗变暗（可经过不可再进）；商店可重复进入
# ============================================================

const ICON_BY_TYPE := {
	GameData.NodeType.BATTLE:   "swords",
	GameData.NodeType.ELITE:    "skull",
	GameData.NodeType.TREASURE: "chest",
	GameData.NodeType.SHOP:     "shop",
	GameData.NodeType.EVENT:    "question",
	GameData.NodeType.BOSS:     "crown",
}

const START_POS := Vector2(640.0, 686.0)   # 起点（地图下方）

var _node_buttons: Dictionary = {}   # id -> Button
var _node_pos: Dictionary = {}       # id -> Vector2 (中心)
var _adjacent_ids: Array = []
var _hero_marker: TextureRect
var _hero_atlas: AtlasTexture
var _region_label: Label
var _hint_label: Label
var _enter_label: Label
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
	_region_label.position = Vector2(0, 58)
	_region_label.size = Vector2(1280, 40)
	_region_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_region_label)

	_hint_label = Label.new()
	_hint_label.text = "WASD 沿路线移动小人 · E / 回车 进入所站节点 · 已打过的战斗可经过不可再进 · 商店可回访"
	_hint_label.add_theme_font_size_override("font_size", 14)
	_hint_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.55))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_label.position = Vector2(0, 96)
	_hint_label.size = Vector2(1280, 22)
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint_label)

	_hero_atlas = AtlasTexture.new()
	_hero_marker = TextureRect.new()
	_hero_marker.texture = _hero_atlas
	_hero_marker.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero_marker.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hero_marker.size = Vector2(56, 64)
	_hero_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hero_marker.visible = false
	add_child(_hero_marker)

	_enter_label = Label.new()
	_enter_label.add_theme_font_size_override("font_size", 14)
	_enter_label.add_theme_color_override("font_color", UITheme.C_GOLD)
	_enter_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_enter_label.add_theme_constant_override("outline_size", 5)
	_enter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enter_label.size = Vector2(160, 20)
	_enter_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_enter_label.visible = false
	add_child(_enter_label)

func refresh() -> void:
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
	var row_n = rows.size()
	for r in range(row_n):
		var row: Array = rows[r]
		var y = 622.0 - r * 118.0
		var spacing = minf(230.0, 880.0 / maxf(1.0, row.size() - 0.0))
		for c in range(row.size()):
			var node = row[c]
			var x = 640.0 + (c - (row.size() - 1) / 2.0) * spacing
			_node_pos[int(node.id)] = Vector2(x, y)
			_make_node_button(node, Vector2(x, y))

	_update_states()
	queue_redraw()

func _make_node_button(node: Dictionary, center: Vector2) -> void:
	var b = Button.new()
	var is_boss = node.type == GameData.NodeType.BOSS
	var bsize = Vector2(88, 88) if is_boss else Vector2(72, 72)
	b.custom_minimum_size = bsize
	b.size = bsize
	b.position = center - bsize / 2.0
	b.pressed.connect(func(): _on_node_pressed(node))
	add_child(b)

	# 已探索的节点（商店除外）换成旗帜图标，一眼区分
	var done = bool(node.get("visited", false)) and node.type != GameData.NodeType.SHOP
	var icon_name = "flag" if done else ICON_BY_TYPE.get(node.type, "question")
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

	# 节点说明（战斗节点显示敌人数量；商店标注可回访；已探索明确标出）
	var label_text: String = GameData.NODE_TYPE_NAMES.get(node.type, "?")
	var foes: Array = node.get("foes", [])
	if done:
		label_text = "已探索"
	elif node.type in [GameData.NodeType.BATTLE, GameData.NodeType.ELITE] and foes.size() > 0:
		label_text += " ×%d" % foes.size()
	if node.type == GameData.NodeType.SHOP and node.get("visited", false):
		label_text += "·可回访"
	var lbl = Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color("#7ea06a") if done else UITheme.C_TEXT_DIM)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, bsize.y - 22)
	lbl.size = Vector2(bsize.x, 18)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(lbl)

	match node.type:
		GameData.NodeType.BATTLE, GameData.NodeType.ELITE, GameData.NodeType.BOSS:
			b.tooltip_text = "站上节点后按 E 侦察并进入"
		GameData.NodeType.EVENT:
			b.tooltip_text = "未知事件"
		GameData.NodeType.SHOP:
			b.tooltip_text = "商店（可重复进入）"
		_:
			b.tooltip_text = GameData.NODE_TYPE_NAMES.get(node.type, "?")

	_node_buttons[int(node.id)] = b

func _update_states() -> void:
	_adjacent_ids = GameState.get_adjacent_ids()
	var map = GameState.current_map
	for node in map.get("nodes", []):
		var b: Button = _node_buttons.get(int(node.id))
		if not b:
			continue
		var adjacent = _adjacent_ids.has(int(node.id))
		var on_it = int(node.id) == GameState.hero_pos
		b.disabled = not (adjacent or on_it)
		if on_it:
			b.modulate = Color(1.0, 0.95, 0.7, 1.0)
		elif node.visited and node.type != GameData.NodeType.SHOP:
			b.modulate = Color(0.42, 0.5, 0.42, 0.62)   # 已探索：绿灰压暗
		elif adjacent:
			b.modulate = Color.WHITE
		else:
			b.modulate = Color(0.68, 0.68, 0.74, 0.5)

	_place_hero_marker()
	_update_enter_label()
	queue_redraw()

func _hero_screen_pos() -> Vector2:
	if GameState.hero_pos >= 0 and _node_pos.has(GameState.hero_pos):
		return _node_pos[GameState.hero_pos]
	return START_POS

func _place_hero_marker() -> void:
	if not _hero_marker:
		return
	var p = _hero_screen_pos()
	_hero_marker.position = p + Vector2(26, -70)
	_hero_marker.visible = true

func _update_enter_label() -> void:
	var node = GameState.get_node_by_id(GameState.hero_pos) if GameState.hero_pos >= 0 else null
	if node != null and GameState.can_enter_node(node):
		var p: Vector2 = _node_pos.get(int(node.id), START_POS)
		_enter_label.text = "[E] 进入%s" % GameData.NODE_TYPE_NAMES.get(node.type, "")
		_enter_label.position = p + Vector2(-80, 44)
		_enter_label.visible = true
	else:
		_enter_label.visible = false

# ------------------------------------------------------------
# 路线绘制：相邻排之间的虚线连线
# ------------------------------------------------------------
func _draw() -> void:
	var map = GameState.current_map
	if not map.has("nodes"):
		return
	for node in map.nodes:
		var from: Vector2 = _node_pos.get(int(node.id), Vector2.ZERO)
		if from == Vector2.ZERO:
			continue
		for nx in node.get("next", []):
			var to: Vector2 = _node_pos.get(int(nx), Vector2.ZERO)
			if to == Vector2.ZERO:
				continue
			var dir = (to - from).normalized()
			var a = from + dir * 44.0
			var bpt = to - dir * 44.0
			var col = Color(1, 1, 1, 0.28)
			# 小人所在节点的可走路线高亮
			if int(node.id) == GameState.hero_pos or int(nx) == GameState.hero_pos:
				col = Color(1.0, 0.9, 0.5, 0.55)
			draw_dashed_line(a, bpt, col, 2.0, 8.0)
	# 起点 → 底排的连线
	if GameState.hero_pos < 0:
		for id in _adjacent_ids:
			var to: Vector2 = _node_pos.get(int(id), Vector2.ZERO)
			if to == Vector2.ZERO:
				continue
			var dir = (to - START_POS).normalized()
			draw_dashed_line(START_POS + dir * 30.0, to - dir * 44.0, Color(1.0, 0.9, 0.5, 0.55), 2.0, 8.0)

# ------------------------------------------------------------
# 输入：WASD 移动 / E 进入（由 main.gd 转发）
# ------------------------------------------------------------
func handle_key(keycode: int) -> void:
	match keycode:
		KEY_W, KEY_UP:    _try_move(Vector2(0, -1))
		KEY_S, KEY_DOWN:  _try_move(Vector2(0, 1))
		KEY_A, KEY_LEFT:  _try_move(Vector2(-1, 0))
		KEY_D, KEY_RIGHT: _try_move(Vector2(1, 0))
		KEY_E, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _try_enter_current()

## 按方向挑选最匹配的相邻节点（余弦相似度），沿连线移动
func _try_move(dir: Vector2) -> void:
	var from = _hero_screen_pos()
	var best_id = -1
	var best_score = 0.35   # 方向至少要大致一致
	for id in _adjacent_ids:
		var p: Vector2 = _node_pos.get(int(id), Vector2.ZERO)
		if p == Vector2.ZERO:
			continue
		var v = p - from
		if v.length() < 1.0:
			continue
		var score = dir.dot(v.normalized())
		if score > best_score:
			best_score = score
			best_id = int(id)
	if best_id < 0:
		return
	if GameState.move_hero(best_id):
		Sfx.play("click")
		_animate_hero_to(best_id)
		_update_states()

func _animate_hero_to(node_id: int) -> void:
	var p: Vector2 = _node_pos.get(node_id, START_POS)
	var tw = create_tween()
	tw.tween_property(_hero_marker, "position", p + Vector2(26, -70), 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## 进入小人所站节点（战斗类先弹侦察预览）
func _try_enter_current() -> void:
	if GameState.hero_pos < 0:
		SignalBus.show_toast.emit("先用 WASD 移动到一个节点上")
		return
	var node = GameState.get_node_by_id(GameState.hero_pos)
	if node == null:
		return
	if not GameState.can_enter_node(node):
		SignalBus.show_toast.emit("这里已经探索过了，去别处看看吧")
		return
	Sfx.play("click")
	if node.type in [GameData.NodeType.BATTLE, GameData.NodeType.ELITE, GameData.NodeType.BOSS]:
		SignalBus.show_modal.emit("node_preview", { "node": node })
	else:
		GameState.enter_node(node)

## 点击：相邻节点 = 移动过去；所站节点 = 尝试进入
func _on_node_pressed(node: Dictionary) -> void:
	var id = int(node.id)
	if id == GameState.hero_pos:
		_try_enter_current()
		return
	if _adjacent_ids.has(id):
		if GameState.move_hero(id):
			Sfx.play("click")
			_animate_hero_to(id)
			_update_states()

func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	# 相邻可走节点呼吸发光
	var pulse = 0.85 + 0.15 * sin(_t * 4.0)
	for id in _adjacent_ids:
		var b: Button = _node_buttons.get(int(id))
		if b and int(id) != GameState.hero_pos:
			var node = GameState.get_node_by_id(int(id))
			if node and node.visited and node.type != GameData.NodeType.SHOP:
				continue
			b.modulate = Color(pulse, pulse, pulse * 0.85 + 0.15, 1.0)
	if _hero_marker and _hero_marker.visible:
		_hero_marker.position.y += sin(_t * 5.0) * 0.15
	if _enter_label and _enter_label.visible:
		_enter_label.modulate.a = 0.7 + 0.3 * sin(_t * 5.0)
