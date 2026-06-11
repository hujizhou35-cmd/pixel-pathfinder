class_name CombatView
extends Control

# ============================================================
# 战斗视图
# - 英雄 4 帧动画 / 敌人 2 帧待机动画 (AtlasTexture)
# - 点击敌人选择目标，攻击突进动画，受击白闪
# - 漂浮伤害数字、血条/护盾条、彩色战斗日志
# ============================================================

const HERO_POS := Vector2(250, 560)       # 英雄脚底位置
const GROUND_Y := 560.0
const LOG_COLORS := {
	"player": "#9fd6ff",
	"enemy":  "#ff9b8a",
	"system": "#c8cede",
	"crit":   "#ffd95e",
	"heal":   "#8aeb9a",
}

var combat_node: CombatStateMachine = null

var _hero: TextureRect
var _hero_atlas: AtlasTexture
var _hero_frame_h: float = 30.0
var _hero_base_pos: Vector2

var _enemy_slots: Array = []   # [{root, sprite, atlas, hp_bar, shield_lbl, name_lbl, frame_h, base_pos, ring}]
var _selected: int = -1

var _log: RichTextLabel
var _turn_label: Label
var _btn_attack: Button
var _btn_skill: Button
var _btn_defend: Button
var _btn_potion: Button
var _float_layer: Control
var _anim_t: float = 0.0
var _frame_flip: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 英雄
	var hero_tex = load("res://assets/sprites/hero.png")
	_hero_atlas = AtlasTexture.new()
	_hero_atlas.atlas = hero_tex
	_hero_frame_h = hero_tex.get_height() / 4.0
	_hero_atlas.region = Rect2(0, 0, hero_tex.get_width(), _hero_frame_h)
	_hero = TextureRect.new()
	_hero.texture = _hero_atlas
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.stretch_mode = TextureRect.STRETCH_SCALE
	var hero_scale := 6.0
	_hero.size = Vector2(hero_tex.get_width() * hero_scale, _hero_frame_h * hero_scale)
	_hero_base_pos = Vector2(HERO_POS.x - _hero.size.x / 2.0, HERO_POS.y - _hero.size.y)
	_hero.position = _hero_base_pos
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero)

	# 漂浮文字层
	_float_layer = Control.new()
	_float_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_float_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_float_layer)

	# 回合提示
	_turn_label = Label.new()
	_turn_label.add_theme_font_size_override("font_size", 22)
	_turn_label.add_theme_color_override("font_color", UITheme.C_GOLD)
	_turn_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	_turn_label.add_theme_constant_override("outline_size", 6)
	_turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_label.position = Vector2(0, 70)
	_turn_label.size = Vector2(1280, 32)
	_turn_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_turn_label)

	# 行动栏
	var bar = HBoxContainer.new()
	bar.position = Vector2(36, 596)
	bar.size = Vector2(560, 56)
	bar.add_theme_constant_override("separation", 10)
	add_child(bar)
	_btn_attack = _mk_action(bar, "攻击 [1]", func(): _act("attack"))
	_btn_skill = _mk_action(bar, "盾击 [2]", func(): _act("skill"))
	_btn_defend = _mk_action(bar, "防御 [3]", func(): _act("defend"))
	_btn_potion = _mk_action(bar, "药水 [4]", func(): _act("potion"))

	var hint = Label.new()
	hint.text = "点击敌人选择目标 · 数字键快捷操作"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	hint.position = Vector2(38, 656)
	hint.size = Vector2(560, 20)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

	# 战斗日志
	var log_panel = PanelContainer.new()
	log_panel.position = Vector2(640, 580)
	log_panel.size = Vector2(604, 124)
	add_child(log_panel)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.custom_minimum_size = Vector2(580, 100)
	log_panel.add_child(_log)

	# 信号
	SignalBus.combat_started.connect(_on_combat_started)
	SignalBus.combat_log_message.connect(_on_log)
	SignalBus.player_attacked.connect(_on_player_attacked)
	SignalBus.enemy_acted.connect(_on_enemy_acted)
	SignalBus.damage_taken.connect(_on_damage_taken)
	SignalBus.enemy_hp_changed.connect(_on_enemy_hp_changed)
	SignalBus.enemy_shield_changed.connect(_on_enemy_shield_changed)
	SignalBus.enemy_defeated.connect(_on_enemy_defeated)
	SignalBus.skill_cooldown_changed.connect(func(_t): _update_buttons())
	SignalBus.player_turn_started.connect(_on_player_turn)
	SignalBus.enemy_turn_started.connect(_on_enemy_turn)
	SignalBus.potion_changed.connect(func(_n): _update_buttons())

func _mk_action(parent: Control, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(126, 52)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ------------------------------------------------------------
# 战斗建立 / 敌人槽位
# ------------------------------------------------------------
func _on_combat_started(enemies: Array) -> void:
	rebuild_enemies(enemies)
	_update_buttons()

func rebuild_enemies(enemies: Array) -> void:
	for s in _enemy_slots:
		s.root.queue_free()
	_enemy_slots.clear()
	_selected = -1

	var n = enemies.size()
	for i in range(n):
		_enemy_slots.append(_make_enemy_slot(enemies[i], i, n))
	_refresh_target_rings()
	_refresh_all_bars()

func _enemy_x(i: int, n: int) -> float:
	match n:
		1: return 920.0
		2: return [790.0, 1060.0][i]
		_: return [720.0, 930.0, 1130.0][mini(i, 2)]

func _make_enemy_slot(e: Dictionary, i: int, n: int) -> Dictionary:
	var tex: Texture2D = null
	if e.is_boss:
		tex = load("res://assets/sprites/enemies/bosses/boss%d.png" % GameState.region)
	else:
		tex = load("res://assets/sprites/enemies/%s.png" % e.get("sprite_key", "slime"))
	if tex == null:
		tex = load("res://assets/sprites/enemies/slime.png")

	var frame_h = tex.get_height() / 2.0
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, tex.get_width(), frame_h)

	var sc: float = e.get("scale", 4.4)
	var w = tex.get_width() * sc
	var h = frame_h * sc
	var cx = _enemy_x(i, n)

	var root = Control.new()
	root.position = Vector2(cx - w / 2.0 - 12.0, GROUND_Y - h - 56.0)
	root.size = Vector2(w + 24.0, h + 56.0)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select_target(i)
	)
	add_child(root)

	# 目标指示环
	var ring = Panel.new()
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	var ring_style = StyleBoxFlat.new()
	ring_style.bg_color = Color(0, 0, 0, 0)
	ring_style.border_color = UITheme.C_GOLD
	ring_style.set_border_width_all(2)
	ring_style.set_corner_radius_all(6)
	ring.add_theme_stylebox_override("panel", ring_style)
	ring.visible = false
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ring)

	# 精灵
	var sprite = TextureRect.new()
	sprite.texture = atlas
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.stretch_mode = TextureRect.STRETCH_SCALE
	sprite.size = Vector2(w, h)
	sprite.position = Vector2(12.0, 0)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(sprite)

	# 名称
	var name_lbl = Label.new()
	name_lbl.text = e.name
	if e.is_boss:
		name_lbl.add_theme_color_override("font_color", UITheme.C_GOLD)
	elif e.is_elite:
		name_lbl.add_theme_color_override("font_color", Color("#bd6fff"))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	name_lbl.add_theme_constant_override("outline_size", 4)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, h + 4.0)
	name_lbl.size = Vector2(w + 24.0, 20)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_lbl)

	# 血条
	var hp_bg = Panel.new()
	hp_bg.add_theme_stylebox_override("panel", UITheme.bar_style(UITheme.C_HP_BG))
	hp_bg.position = Vector2(12.0, h + 28.0)
	hp_bg.size = Vector2(w, 10)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_bg)
	var hp_bar = Panel.new()
	hp_bar.add_theme_stylebox_override("panel", UITheme.bar_style(UITheme.C_HP))
	hp_bar.position = Vector2(12.0, h + 28.0)
	hp_bar.size = Vector2(w, 10)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_bar)

	# 护盾标签
	var shield_lbl = Label.new()
	shield_lbl.add_theme_font_size_override("font_size", 13)
	shield_lbl.add_theme_color_override("font_color", UITheme.C_SHIELD)
	shield_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	shield_lbl.add_theme_constant_override("outline_size", 4)
	shield_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shield_lbl.position = Vector2(0, h + 40.0)
	shield_lbl.size = Vector2(w + 24.0, 16)
	shield_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shield_lbl)

	return {
		"root": root, "sprite": sprite, "atlas": atlas, "frame_h": frame_h,
		"hp_bar": hp_bar, "bar_w": w, "shield_lbl": shield_lbl,
		"base_pos": root.position, "ring": ring, "dead": false,
	}

func _select_target(i: int) -> void:
	var enemies = _enemies()
	if i < 0 or i >= enemies.size() or enemies[i].hp <= 0:
		return
	_selected = i
	Sfx.play("click")
	_refresh_target_rings()

func _refresh_target_rings() -> void:
	for i in range(_enemy_slots.size()):
		_enemy_slots[i].ring.visible = (i == _selected)

func _enemies() -> Array:
	return GameState.combat_state.get("enemies", [])

# ------------------------------------------------------------
# 玩家操作
# ------------------------------------------------------------
func _act(kind: String) -> void:
	if combat_node == null or not is_instance_valid(combat_node):
		return
	if not combat_node.can_player_act():
		return
	match kind:
		"attack":
			_hero_attack_anim()
			combat_node.player_attack(_selected)
		"skill":
			if GameState.combat_state.get("skill_cooldown", 0) > 0:
				return
			_hero_attack_anim()
			combat_node.player_skill(_selected)
		"defend":
			combat_node.player_defend()
		"potion":
			combat_node.player_potion()
	_update_buttons()

func handle_key(idx: int) -> void:
	match idx:
		1: _act("attack")
		2: _act("skill")
		3: _act("defend")
		4: _act("potion")

func _update_buttons() -> void:
	var can = combat_node != null and is_instance_valid(combat_node) and combat_node.can_player_act()
	var cd = GameState.combat_state.get("skill_cooldown", 0)
	_btn_attack.disabled = not can
	_btn_skill.disabled = not can or cd > 0
	_btn_skill.text = "盾击 [2]" if cd <= 0 else "盾击 (%d)" % cd
	_btn_defend.disabled = not can
	_btn_potion.disabled = not can or GameState.potions <= 0
	_btn_potion.text = "药水 [4] ×%d" % GameState.potions

func _on_player_turn() -> void:
	_turn_label.text = "—— 你的回合 ——"
	_update_buttons()
	_refresh_all_bars()

func _on_enemy_turn() -> void:
	_turn_label.text = "敌方行动中……"
	_update_buttons()

# ------------------------------------------------------------
# 动画与反馈
# ------------------------------------------------------------
func _hero_attack_anim() -> void:
	_set_hero_frame(2)
	var tw = create_tween()
	tw.tween_property(_hero, "position:x", _hero_base_pos.x + 70.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hero, "position:x", _hero_base_pos.x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _set_hero_frame(0))

func _set_hero_frame(f: int) -> void:
	_hero_atlas.region = Rect2(0, f * _hero_frame_h, _hero_atlas.atlas.get_width(), _hero_frame_h)

func _on_player_attacked(target: int, damage: int, is_crit: bool) -> void:
	if target < 0 or target >= _enemy_slots.size():
		return
	var slot = _enemy_slots[target]
	# 受击白闪
	var tw = create_tween()
	slot.sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	tw.tween_property(slot.sprite, "modulate", Color.WHITE, 0.22)
	# 漂浮数字
	var pos = slot.root.position + Vector2(slot.root.size.x / 2.0, 10.0)
	_spawn_float("%d" % damage, pos, Color("#ffd95e") if is_crit else Color.WHITE, 30 if is_crit else 22)
	_refresh_all_bars()

func _on_enemy_acted(enemy_index: int, _action: String) -> void:
	if enemy_index < 0 or enemy_index >= _enemy_slots.size():
		return
	var slot = _enemy_slots[enemy_index]
	if slot.dead:
		return
	var tw = create_tween()
	tw.tween_property(slot.root, "position:x", slot.base_pos.x - 56.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(slot.root, "position:x", slot.base_pos.x, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _on_damage_taken(target: String, amount: int) -> void:
	if target != "player":
		return
	_set_hero_frame(3)
	var tw = create_tween()
	_hero.modulate = Color(2.5, 1.0, 1.0, 1.0)
	tw.tween_property(_hero, "modulate", Color.WHITE, 0.25)
	tw.tween_callback(func(): _set_hero_frame(0))
	_spawn_float("-%d" % amount, _hero_base_pos + Vector2(_hero.size.x / 2.0, -8.0), Color("#ff7a6a"), 24)

func _spawn_float(text: String, pos: Vector2, col: Color, fsize: int) -> void:
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.position = pos + Vector2(randf_range(-22, 22), 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(lbl)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", lbl.position.y - 64.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(lbl.queue_free)

func _on_enemy_hp_changed(enemy_index: int, _cur: int, _max: int) -> void:
	if enemy_index < 0:
		_refresh_all_bars()
	elif enemy_index < _enemy_slots.size():
		_refresh_bar(enemy_index)

func _on_enemy_shield_changed(_idx: int, _amount: int) -> void:
	_refresh_all_bars()

func _refresh_all_bars() -> void:
	for i in range(_enemy_slots.size()):
		_refresh_bar(i)

func _refresh_bar(i: int) -> void:
	var enemies = _enemies()
	if i >= enemies.size() or i >= _enemy_slots.size():
		return
	var e = enemies[i]
	var slot = _enemy_slots[i]
	var pct = clampf(float(e.hp) / float(e.maxhp), 0.0, 1.0)
	slot.hp_bar.size.x = slot.bar_w * pct
	slot.shield_lbl.text = ("◈ 护盾 %d" % e.shield) if e.shield > 0 else ""
	if e.hp <= 0 and not slot.dead:
		_mark_dead(i)

func _on_enemy_defeated(enemy_index: int) -> void:
	if enemy_index >= 0 and enemy_index < _enemy_slots.size():
		_mark_dead(enemy_index)

func _mark_dead(i: int) -> void:
	var slot = _enemy_slots[i]
	if slot.dead:
		return
	slot.dead = true
	var tw = create_tween()
	tw.tween_property(slot.root, "modulate:a", 0.0, 0.5)
	if _selected == i:
		_selected = -1
		_refresh_target_rings()

# ------------------------------------------------------------
# 日志
# ------------------------------------------------------------
func _on_log(text: String, message_type: String) -> void:
	var col = LOG_COLORS.get(message_type, "#e8ecf4")
	_log.append_text("[color=%s]%s[/color]\n" % [col, text])

func clear_log() -> void:
	_log.clear()

# ------------------------------------------------------------
# 待机动画
# ------------------------------------------------------------
func _process(delta: float) -> void:
	if not visible:
		return
	_anim_t += delta
	if _anim_t >= 0.45:
		_anim_t = 0.0
		_frame_flip = not _frame_flip
		# 英雄待机帧（仅在非攻击/受伤状态切换 idle0/idle1）
		var cur_y = _hero_atlas.region.position.y
		if cur_y < _hero_frame_h * 2.0 - 0.5:
			_set_hero_frame(1 if _frame_flip else 0)
		# 敌人 2 帧切换
		for slot in _enemy_slots:
			if slot.dead:
				continue
			var f = 1 if _frame_flip else 0
			slot.atlas.region = Rect2(0, f * slot.frame_h, slot.atlas.atlas.get_width(), slot.frame_h)
