class_name CombatView
extends Control

# ============================================================
# 战斗视图
# - 英雄整体外观由 PixelArt 按装备实时合成（武器在手、护甲改变体型配色）
# - 怪物精灵运行时程序化生成（高细节 2 帧）；词条/元素/状态标签
# - 行动按钮带冷却显示：盾击3 / 防御2 / 药水3 / 斧攻击1
# - 武器差异化攻击动画：剑突进斩击 / 斧重劈回旋 / 弓双发箭矢
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
var _hero_frame_h: float = 26.0
var _hero_base_pos: Vector2
var _armor_glow: ColorRect

var _enemy_slots: Array = []   # [{root, sprite, atlas, hp_bar, hp_lbl, shield_lbl, name_lbl, tag_lbl, status_lbl, frame_h, base_pos, ring}]
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
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 护甲光环（脚底辉光，颜色 = 护甲稀有度）
	_armor_glow = ColorRect.new()
	_armor_glow.size = Vector2(96, 10)
	_armor_glow.position = Vector2(HERO_POS.x - 48, GROUND_Y - 4)
	_armor_glow.color = Color(1, 1, 1, 0.0)
	_armor_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_armor_glow)

	# 英雄（程序化合成，随装备变化）
	_hero_atlas = AtlasTexture.new()
	_hero = TextureRect.new()
	_hero.texture = _hero_atlas
	_hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hero.stretch_mode = TextureRect.STRETCH_SCALE
	_hero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hero)

	# 漂浮文字层
	_float_layer = Control.new()
	_float_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	_btn_potion.tooltip_text = GameData.POTION_INFO.desc
	_btn_defend.tooltip_text = "获得护盾（冷却 2 回合）；蓄势词条防御时叠层"
	_btn_skill.tooltip_text = "盾击：造成 ×1.35 伤害并获得护盾（默认后手——敌人先动；剑/疾盾词条/盾击大师可先手）"

	var hint = Label.new()
	hint.text = "点击敌人选择目标 · 数字键快捷操作 · B 背包 · V 属性 · C 图鉴"
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
	SignalBus.cooldowns_changed.connect(_update_buttons)
	SignalBus.player_turn_started.connect(_on_player_turn)
	SignalBus.enemy_turn_started.connect(_on_enemy_turn)
	SignalBus.potion_changed.connect(func(_n): _update_buttons())
	SignalBus.equipment_changed.connect(func(_s, _i):
		_refresh_hero_gear()
		_update_buttons()
	)
	SignalBus.elem_proc_triggered.connect(_on_elem_proc)
	SignalBus.bow_combo_changed.connect(func(_c): _update_buttons())

	_refresh_hero_gear()

func _mk_action(parent: Control, text: String, cb: Callable) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(126, 52)
	b.add_theme_font_size_override("font_size", 18)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b

# ------------------------------------------------------------
# 英雄装备外观：整体合成精灵 + 护甲稀有度光环
# ------------------------------------------------------------
func _refresh_hero_gear() -> void:
	var tex = PixelArt.hero_texture(GameState.equipment)
	_hero_atlas.atlas = tex
	_hero_frame_h = tex.get_height() / 4.0
	_set_hero_frame(0)
	var hero_scale := 4.0
	_hero.size = Vector2(tex.get_width() * hero_scale, _hero_frame_h * hero_scale)
	_hero_base_pos = Vector2(HERO_POS.x - _hero.size.x / 2.0, HERO_POS.y - _hero.size.y)
	_hero.position = _hero_base_pos
	_hero.pivot_offset = Vector2(_hero.size.x / 2.0, _hero.size.y)

	var armor = GameState.equipment.get("armor")
	if armor:
		var rc = UITheme.rarity_color(armor.rarity)
		_armor_glow.color = Color(rc.r, rc.g, rc.b, 0.28 + 0.08 * armor.rarity)
	else:
		_armor_glow.color = Color(1, 1, 1, 0.0)

# ------------------------------------------------------------
# 战斗建立 / 敌人槽位
# ------------------------------------------------------------
func _on_combat_started(enemies: Array) -> void:
	rebuild_enemies(enemies)
	_update_buttons()
	_refresh_hero_gear()

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
	var tex: Texture2D
	if e.get("cycle_boss", false):
		tex = PixelArt.cycle_boss_texture(e.get("cycle_sprite", "voidbeast"), e.palette)
	elif e.is_boss:
		tex = PixelArt.boss_texture(GameState.region, e.palette)
	else:
		tex = PixelArt.enemy_texture(e.get("sprite_key", "slime"), e.palette)

	var frame_h = tex.get_height() / 2.0
	var atlas = AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(0, 0, tex.get_width(), frame_h)

	var sc: float = e.get("scale", 4.4)
	var w = tex.get_width() * sc
	var h = frame_h * sc
	var cx = _enemy_x(i, n)

	var root = Control.new()
	root.position = Vector2(cx - w / 2.0 - 12.0, GROUND_Y - h - 78.0)
	root.size = Vector2(w + 24.0, h + 78.0)
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_select_target(i)
	)
	add_child(root)

	# 目标指示环
	var ring = Panel.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	sprite.pivot_offset = Vector2(w / 2.0, h)
	sprite.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if e.is_elite:
		sprite.modulate = Color(1.12, 1.04, 0.9, 1.0)
	root.add_child(sprite)

	# 像素粒子光环：仅精英 / 区域首领 / 周目大 Boss 拥有（普通杂兵无粒子）
	if e.get("cycle_boss", false) or e.is_boss or e.is_elite:
		_add_enemy_particles(root, e, w, h)

	# 名称（含元素标记）
	var name_lbl = Label.new()
	var elem = str(e.get("element", ""))
	var ename = e.name
	if elem != "":
		ename = "〔%s〕%s" % [GameData.element_name(elem), e.name]
	name_lbl.text = ename
	if e.is_boss:
		name_lbl.add_theme_color_override("font_color", UITheme.C_GOLD)
	elif e.is_elite:
		name_lbl.add_theme_color_override("font_color", Color("#bd6fff"))
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	name_lbl.add_theme_constant_override("outline_size", 4)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.position = Vector2(0, h + 2.0)
	name_lbl.size = Vector2(w + 24.0, 20)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(name_lbl)

	# 词条 + 战斗风格标签
	var tag_lbl = Label.new()
	var afx: Array = e.get("affixes", [])
	var tag_parts = []
	var st_info = GameData.ENEMY_STYLES.get(str(e.get("style", "normal")), {})
	if str(st_info.get("name", "")) != "":
		tag_parts.append("〈%s〉" % st_info.name)
	if afx.size() > 0:
		tag_parts.append(GameData.monster_affix_names(afx))
	tag_lbl.text = "".join(tag_parts)
	tag_lbl.add_theme_font_size_override("font_size", 12)
	tag_lbl.add_theme_color_override("font_color", Color("#e8a8ff"))
	tag_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	tag_lbl.add_theme_constant_override("outline_size", 3)
	tag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag_lbl.position = Vector2(0, h + 19.0)
	tag_lbl.size = Vector2(w + 24.0, 16)
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tips = []
	if str(st_info.get("name", "")) != "":
		tips.append("%s：%s" % [st_info.name, st_info.get("desc", "")])
	for a in afx:
		var ad = GameData.get_monster_affix(a)
		tips.append("%s：%s" % [ad.name, ad.desc])
	tag_lbl.tooltip_text = "\n".join(tips)
	root.add_child(tag_lbl)

	# 血条
	var bar_y = h + 37.0
	var hp_bg = Panel.new()
	hp_bg.add_theme_stylebox_override("panel", UITheme.bar_style(UITheme.C_HP_BG))
	hp_bg.position = Vector2(12.0, bar_y)
	hp_bg.size = Vector2(w, 14)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_bg)
	var hp_bar = Panel.new()
	hp_bar.add_theme_stylebox_override("panel", UITheme.bar_style(UITheme.C_HP))
	hp_bar.position = Vector2(12.0, bar_y)
	hp_bar.size = Vector2(w, 14)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_bar)

	# 血量精确数值（覆盖在血条上）
	var hp_lbl = Label.new()
	hp_lbl.add_theme_font_size_override("font_size", 12)
	hp_lbl.add_theme_color_override("font_color", Color.WHITE)
	hp_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hp_lbl.add_theme_constant_override("outline_size", 4)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hp_lbl.position = Vector2(12.0, bar_y - 2.0)
	hp_lbl.size = Vector2(w, 18)
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_lbl)

	# 护盾 + 状态标签
	var shield_lbl = Label.new()
	shield_lbl.add_theme_font_size_override("font_size", 13)
	shield_lbl.add_theme_color_override("font_color", UITheme.C_SHIELD)
	shield_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	shield_lbl.add_theme_constant_override("outline_size", 4)
	shield_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shield_lbl.position = Vector2(0, bar_y + 16.0)
	shield_lbl.size = Vector2(w + 24.0, 16)
	shield_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(shield_lbl)

	var status_lbl = Label.new()
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color("#ffb44a"))
	status_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	status_lbl.add_theme_constant_override("outline_size", 3)
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_lbl.position = Vector2(0, bar_y + 32.0)
	status_lbl.size = Vector2(w + 24.0, 16)
	status_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(status_lbl)

	return {
		"root": root, "sprite": sprite, "atlas": atlas, "frame_h": frame_h,
		"hp_bar": hp_bar, "hp_lbl": hp_lbl, "bar_w": w, "shield_lbl": shield_lbl,
		"status_lbl": status_lbl,
		"base_pos": root.position, "ring": ring, "dead": false,
	}

## 小方块像素贴图（粒子用），按颜色缓存
static var _pix_cache: Dictionary = {}
func _pixel_square(col: Color) -> ImageTexture:
	var key = col.to_html()
	if _pix_cache.has(key):
		return _pix_cache[key]
	var img = Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(col)
	var t = ImageTexture.create_from_image(img)
	_pix_cache[key] = t
	return t

## 为敌人添加上升的像素粒子光环；周目大 Boss 更密集并带主题色
func _add_enemy_particles(root: Control, e: Dictionary, w: float, h: float) -> void:
	var is_cb: bool = e.get("cycle_boss", false)
	var pal: Dictionary = e.get("palette", {})
	var col := Color("#cfd6e4")
	if is_cb:
		col = {
			"orochi": Color("#7be08a"), "kitsune": Color("#ffd36a"),
			"colossus": Color("#d8c8a4"), "voidbeast": Color("#c08aff"),
		}.get(str(e.get("cycle_sprite", "voidbeast")), Color("#c08aff"))
	else:
		col = Color(str(pal.get("e", "#cfd6e4")))
	# 主体上升粒子
	var ps = CPUParticles2D.new()
	ps.texture = _pixel_square(col)
	ps.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ps.amount = 30 if is_cb else (14 if e.is_boss else 7)
	ps.lifetime = 1.9 if is_cb else 1.5
	ps.preprocess = ps.lifetime
	ps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ps.emission_rect_extents = Vector2(w * 0.34, h * 0.42)
	ps.direction = Vector2(0, -1)
	ps.spread = 28.0
	ps.gravity = Vector2(0, -26.0)
	ps.initial_velocity_min = 10.0
	ps.initial_velocity_max = 30.0 if is_cb else 20.0
	ps.scale_amount_min = 2.0
	ps.scale_amount_max = 5.0 if is_cb else 3.5
	var grad = Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.0))
	grad.add_point(0.25, Color(col.r, col.g, col.b, 0.9 if is_cb else 0.6))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	ps.color_ramp = grad
	ps.position = Vector2(12.0 + w / 2.0, h * 0.55)
	root.add_child(ps)
	root.move_child(ps, 1)   # 置于精灵之后（光环在身后）
	# 周目大 Boss 额外环绕火花（位于身前，营造威压感）
	if is_cb:
		var sp = CPUParticles2D.new()
		sp.texture = _pixel_square(Color(col.r, col.g, col.b).lerp(Color.WHITE, 0.4))
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sp.amount = 16
		sp.lifetime = 1.3
		sp.preprocess = 1.3
		sp.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
		sp.emission_sphere_radius = maxf(w, h) * 0.46
		sp.gravity = Vector2.ZERO
		sp.orbit_velocity_min = 0.12
		sp.orbit_velocity_max = 0.22
		sp.initial_velocity_min = 0.0
		sp.initial_velocity_max = 4.0
		sp.scale_amount_min = 2.0
		sp.scale_amount_max = 4.0
		var g2 = Gradient.new()
		g2.set_color(0, Color(1, 1, 1, 0.0))
		g2.add_point(0.3, Color(col.r, col.g, col.b, 0.95))
		g2.set_color(1, Color(col.r, col.g, col.b, 0.0))
		sp.color_ramp = g2
		sp.position = Vector2(12.0 + w / 2.0, h * 0.5)
		root.add_child(sp)

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

## 当前攻击目标的画面中心位置（用于投射物/特效）
func _target_pos(idx: int = -1) -> Vector2:
	if idx < 0:
		idx = _selected
	var enemies = _enemies()
	if idx < 0 or idx >= enemies.size() or enemies[idx].hp <= 0:
		idx = -1
		for i in range(enemies.size()):
			if enemies[i].hp > 0:
				idx = i
				break
	if idx < 0 or idx >= _enemy_slots.size():
		return Vector2(920, 440)
	var slot = _enemy_slots[idx]
	return slot.root.position + slot.root.size / 2.0

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
			if combat_node.get_cooldown("attack") > 0:
				return
			_play_attack_anim()
			combat_node.player_attack(_selected)
		"skill":
			if GameState.combat_state.get("skill_cooldown", 0) > 0:
				return
			_hero_lunge_anim(2)
			combat_node.player_skill(_selected)
		"defend":
			if combat_node.get_cooldown("defend") > 0:
				return
			_hero_defend_anim()
			combat_node.player_defend()
		"potion":
			if combat_node.get_cooldown("potion") > 0:
				return
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
	var cds: Dictionary = GameState.combat_state.get("cooldowns", {})
	var atk_cd = int(cds.get("attack", 0))
	var def_cd = int(cds.get("defend", 0))
	var pot_cd = int(cds.get("potion", 0))
	var weapon = GameState.equipment.get("weapon")
	var wkey = weapon.get("key", "sword") if weapon else "sword"
	var atk_names = { "sword": "挥剑", "bow": "连射", "axe": "劈砍" }
	var aname: String = atk_names.get(wkey, "攻击")
	if wkey == "bow":
		var stats_b = GameState.get_player_stats()
		var bonus_b = mini(int(GameData.COMBAT["multihit_cap"]),
			int(GameState.combat_state.get("bow_combo", 0)) + int(stats_b.get("multihit", 0)))
		var arrows = mini(int(GameData.COMBAT["max_attacks_per_action"]), int(GameData.COMBAT["bow_hits"]) + bonus_b)
		aname = "连射×%d" % arrows
	_btn_attack.text = ("%s [1]" % aname) if atk_cd <= 0 else ("%s 冷却(%d)" % [aname, atk_cd])
	_btn_attack.disabled = not can or atk_cd > 0
	_btn_skill.disabled = not can or cd > 0
	_btn_skill.text = "盾击 [2]" if cd <= 0 else "盾击 (%d)" % cd
	var focus = int(GameState.combat_state.get("focus", 0))
	_btn_defend.text = ("防御 [3]" + (" ◆%d" % focus if focus > 0 else "")) if def_cd <= 0 else ("防御 (%d)" % def_cd)
	_btn_defend.disabled = not can or def_cd > 0
	_btn_potion.disabled = not can or GameState.potions <= 0 or pot_cd > 0
	_btn_potion.text = ("药水 [4] ×%d" % GameState.potions) if pot_cd <= 0 else ("药水 (%d)" % pot_cd)

func _on_player_turn() -> void:
	_turn_label.text = "—— 你的回合 ——"
	_update_buttons()
	_refresh_all_bars()

func _on_enemy_turn() -> void:
	_turn_label.text = "敌方行动中……"
	_update_buttons()

# ------------------------------------------------------------
# 攻击动画（按武器类型差异化）
# ------------------------------------------------------------
func _play_attack_anim() -> void:
	var weapon = GameState.equipment.get("weapon")
	var key = weapon.get("key", "sword") if weapon else "sword"
	match key:
		"bow":
			_hero_bow_anim()
		"axe":
			_hero_axe_anim()
		_:
			_hero_sword_anim()

## 剑：突进 + 斩击弧光
func _hero_sword_anim() -> void:
	_set_hero_frame(2)
	var tw = create_tween()
	tw.tween_property(_hero, "position:x", _hero_base_pos.x + 70.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _spawn_slash(_target_pos(), Color(1, 1, 1, 0.9)))
	tw.tween_property(_hero, "position:x", _hero_base_pos.x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _set_hero_frame(0))

## 斧：大幅突进 + 整体回旋 + 重斩
func _hero_axe_anim() -> void:
	_set_hero_frame(2)
	var tw = create_tween()
	tw.tween_property(_hero, "position:x", _hero_base_pos.x + 90.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_hero, "rotation_degrees", 18.0, 0.14)
	tw.tween_callback(func():
		_spawn_slash(_target_pos(), Color("#ffb44a"))
		_spawn_sparks(_target_pos(), Color("#ffb44a"), 10)
	)
	tw.tween_property(_hero, "position:x", _hero_base_pos.x, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_hero, "rotation_degrees", 0.0, 0.2)
	tw.tween_callback(func(): _set_hero_frame(0))

## 弓：后撤蓄力 + 连发两箭
func _hero_bow_anim() -> void:
	_set_hero_frame(2)
	var from = _hero_base_pos + Vector2(_hero.size.x * 0.85, _hero.size.y * 0.35)
	var to = _target_pos()
	var tw = create_tween()
	tw.tween_property(_hero, "position:x", _hero_base_pos.x - 26.0, 0.10).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func(): _spawn_arrow(from, to))
	tw.tween_interval(0.12)
	tw.tween_callback(func(): _spawn_arrow(from + Vector2(0, 6), to + Vector2(8, 4)))
	tw.tween_property(_hero, "position:x", _hero_base_pos.x, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _set_hero_frame(0))

## 盾击/技能通用突进
func _hero_lunge_anim(frame: int) -> void:
	_set_hero_frame(frame)
	var tw = create_tween()
	tw.tween_property(_hero, "position:x", _hero_base_pos.x + 70.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hero, "position:x", _hero_base_pos.x, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): _set_hero_frame(0))

## 防御：短暂下蹲 + 蓝光
func _hero_defend_anim() -> void:
	var tw = create_tween()
	_hero.modulate = Color(0.7, 0.85, 1.6, 1.0)
	tw.tween_property(_hero, "position:y", _hero_base_pos.y + 6.0, 0.1)
	tw.tween_property(_hero, "position:y", _hero_base_pos.y, 0.14)
	tw.parallel().tween_property(_hero, "modulate", Color.WHITE, 0.3)

func _set_hero_frame(f: int) -> void:
	if _hero_atlas.atlas == null:
		return
	_hero_atlas.region = Rect2(0, f * _hero_frame_h, _hero_atlas.atlas.get_width(), _hero_frame_h)

# ------------------------------------------------------------
# 特效：箭矢 / 斩击弧光 / 命中火花
# ------------------------------------------------------------
func _spawn_arrow(from: Vector2, to: Vector2) -> void:
	var arrow = ColorRect.new()
	arrow.color = Color("#e8d9a0")
	arrow.size = Vector2(26, 3)
	arrow.position = from
	arrow.rotation = (to - from).angle()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(arrow)
	var tw = create_tween()
	tw.tween_property(arrow, "position", to, 0.16).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(func():
		_spawn_sparks(to, Color("#ffe9a0"))
		arrow.queue_free()
	)

func _spawn_slash(pos: Vector2, col: Color) -> void:
	var slash = ColorRect.new()
	slash.color = col
	slash.size = Vector2(64, 5)
	slash.position = pos - Vector2(32, 2)
	slash.rotation_degrees = -36.0
	slash.pivot_offset = Vector2(32, 2)
	slash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(slash)
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(slash, "rotation_degrees", 36.0, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(slash, "modulate:a", 0.0, 0.2)
	tw.chain().tween_callback(slash.queue_free)

func _spawn_sparks(pos: Vector2, col: Color, count: int = 7) -> void:
	for i in range(count):
		var p = ColorRect.new()
		p.color = col
		var s = randf_range(3.0, 6.0)
		p.size = Vector2(s, s)
		p.position = pos
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_float_layer.add_child(p)
		var dir = Vector2.from_angle(randf() * TAU) * randf_range(26.0, 64.0)
		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(p, "position", pos + dir, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 0.0, 0.32)
		tw.chain().tween_callback(p.queue_free)

# ------------------------------------------------------------
# 受击反馈
# ------------------------------------------------------------
func _on_player_attacked(target: int, damage: int, is_crit: bool) -> void:
	if target < 0 or target >= _enemy_slots.size():
		return
	var slot = _enemy_slots[target]
	var pos = slot.root.position + Vector2(slot.root.size.x / 2.0, 10.0)
	if damage <= 0:
		# 虚体闪避
		_spawn_float("闪避", pos, Color("#b59cf4"), 20)
		return
	# 受击白闪 + 后仰
	var tw = create_tween()
	slot.sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	tw.set_parallel(true)
	tw.tween_property(slot.sprite, "modulate", Color.WHITE, 0.22)
	tw.tween_property(slot.root, "position:x", slot.base_pos.x + 14.0, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(slot.root, "position:x", slot.base_pos.x, 0.12)
	# 漂浮数字 + 火花
	_spawn_float("%d" % damage, pos, Color("#ffd95e") if is_crit else Color.WHITE, 30 if is_crit else 22)
	_spawn_sparks(slot.root.position + slot.root.size / 2.0, Color("#ffd95e") if is_crit else Color(1, 1, 1, 0.8), 9 if is_crit else 5)
	if is_crit:
		SignalBus.shake_screen.emit(4.0, 0.14)
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
	# 周目大 Boss 攻击：发射一颗能量粒子球飞向主角，命中后爆散
	var enemies = _enemies()
	if enemy_index < enemies.size() and enemies[enemy_index].get("cycle_boss", false):
		var from = slot.root.position + slot.root.size / 2.0
		var to = _hero_base_pos + _hero.size / 2.0
		var col = {
			"orochi": Color("#7be08a"), "kitsune": Color("#ffd36a"),
			"colossus": Color("#d8c8a4"), "voidbeast": Color("#c08aff"),
		}.get(str(enemies[enemy_index].get("cycle_sprite", "voidbeast")), Color("#c08aff"))
		_spawn_boss_orb(from, to, col)

## 周目 Boss 能量弹：飞行时拖尾、命中爆散；全程一次性自释放，杜绝粒子堆积
func _spawn_boss_orb(from: Vector2, to: Vector2, col: Color) -> void:
	# 飞行拖尾（local_coords=false 让粒子留在世界形成尾迹）
	var orb = CPUParticles2D.new()
	orb.texture = _pixel_square(col.lerp(Color.WHITE, 0.35))
	orb.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	orb.local_coords = false
	orb.amount = 26
	orb.lifetime = 0.42
	orb.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	orb.emission_sphere_radius = 7.0
	orb.spread = 180.0
	orb.gravity = Vector2.ZERO
	orb.initial_velocity_min = 4.0
	orb.initial_velocity_max = 16.0
	orb.scale_amount_min = 2.0
	orb.scale_amount_max = 6.0
	var grad = Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.95))
	grad.add_point(0.4, Color(col.r, col.g, col.b, 0.7))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	orb.color_ramp = grad
	orb.position = from
	_float_layer.add_child(orb)
	# 实心核（亮球），随弹飞行
	var core = TextureRect.new()
	core.texture = _pixel_square(col.lerp(Color.WHITE, 0.55))
	core.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	core.stretch_mode = TextureRect.STRETCH_SCALE
	core.size = Vector2(14, 14)
	core.pivot_offset = Vector2(7, 7)
	core.position = from - Vector2(7, 7)
	core.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_float_layer.add_child(core)
	var dur = 0.34
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(orb, "position", to, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(core, "position", to - Vector2(7, 7), dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		orb.emitting = false                    # 停止发射，残留粒子在 lifetime 内淡出
		core.queue_free()
		_spawn_orb_burst(to, col)               # 命中爆散
		var t = get_tree().create_timer(orb.lifetime + 0.1)
		t.timeout.connect(orb.queue_free)       # 一次性定时清理，无堆积
	)

## 命中爆散：一次性（one_shot）粒子炸开，按 lifetime 后自毁
func _spawn_orb_burst(pos: Vector2, col: Color) -> void:
	var b = CPUParticles2D.new()
	b.texture = _pixel_square(col)
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.one_shot = true
	b.explosiveness = 0.92
	b.amount = 22
	b.lifetime = 0.5
	b.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	b.emission_sphere_radius = 4.0
	b.spread = 180.0
	b.gravity = Vector2(0, 90.0)
	b.initial_velocity_min = 40.0
	b.initial_velocity_max = 110.0
	b.scale_amount_min = 2.0
	b.scale_amount_max = 5.0
	var g = Gradient.new()
	g.set_color(0, Color(col.r, col.g, col.b, 1.0))
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	b.color_ramp = g
	b.position = pos
	b.emitting = true
	_float_layer.add_child(b)
	var t = get_tree().create_timer(b.lifetime + 0.2)
	t.timeout.connect(b.queue_free)
	_spawn_sparks(pos, col.lerp(Color.WHITE, 0.3), 8)

## 元素触发：在目标头顶弹出触发名（让被动"看得见"）
func _on_elem_proc(target_idx: int, proc_name: String) -> void:
	var pos: Vector2
	if target_idx >= 0 and target_idx < _enemy_slots.size():
		var slot = _enemy_slots[target_idx]
		pos = slot.root.position + Vector2(slot.root.size.x / 2.0, -12.0)
	else:
		pos = Vector2(920, 380)
	_spawn_float("「%s」" % proc_name, pos, Color("#7fe8ff"), 22)

func _on_damage_taken(target: String, amount: int) -> void:
	if target != "player":
		return
	_set_hero_frame(3)
	var tw = create_tween()
	_hero.modulate = Color(2.5, 1.0, 1.0, 1.0)
	tw.tween_property(_hero, "modulate", Color.WHITE, 0.25)
	tw.tween_callback(func(): _set_hero_frame(0))
	_spawn_float("-%d" % amount, _hero_base_pos + Vector2(_hero.size.x / 2.0, -8.0), Color("#ff7a6a"), 24)
	_spawn_sparks(_hero_base_pos + _hero.size / 2.0, Color("#ff7a6a"), 5)

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

# ------------------------------------------------------------
# 血条 / 状态 / 阵亡
# ------------------------------------------------------------
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
	# 血条平滑过渡
	var target_w = slot.bar_w * pct
	if absf(slot.hp_bar.size.x - target_w) > 0.5:
		var tw = create_tween()
		tw.tween_property(slot.hp_bar, "size:x", target_w, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	slot.hp_lbl.text = "%d / %d" % [maxi(0, e.hp), e.maxhp]
	slot.shield_lbl.text = ("◈ 护盾 %d" % e.shield) if e.shield > 0 else ""
	# 状态标签
	var status = []
	if int(e.get("burn", 0)) > 0:
		status.append("灼烧(%d)" % e.burn)
	if int(e.get("stun", 0)) > 0:
		status.append("眩晕")
	if int(e.get("weaken", 0)) > 0:
		status.append("减攻(%d)" % e.weaken)
	if e.get("raged", false) or e.get("berserk_done", false):
		status.append("狂暴")
	slot.status_lbl.text = " · ".join(status)
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
	slot.hp_lbl.text = "0 / %d" % _enemies()[i].maxhp if i < _enemies().size() else ""
	slot.status_lbl.text = ""
	# 倒地：倾倒 + 下沉 + 淡出
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(slot.sprite, "rotation_degrees", 80.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(slot.root, "position:y", slot.base_pos.y + 16.0, 0.45)
	tw.tween_property(slot.root, "modulate:a", 0.0, 0.55)
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
	# 护甲光环呼吸
	var glow_a = _armor_glow.color.a
	if glow_a > 0.01:
		_armor_glow.color.a = glow_a + (0.30 + 0.10 * sin(_anim_t * 3.0) - glow_a) * 0.2
	if _anim_t >= 0.45:
		_anim_t = 0.0
		_frame_flip = not _frame_flip
		# 英雄待机帧（仅在非攻击/受伤状态切换 idle0/idle1）
		if _hero_atlas.atlas != null:
			var cur_y = _hero_atlas.region.position.y
			if cur_y < _hero_frame_h * 2.0 - 0.5:
				_set_hero_frame(1 if _frame_flip else 0)
		# 敌人 2 帧切换
		for slot in _enemy_slots:
			if slot.dead:
				continue
			var f = 1 if _frame_flip else 0
			slot.atlas.region = Rect2(0, f * slot.frame_h, slot.atlas.atlas.get_width(), slot.frame_h)
