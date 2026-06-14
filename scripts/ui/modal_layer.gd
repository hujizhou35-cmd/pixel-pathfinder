class_name ModalLayer
extends Control

# ============================================================
# 弹窗层 - 游戏所有对话框
# 栈式管理：背包/详情/图鉴/属性等可叠加在奖励/商店/事件之上，
# 关闭叠加窗口后自动恢复底层弹窗（修复"看背包丢战利品卡死"）
#
# shop / bag / treasure / event / reward / region_clear /
# victory / defeat / help / equip_detail / saves / codex /
# stats / region_select
# ============================================================

var _dim: ColorRect
var _panel: PanelContainer
var _current_type: String = ""
var _current_data: Dictionary = {}
var _dirty: bool = false
var _stack: Array = []   # [{type, data}] 被叠加暂存的底层弹窗

## 可以叠加到其它弹窗之上的"查看类"窗口
const OVERLAY_TYPES = ["bag", "equip_detail", "help", "codex", "stats", "smelt", "forge", "purge"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_dim)

	_panel = PanelContainer.new()
	add_child(_panel)

	SignalBus.show_modal.connect(open)
	SignalBus.hide_modal.connect(close)
	# 打开期间数据变化 → 重建
	SignalBus.bag_changed.connect(func(_b): _mark_dirty())
	SignalBus.equipment_changed.connect(func(_s, _i): _mark_dirty())
	SignalBus.gold_changed.connect(func(_g): _mark_dirty())
	SignalBus.potion_changed.connect(func(_p): _mark_dirty())

func _mark_dirty() -> void:
	if visible and _current_type in ["bag", "shop", "equip_detail", "stats", "saves"]:
		_dirty = true

func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_rebuild()

# ------------------------------------------------------------
# 开关（栈式）
# ------------------------------------------------------------
func open(modal_type: String, data: Dictionary) -> void:
	# 已有弹窗时：查看类窗口叠加压栈，其余直接替换
	if visible and _current_type != "" and _current_type != modal_type:
		if modal_type in OVERLAY_TYPES:
			_stack.append({ "type": _current_type, "data": _current_data })
		else:
			_stack.clear()
	elif not visible:
		_stack.clear()

	_current_type = modal_type
	_current_data = data
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_rebuild()
	# 弹入动画
	_panel.pivot_offset = _panel.size / 2.0
	_panel.scale = Vector2(0.85, 0.85)
	_panel.modulate.a = 0.0
	var tw = create_tween()
	tw.set_parallel(true)
	tw.tween_property(_panel, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_panel, "modulate:a", 1.0, 0.12)

## 关闭当前弹窗；若有被叠加的底层弹窗则恢复显示
func close() -> void:
	if _stack.size() > 0:
		var prev = _stack.pop_back()
		_current_type = prev.type
		_current_data = prev.data
		_rebuild()
		return
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_current_type = ""

## 无视堆栈，关闭全部弹窗（流程切换用）
func close_all() -> void:
	_stack.clear()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_current_type = ""

func is_open() -> bool:
	return visible

## ESC 行为：可安全关闭的弹窗才响应
func try_escape() -> void:
	if _current_type in OVERLAY_TYPES or _current_type in ["saves", "region_select", "node_preview"]:
		Sfx.play("click")
		close()
	elif _current_type == "shop":
		Sfx.play("click")
		close_all()
		GameState.back_to_map()

# ------------------------------------------------------------
# 构建
# ------------------------------------------------------------
func _rebuild() -> void:
	for c in _panel.get_children():
		_panel.remove_child(c)
		c.queue_free()
	var content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	_panel.add_child(content)

	match _current_type:
		"shop":          _build_shop(content)
		"bag":           _build_bag(content)
		"treasure":      _build_treasure(content)
		"event":         _build_event(content)
		"reward":        _build_reward(content)
		"region_clear":  _build_region_clear(content)
		"victory":       _build_victory(content)
		"defeat":        _build_defeat(content)
		"help":          _build_help(content)
		"equip_detail":  _build_equip_detail(content)
		"saves":         _build_saves(content)
		"codex":         _build_codex(content)
		"stats":         _build_stats(content)
		"region_select": _build_region_select(content)
		"node_preview":  _build_node_preview(content)
		"smelt":         _build_smelt(content)
		"forge":         _build_forge(content)
		"purge":         _build_purge(content)
		"perk_choice":   _build_perk_choice(content)
		"perk_replace":  _build_perk_replace(content)
		"new_run_setup": _build_new_run_setup(content)
		_:               close_all()

	# 居中
	await get_tree().process_frame
	_panel.reset_size()
	_panel.position = (Vector2(1280, 720) - _panel.size) / 2.0
	_panel.pivot_offset = _panel.size / 2.0

# ------------------------------------------------------------
# 通用构件
# ------------------------------------------------------------
func _title(parent: Control, text: String, color: Color = UITheme.C_GOLD) -> void:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)

func _text(parent: Control, text: String, size: int = 16, color: Color = UITheme.C_TEXT, center: bool = true, min_w: float = 440.0) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(min_w, 0)
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _btn_row(parent: Control) -> HBoxContainer:
	var h = HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	parent.add_child(h)
	return h

func _btn(parent: Control, text: String, cb: Callable, min_w: float = 130.0) -> Button:
	var b = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 42)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call()
	)
	parent.add_child(b)
	return b

func _separator(parent: Control) -> void:
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	parent.add_child(sep)

## 装备卡片（compact: 列表用；完整: 含解说词条）
func _item_card(parent: Control, item: Dictionary, compact: bool = false) -> void:
	var card = PanelContainer.new()
	var rc = UITheme.rarity_color(item.rarity)
	card.add_theme_stylebox_override("panel", UITheme.flat_box(Color(0.08, 0.1, 0.16, 0.9), rc, 2, 12, 10))
	parent.add_child(card)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)

	# 图标 + 名称行
	var head_row = HBoxContainer.new()
	head_row.add_theme_constant_override("separation", 8)
	v.add_child(head_row)
	var icon = TextureRect.new()
	icon.texture = PixelArt.item_icon(item)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.custom_minimum_size = Vector2(28, 28)
	icon.size = Vector2(28, 28)
	head_row.add_child(icon)
	var nm = Label.new()
	var lvl_txt = (" +%d" % item.level) if item.level > 0 else ""
	nm.text = "%s%s · %s" % [item.get("name", item.base_name), lvl_txt, GameData.get_rarity_name(item.rarity)]
	nm.add_theme_font_size_override("font_size", 18)
	nm.add_theme_color_override("font_color", rc)
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_row.add_child(nm)

	var st = Label.new()
	st.text = EquipmentModifier.format_item_stats(item)
	st.add_theme_font_size_override("font_size", 15)
	v.add_child(st)

	if not compact:
		for line in EquipmentModifier.format_affixes(item):
			var al = Label.new()
			al.text = line
			al.add_theme_font_size_override("font_size", 13)
			al.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
			al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			al.custom_minimum_size = Vector2(420, 0)
			v.add_child(al)
		# 解说词条（稀有度越高越丰富）
		var lore = item.get("lore", [])
		if lore is Array and lore.size() > 0:
			var sep = HSeparator.new()
			v.add_child(sep)
			for line in lore:
				var ll = Label.new()
				ll.text = "“%s”" % line
				ll.add_theme_font_size_override("font_size", 13)
				ll.add_theme_color_override("font_color", Color("#c8b88a"))
				ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				ll.custom_minimum_size = Vector2(420, 0)
				v.add_child(ll)

# ------------------------------------------------------------
# 商店
# ------------------------------------------------------------
func _build_shop(c: VBoxContainer) -> void:
	_title(c, "旅 行 商 店")
	_text(c, "金币: %d   ·   点击「详情」可查看完整词条与解说" % GameState.gold, 15, UITheme.C_GOLD)

	var stock: Array = GameState.shop_stock
	if stock.is_empty():
		_text(c, "货架已空 — 都被你买光了！", 15, UITheme.C_TEXT_DIM)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620, mini(440, stock.size() * 88 + 10))
	c.add_child(scroll)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	for i in range(stock.size()):
		var it = stock[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		inner.add_child(row)
		var cardbox = VBoxContainer.new()
		cardbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cardbox)
		_item_card(cardbox, it, true)
		var idx = i
		var bcol = VBoxContainer.new()
		bcol.add_theme_constant_override("separation", 4)
		row.add_child(bcol)
		_btn(bcol, "详情", func():
			SignalBus.show_modal.emit("equip_detail", { "item": GameState.shop_stock[idx], "price": GameState.shop_stock[idx].price, "shop_index": idx })
		, 100.0)
		var buy = _btn(bcol, "%d 金币" % it.price, func():
			if GameState.buy_shop_item(idx):
				Sfx.play("coin")
			else:
				SignalBus.show_toast.emit("金币不足或背包已满")
		, 100.0)
		buy.disabled = GameState.gold < it.price or GameState.bag.size() >= GameData.PLAYER_BASE["bag_capacity"]

	# 药水
	var prow = _btn_row(c)
	var pot = _btn(prow, "购买药水 (%d 金币) — 现有 ×%d" % [GameState.potion_price, GameState.potions], func():
		if GameState.buy_potion():
			Sfx.play("coin")
		else:
			SignalBus.show_toast.emit("金币不足或药水已达上限")
	, 320.0)
	pot.tooltip_text = GameData.POTION_INFO.desc
	pot.disabled = GameState.gold < GameState.potion_price or GameState.potions >= GameData.PLAYER_BASE["max_potions"]

	var brow = _btn_row(c)
	_btn(brow, "离开商店", func():
		close_all()
		GameState.back_to_map()
	, 180.0)

# ------------------------------------------------------------
# 背包（容量 32 · 分类查看 · 一键整理 · 全部装备可看详情）
# ------------------------------------------------------------
const BAG_FILTERS = [
	["all", "全部"], ["weapon", "武器"], ["clothes", "衣物"], ["accessory", "配饰"],
]
const CLOTHES_SLOTS = ["armor", "helmet", "pants", "boots"]

func _bag_filter_match(item: Dictionary, filter: String) -> bool:
	match filter:
		"all": return true
		"weapon": return str(item.get("slot", "")) == "weapon"
		"clothes": return CLOTHES_SLOTS.has(str(item.get("slot", "")))
		"accessory": return str(item.get("slot", "")) == "accessory"
	return true

func _build_bag(c: VBoxContainer) -> void:
	c.add_theme_constant_override("separation", 6)
	_title(c, "背 包")
	var cap = int(GameData.PLAYER_BASE["bag_capacity"])

	# ============ 左右布局：左=英雄+装备 ｜ 右=物品栏+词条精华 ============
	var main = HBoxContainer.new()
	main.add_theme_constant_override("separation", 18)
	main.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(main)

	# ---------- 左列 ----------
	var left = VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(430, 0)
	main.add_child(left)
	_build_bag_hero(left)
	_build_bag_equip(left)

	# ---------- 右列 ----------
	var right = VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(716, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(right)

	# 资源概览
	var resl = Label.new()
	resl.text = "金币 %d      ·      精粹 ×%d      ·      药水 ×%d" % [GameState.gold, GameState.refine_dust, GameState.potions]
	resl.add_theme_font_size_override("font_size", 15)
	resl.add_theme_color_override("font_color", UITheme.C_GOLD)
	right.add_child(resl)

	# 物品栏标题 + 分类 + 整理
	var bagcount = GameState.bag.size()
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	right.add_child(head)
	var hl = Label.new()
	hl.text = "物品栏  %d / %d" % [bagcount, cap]
	hl.add_theme_font_size_override("font_size", 17)
	hl.add_theme_color_override("font_color", UITheme.C_GOLD)
	hl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hl.custom_minimum_size = Vector2(140, 0)
	head.add_child(hl)
	var filter: String = str(_current_data.get("filter", "all"))
	for fd in BAG_FILTERS:
		var fkey: String = fd[0]
		var b = _btn(head, fd[1], func():
			_current_data["filter"] = fkey
			_rebuild()
		, 72.0)
		if fkey == filter:
			b.add_theme_color_override("font_color", UITheme.C_GOLD)
			b.add_theme_stylebox_override("normal", UITheme.flat_box(Color("#2f3a58"), UITheme.C_GOLD, 2, 8, 6))
	var sort_b = _btn(head, "整理", func():
		GameState.sort_bag()
		SignalBus.show_toast.emit("背包已整理：按部位与稀有度排列")
	, 72.0)
	sort_b.tooltip_text = "按 部位 → 稀有度 → 品级 → 强化 排序背包"

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(grid)

	var expanded: Array = _current_data.get("expanded", [])
	var shown = 0
	for i in range(GameState.bag.size()):
		var it = GameState.bag[i]
		if not _bag_filter_match(it, filter):
			continue
		shown += 1
		_bag_item_cell(grid, it, i, expanded.has(i))
	if shown == 0:
		_text(right, "（该分类下没有物品）", 14, UITheme.C_TEXT_DIM, true, 680.0)

	# 词条精华（右列底部）
	_build_bag_essences(right)

	var brow = _btn_row(c)
	_btn(brow, "关闭 [Esc]", close, 160.0)

## 左列上：英雄立绘 + 名称/周目/属性概览 + 属性详情按钮
func _build_bag_hero(parent: Control) -> void:
	var box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.flat_box(Color(0.06, 0.07, 0.12, 0.94), Color("#3a4660"), 2, 12, 12))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)

	# 立绘
	var fig = TextureRect.new()
	var htex = PixelArt.hero_texture(GameState.equipment)
	var hsz = PixelArt.hero_frame_size()
	var atlas = AtlasTexture.new()
	atlas.atlas = htex
	atlas.region = Rect2(0, 0, hsz.x, hsz.y)
	fig.texture = atlas
	fig.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fig.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fig.custom_minimum_size = Vector2(hsz.x * 3.2, hsz.y * 3.2)
	row.add_child(fig)

	# 属性概览
	var info = VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(info)
	var nm = Label.new()
	nm.text = GameState.hero_name
	nm.add_theme_font_size_override("font_size", 20)
	nm.add_theme_color_override("font_color", UITheme.C_GOLD)
	info.add_child(nm)
	var sub = Label.new()
	sub.text = ("强化 %d 周目 · 区域 %d" % [GameState.cycle, GameState.region + 1]) if GameState.cycle > 0 else ("区域 %d" % (GameState.region + 1))
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	info.add_child(sub)

	var ts = EquipmentModifier.calculate_total_stats(GameState.equipment)
	var lines = [
		["生命", "%d / %d" % [GameState.hp, GameState.max_hp]],
		["攻击", "%d" % int(ts.atk)],
		["防御", "%d" % int(ts.def)],
		["暴击", "%d%%" % int(ts.crit)],
		["暴伤", "%d%%" % int(ts.crit_dmg)],
		["闪避", "%d%%" % int(ts.get("dodge_chance", 0))],
	]
	for ln in lines:
		var l = Label.new()
		l.text = "%s   %s" % [ln[0], ln[1]]
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", UITheme.C_TEXT)
		info.add_child(l)
	var det = _btn(info, "属性详情", func():
		SignalBus.show_modal.emit("stats", {})
	, 120.0)
	det.tooltip_text = "查看属性的基础/装备/总计明细与套装"

## 左列下：6 个装备槽（点击查看详情 → 可脱下/强化/精铸/熔炼/出售/分解）
func _build_bag_equip(parent: Control) -> void:
	var box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.flat_box(Color(0.06, 0.07, 0.12, 0.94), Color("#3a4660"), 2, 12, 12))
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(box)
	var col = VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)
	var t = Label.new()
	t.text = "— 已穿戴装备（点击可脱下/强化/精铸/熔炼…）—"
	t.add_theme_font_size_override("font_size", 13)
	t.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(t)
	var eg = GridContainer.new()
	eg.columns = 2
	eg.add_theme_constant_override("h_separation", 8)
	eg.add_theme_constant_override("v_separation", 8)
	col.add_child(eg)
	# 武器置顶，其余护甲随后
	for slot in ["weapon", "helmet", "armor", "accessory", "pants", "boots"]:
		_equip_slot_box(eg, slot)

## 单个装备槽方块（含图标/部位/名称，点击进入详情或提示空槽）
func _equip_slot_box(parent: Control, slot: String) -> void:
	var it = GameState.equipment.get(slot)
	var bc = UITheme.rarity_color(it.rarity) if it else Color("#3a4660")
	var box = PanelContainer.new()
	box.add_theme_stylebox_override("panel", UITheme.flat_box(Color(0.09, 0.11, 0.17, 0.95), bc, 2, 10, 8))
	box.custom_minimum_size = Vector2(196, 64)
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(box)
	var r = HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(r)
	var icon = TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.size = Vector2(40, 40)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if it:
		icon.texture = PixelArt.item_icon(it)
	r.add_child(icon)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_child(v)
	var sl = Label.new()
	sl.text = GameData.slot_name(slot)
	sl.add_theme_font_size_override("font_size", 12)
	sl.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	sl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sl)
	var nl = Label.new()
	if it:
		nl.text = "%s%s" % [it.get("name", it.base_name), (" +%d" % it.level) if it.level > 0 else ""]
		nl.add_theme_color_override("font_color", bc)
	else:
		nl.text = "— 空 —"
		nl.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	nl.add_theme_font_size_override("font_size", 14)
	nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nl)
	box.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("click")
			if it:
				SignalBus.show_modal.emit("equip_detail", { "slot": slot, "item": it })
			else:
				SignalBus.show_toast.emit("「%s」槽位为空" % GameData.slot_name(slot))
	)

## 物品栏单元格：折叠态=图标+名称；展开态=数值+词条+操作按钮
func _bag_item_cell(parent: Control, it: Dictionary, idx: int, is_open: bool) -> void:
	var rc = UITheme.rarity_color(it.rarity)
	var cell = PanelContainer.new()
	cell.add_theme_stylebox_override("panel", UITheme.flat_box(Color(0.08, 0.10, 0.16, 0.95), rc, 2, 10, 8))
	cell.custom_minimum_size = Vector2(326, 0)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(cell)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(v)

	# 折叠行：图标 + 名称 + 展开箭头
	var head = HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)
	var icon = TextureRect.new()
	icon.texture = PixelArt.item_icon(it)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(30, 30)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(icon)
	var nm = Label.new()
	var lvl_txt = (" +%d" % it.level) if it.level > 0 else ""
	nm.text = "%s%s" % [it.get("name", it.base_name), lvl_txt]
	nm.add_theme_font_size_override("font_size", 15)
	nm.add_theme_color_override("font_color", rc)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(220, 0)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nm.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(nm)
	var arrow = Label.new()
	arrow.text = "▾" if is_open else "▸"
	arrow.add_theme_font_size_override("font_size", 14)
	arrow.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(arrow)

	if is_open:
		# 数值
		var st = Label.new()
		st.text = EquipmentModifier.format_item_stats(it)
		st.add_theme_font_size_override("font_size", 14)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(st)
		# 特性词条
		for line in EquipmentModifier.format_affixes(it):
			var al = Label.new()
			al.text = line
			al.add_theme_font_size_override("font_size", 12)
			al.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
			al.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			al.custom_minimum_size = Vector2(300, 0)
			al.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(al)
		# 操作按钮（自动换行）
		var bar = HFlowContainer.new()
		bar.add_theme_constant_override("h_separation", 6)
		bar.add_theme_constant_override("v_separation", 6)
		v.add_child(bar)
		_btn(bar, "装备", func():
			GameState.equip_item(GameState.bag[idx])
			Sfx.play("equip")
		, 70.0)
		if it.level < GameData.COMBAT["max_upgrade_level"]:
			var cost = EquipmentModifier.get_upgrade_cost(it, GameState.region)
			var up = _btn(bar, "强化(%d金)" % cost, func():
				if GameState.upgrade_bag_item(idx):
					Sfx.play("upgrade")
				else:
					SignalBus.show_toast.emit("金币不足")
			, 104.0)
			up.tooltip_text = EquipmentModifier.format_upgrade_preview(it)
			up.disabled = GameState.gold < cost
		var val = EquipmentModifier.get_sell_value(it)
		_btn(bar, "出售(%d金)" % val, func():
			GameState.sell_bag_item(idx)
			Sfx.play("coin")
		, 104.0)
		var dust = GameData.dust_gain(int(it.rarity))
		var dis = _btn(bar, "分解(+%d粹)" % dust, func():
			GameState.dismantle_bag_item(idx)
		, 100.0)
		dis.tooltip_text = "销毁该装备，获得 %d 精粹（精铸史诗/传说装备每次需 %d 精粹）" % [dust, int(GameData.COMBAT["refine_cost"])]
		var sm = _btn(bar, "熔炼", func():
			SignalBus.show_modal.emit("smelt", { "index": idx })
		, 70.0)
		if GameState.can_smelt(it):
			sm.tooltip_text = "花费 %d 金销毁该装备，由你自选一条词条萃取为精华（可锻打到其他装备上）" % int(GameData.COMBAT["smelt_cost"])
		else:
			sm.disabled = true
			sm.tooltip_text = "该装备没有可萃取的词条（基底特性与元素不可萃取）"
		_refine_button(bar, it, { "kind": "bag", "index": idx })

	cell.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			Sfx.play("click")
			var exp: Array = _current_data.get("expanded", [])
			if exp.has(idx):
				exp.erase(idx)
			else:
				exp.append(idx)
			_current_data["expanded"] = exp
			_rebuild()
	)

## 词条精华区（熔炼所得，可锻打；同词条锻打=强化；可付费消除已有词条）
func _build_bag_essences(parent: Control) -> void:
	_separator(parent)
	var ess_row = HBoxContainer.new()
	ess_row.add_theme_constant_override("separation", 10)
	parent.add_child(ess_row)
	var ess_lbl = Label.new()
	ess_lbl.text = "词条精华 %d/%d（锻打 %d 金）" % [GameState.essences.size(), GameData.COMBAT["essence_cap"], GameState.get_forge_cost()]
	ess_lbl.add_theme_color_override("font_color", Color("#e8a8ff"))
	ess_lbl.add_theme_font_size_override("font_size", 14)
	ess_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ess_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ess_row.add_child(ess_lbl)
	var purge_b = _btn(ess_row, "消除词条", func():
		SignalBus.show_modal.emit("purge", {})
	, 110.0)
	purge_b.tooltip_text = "花费 %d 金移除装备上的一条词条，为新词条腾位置" % int(GameData.COMBAT["purge_cost"])
	if GameState.essences.is_empty():
		_text(parent, "（熔炼任意带词条的装备可自选萃取词条精华，费用 %d 金）" % int(GameData.COMBAT["smelt_cost"]), 13, UITheme.C_TEXT_DIM, false, 680.0)
		return
	# 已拥有的词条精华列表（带滚动，确保「锻打」按钮始终可见）
	var es_scroll = ScrollContainer.new()
	es_scroll.custom_minimum_size = Vector2(700, mini(118, GameState.essences.size() * 34 + 6))
	es_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	es_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(es_scroll)
	var es_inner = VBoxContainer.new()
	es_inner.add_theme_constant_override("separation", 5)
	es_inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	es_scroll.add_child(es_inner)
	for i in range(GameState.essences.size()):
		var es = GameState.essences[i]
		var ad = GameData.AFFIXES.get(es.affix, {})
		var er = HBoxContainer.new()
		er.add_theme_constant_override("separation", 8)
		es_inner.add_child(er)
		var el = Label.new()
		el.text = "◈ %s — %s（萃取自 %s）" % [ad.get("name", es.affix), ad.get("desc", ""), es.get("from", "?")]
		el.add_theme_font_size_override("font_size", 13)
		el.add_theme_color_override("font_color", Color("#e8a8ff"))
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.custom_minimum_size = Vector2(560, 0)
		el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		er.add_child(el)
		var ei = i
		_btn(er, "锻打", func():
			SignalBus.show_modal.emit("forge", { "essence_idx": ei })
		, 80.0)

## 精铸按钮：史诗+装备且基准低于当前最高区域时显示（增量：每次 +1 区域）
func _refine_button(r: Control, it: Dictionary, target: Dictionary) -> void:
	if not GameState.can_refine(it):
		return
	var cost = int(GameData.COMBAT["refine_cost"])
	var cur_eff = int(it.get("tier_eff", 0))
	var next_eff = mini(GameState.best_eff, cur_eff + 1)
	var preview = EquipmentFactory.baseline_stats(it, next_eff)
	var b = _btn(r, "精铸(%d粹)" % cost, func():
		GameState.refine_item(target)
	, 104.0)
	var parts = []
	if preview.atk > 0:
		parts.append("攻击 %d→%d" % [int(it.stats.atk), int(preview.atk)])
	if preview.def > 0:
		parts.append("防御 %d→%d" % [int(it.stats.def), int(preview.def)])
	if preview.hp > 0:
		parts.append("生命 %d→%d" % [int(it.stats.hp), int(preview.hp)])
	b.tooltip_text = "每 %d 精粹提升 1 个区域基准（%d→%d，最高 %d）：%s" % [cost, cur_eff + 1, next_eff + 1, GameState.best_eff + 1, " · ".join(parts)]
	b.disabled = GameState.refine_dust < cost
	b.add_theme_color_override("font_color", Color("#7ad9ff"))

# ------------------------------------------------------------
# 宝箱
# ------------------------------------------------------------
func _build_treasure(c: VBoxContainer) -> void:
	_title(c, "宝 箱 开 启 ！")
	if _current_data.get("type") == "gold":
		_text(c, "你撬开箱盖，金光涌出 ——", 16)
		_text(c, "+%d 金币" % _current_data.get("gold", 0), 26, UITheme.C_GOLD)
		var r = _btn_row(c)
		_btn(r, "收下继续", func():
			Sfx.play("coin")
			close_all()
			GameState.back_to_map()
		, 170.0)
	else:
		_text(c, "箱中静卧着一件装备：", 16)
		var item = _current_data.get("item", {})
		_item_card(c, item)
		_drop_choice_buttons(c)

# ------------------------------------------------------------
# 事件（通用：按事件定义生成选项按钮）
# ------------------------------------------------------------
func _build_event(c: VBoxContainer) -> void:
	var key = _current_data.get("key", "")
	_title(c, _current_data.get("title", "神秘事件"))
	_text(c, _current_data.get("desc", ""), 16, UITheme.C_TEXT)

	var choices: Array = _current_data.get("choices", [])
	if choices.is_empty():
		var r0 = _btn_row(c)
		_btn(r0, "继续", func():
			close_all()
			GameState.back_to_map()
		, 140.0)
		return

	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	for i in range(choices.size()):
		var ch = choices[i]
		var cost = GameState.get_event_choice_cost(ch)
		var label: String = str(ch.get("label", "……"))
		if cost > 0:
			label += "（花费 %d 金币）" % cost
		var idx = i
		var row = _btn_row(v)
		var b = _btn(row, label, func():
			close_all()
			GameState.handle_event_choice(key, idx)
		, 340.0)
		if cost > 0 and GameState.gold < cost:
			b.disabled = true
			b.tooltip_text = "金币不足"
		if int(ch.get("require_potion", 0)) > GameState.potions:
			b.disabled = true
			b.tooltip_text = "需要药水 ×%d" % int(ch.get("require_potion", 0))

# ------------------------------------------------------------
# 奖励
# ------------------------------------------------------------
func _build_reward(c: VBoxContainer) -> void:
	var src = _current_data.get("source", "")
	if src != "":
		_title(c, "交 易 达 成" if src == "merchant" else "意 外 收 获")
	else:
		_title(c, "战 斗 胜 利 ！", UITheme.C_GREEN)
		var g = _current_data.get("gold", 0)
		if g > 0:
			_text(c, "+%d 金币" % g, 20, UITheme.C_GOLD)

	var drop = _current_data.get("drop", _current_data.get("item"))
	if drop:
		_text(c, "获得战利品：", 15, UITheme.C_TEXT_DIM)
		_item_card(c, drop)
		_drop_choice_buttons(c)
	else:
		var r = _btn_row(c)
		_btn(r, "继 续", func():
			close_all()
			GameState.close_reward()
		, 170.0)

## 装备/入包/出售/放弃 四连按钮 (treasure 与 reward 通用)
func _drop_choice_buttons(c: VBoxContainer) -> void:
	var r = _btn_row(c)
	_btn(r, "装备", func():
		close_all()
		Sfx.play("equip")
		GameState.handle_drop("equip")
	, 110.0)
	var bag_btn = _btn(r, "放入背包", func():
		close_all()
		GameState.handle_drop("bag")
	, 130.0)
	bag_btn.disabled = GameState.bag.size() >= GameData.PLAYER_BASE["bag_capacity"]
	var drop = GameState.pending_drop
	var val = EquipmentModifier.get_sell_value(drop) if drop else 0
	_btn(r, "出售 (%d金)" % val, func():
		close_all()
		Sfx.play("coin")
		GameState.handle_drop("sell")
	, 140.0)
	_btn(r, "放弃", func():
		close_all()
		GameState.pending_drop = null
		GameState.close_reward()
	, 100.0)
	var hint = _text(c, "提示：可先按 [B] 打开背包对比装备，关闭后回到此界面", 13, UITheme.C_TEXT_DIM)
	hint.modulate.a = 0.8

# ------------------------------------------------------------
# 区域攻克 / 胜利 / 失败
# ------------------------------------------------------------
func _build_region_clear(c: VBoxContainer) -> void:
	var region = _current_data.get("region", 0)
	var biome = GameData.get_biome(region)
	_title(c, "区 域 攻 克 ！", UITheme.C_GREEN)
	_text(c, "%s 的首领已被击败！" % biome.name, 17)
	_text(c, "+%d 金币奖励 · 生命完全恢复" % _current_data.get("bonus", 0), 16, UITheme.C_GOLD)
	var nb = GameData.get_biome(_current_data.get("next_region", region + 1))
	_text(c, "前方是 —— %s" % nb.name, 16, UITheme.C_TEXT_DIM)
	var r = _btn_row(c)
	_btn(r, "踏入下一区域", func():
		close_all()
		Sfx.play("victory")
		GameState.next_region()
	, 200.0)

func _build_victory(c: VBoxContainer) -> void:
	var cleared = int(_current_data.get("cycle", 0))
	if cleared == 0:
		_title(c, "✦ 远 征 完 成 ✦")
		_text(c, "五大区域全部攻克，传奇就此铸成！", 17)
	else:
		_title(c, "✦ 强化 %d 周目 完成 ✦" % cleared)
		_text(c, "更强的怪物也没能拦住你！", 17)
	_stats_block(c, _current_data.get("stats", {}))
	_text(c, "通关奖励 +%d 金币 · 当前金币 %d" % [_current_data.get("bonus", 0), _current_data.get("gold", 0)], 16, UITheme.C_GOLD)
	_text(c, "远征没有终点 —— 强化 %d 周目已就绪：怪物更强、词条更多，装备掉落也更高级。\n进度已保存，随时可以退出休息。" % (cleared + 1), 14, UITheme.C_TEXT_DIM)
	var r = _btn_row(c)
	_btn(r, "进入强化 %d 周目" % (cleared + 1), func():
		close_all()
		Sfx.play("victory")
		SignalBus.view_changed.emit("map")
	, 210.0)
	_btn(r, "返回标题", func():
		close_all()
		SignalBus.view_changed.emit("title")
	, 150.0)

func _build_defeat(c: VBoxContainer) -> void:
	_title(c, "你 倒 下 了 ……", UITheme.C_DANGER)
	_text(c, "在 %s 的征途戛然而止。" % GameData.get_biome(_current_data.get("region", 0)).name, 16)
	_text(c, "损失了 %d 金币" % _current_data.get("lost_gold", 0), 15, UITheme.C_TEXT_DIM)
	_stats_block(c, _current_data.get("stats", {}))
	_text(c, "(装备与等级保留 — 重整旗鼓再战！)", 14, UITheme.C_TEXT_DIM)
	var r = _btn_row(c)
	_btn(r, "重整旗鼓", func():
		close_all()
		GameState.retry_region()
	, 160.0)
	_btn(r, "返回标题", func():
		close_all()
		SignalBus.view_changed.emit("title")
	, 150.0)

func _stats_block(c: VBoxContainer, stats: Dictionary) -> void:
	if stats.is_empty():
		return
	var grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 36)
	grid.add_theme_constant_override("v_separation", 4)
	c.add_child(grid)
	var rows = [
		["击杀敌人", str(stats.get("kills", 0))],
		["精英 / 首领", "%d / %d" % [stats.get("elite_kills", 0), stats.get("boss_kills", 0)]],
		["造成伤害", str(stats.get("dmg_dealt", 0))],
		["承受伤害", str(stats.get("dmg_taken", 0))],
		["赚取金币", str(stats.get("gold_earned", 0))],
		["探索节点", str(stats.get("nodes_visited", 0))],
	]
	for row in rows:
		var k = Label.new()
		k.text = row[0]
		k.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
		k.add_theme_font_size_override("font_size", 15)
		grid.add_child(k)
		var v = Label.new()
		v.text = row[1]
		v.add_theme_font_size_override("font_size", 15)
		grid.add_child(v)

# ------------------------------------------------------------
# 帮助
# ------------------------------------------------------------
func _build_help(c: VBoxContainer) -> void:
	_title(c, "冒 险 指 南")
	var lines = [
		"◆ 目标：穿越 5 大区域击败首领 — 通关后进入更强的「强化周目」，无限循环。",
		"◆ 地图路线探索：用 WASD 沿虚线移动小人，按 E 进入所站节点；可折返换路。",
		"◆ 已打过的战斗只能经过不能再进；商店可重复进入（每次进货）。",
		"◆ 战斗节点可先侦察：怪物数量、风格、词条、精确数值一目了然。",
		"◆ 战斗：攻击[1] · 盾击[2]（冷却3·默认后手）· 防御[3]（冷却2）· 药水[4]（冷却3）。",
		"◆ 先后手：普攻/防御/药水先手；盾击后手（剑/疾盾词条豁免）；「先手」怪总是抢先。",
		"◆ 武器差异：剑盾击先手+护盾增伤 / 斧 ×1.7 破甲、攻击后冷却 / 弓多箭齐发（连击词条仅弓生效，上限 5）。",
		"◆ 护盾有上限：你的护盾不超过最大生命 40%；怪物护盾不超过其生命上限 60%，详见图鉴「机制」页。",
		"◆ 锻打强化：同词条精华锻打到已有该词条的装备上 → 词条升级（最高 Lv.3，数值翻倍/三倍）。",
		"◆ 元素：闪电克森林·森林克大地·大地克寒冰·寒冰克焰火·焰火克闪电，克制 ×1.3。",
		"◆ 装备六部位：武器/铠甲/头盔/裤子/鞋/配饰；同前缀 2/3 件成套装；+3 被动 +5 独特。",
		"◆ 新存档：给角色起名并分配 10 点天赋；通关区域 2 / 区域 5 后各三选一天赋词条（周目同样），上限 5 条、超出可替换。",
		"◆ 熔炼（40金）：销毁史诗+装备，由你【自选】其中一条词条萃取为精华 → 锻打到其他装备；同词条=强化；也可花 40 金消除词条腾位。",
		"◆ 词条上限随稀有度：稀有 2 条 / 史诗 3 条 / 传说 4 条。",
		"◆ 掉落：精英 70% 稀有 30% 史诗；首领 70% 史诗 30% 传奇；周目大 Boss 60% 史诗 40% 传奇。",
		"◆ 精铸：分解装备得精粹（普1/稀3/史8/传20），每花 5 精粹把史诗/传说装备的基准区域 +1（如 16→17），多次精铸逐级追平最高区域。",
		"◆ 周目大 Boss：每通关区域 5 后，会有一只远古噩梦压轴登场（八岐大蛇/九尾狐/三头石像/虚空兽），击败后才进入新周目。",
		"◆ 换区不重置：同一周目内各区域的关卡记录都会保留；只有阵亡才重置当前区域。",
		"◆ 背包：左侧为角色立绘与六部位已穿戴装备、右侧物品栏可展开操作并查看词条精华，可按 武器/衣物/配饰 分类、一键整理。",
		"◆ 已穿戴装备：在背包左侧点击任一装备槽，即可脱下/强化/精铸/熔炼/出售/分解，与背包内装备功能一致。",
		"◆ 图鉴搜索：图鉴顶部输入关键词可定位条目位置。",
		"◆ 阵亡损失一半金币，装备保留；进度随时自动保存（3 个存档位）。",
		"◆ 快捷键：B 背包 · C 图鉴 · V 属性 · Esc 关闭窗口。",
	]
	for line in lines:
		_text(c, line, 15, UITheme.C_TEXT, false)
	var r = _btn_row(c)
	_btn(r, "明白了", close, 150.0)

# ------------------------------------------------------------
# 装备详情
# ------------------------------------------------------------
func _build_equip_detail(c: VBoxContainer) -> void:
	var item = _current_data.get("item", {})
	var slot = _current_data.get("slot", "")
	_title(c, "装 备 详 情 · %s" % GameData.slot_name(str(item.get("slot", ""))))
	_item_card(c, item)
	var r = _btn_row(c)

	# 商店详情模式：显示购买按钮
	if _current_data.has("price"):
		var price = int(_current_data.price)
		var sidx = int(_current_data.get("shop_index", -1))
		var buy = _btn(r, "购买 (%d 金币)" % price, func():
			if GameState.buy_shop_item(sidx):
				Sfx.play("coin")
				close()
			else:
				SignalBus.show_toast.emit("金币不足或背包已满")
		, 180.0)
		buy.disabled = GameState.gold < price or GameState.bag.size() >= GameData.PLAYER_BASE["bag_capacity"]
		_btn(r, "返回", close, 120.0)
		return

	# 背包物品详情模式：可装备 / 强化 / 出售
	if _current_data.has("bag_index"):
		var bidx = int(_current_data.bag_index)
		if bidx < 0 or bidx >= GameState.bag.size():
			close()
			return
		if item.level < GameData.COMBAT["max_upgrade_level"]:
			var preview_b = EquipmentModifier.format_upgrade_preview(item)
			if preview_b != "":
				_text(c, "强化预览：%s" % preview_b, 14, UITheme.C_GREEN)
		_btn(r, "装备", func():
			GameState.equip_item(GameState.bag[bidx])
			Sfx.play("equip")
			close()
		, 110.0)
		if item.level < GameData.COMBAT["max_upgrade_level"]:
			var cost_b = EquipmentModifier.get_upgrade_cost(item, GameState.region)
			var up_b = _btn(r, "强化 (%d金)" % cost_b, func():
				if GameState.upgrade_bag_item(bidx):
					Sfx.play("upgrade")
					_current_data["item"] = GameState.bag[bidx]
				else:
					SignalBus.show_toast.emit("金币不足")
			, 150.0)
			up_b.disabled = GameState.gold < cost_b
		var val_b = EquipmentModifier.get_sell_value(item)
		_btn(r, "出售 (%d金)" % val_b, func():
			GameState.sell_bag_item(bidx)
			Sfx.play("coin")
			close()
		, 140.0)
		_btn(r, "关闭", close, 100.0)
		return

	# 已穿戴装备：提供与背包装备一致的全套操作（脱下/强化/精铸/熔炼/出售/分解）
	if item.level < GameData.COMBAT["max_upgrade_level"]:
		var preview = EquipmentModifier.format_upgrade_preview(item)
		if preview != "":
			_text(c, "强化预览：%s" % preview, 14, UITheme.C_GREEN)
	else:
		_text(c, "已强化至满级 +5", 15, UITheme.C_GOLD)
	var bar = HFlowContainer.new()
	bar.add_theme_constant_override("h_separation", 8)
	bar.add_theme_constant_override("v_separation", 8)
	bar.alignment = FlowContainer.ALIGNMENT_CENTER
	c.add_child(bar)
	_btn(bar, "脱下", func():
		if GameState.unequip(slot):
			Sfx.play("equip")
			close()
	, 80.0)
	if item.level < GameData.COMBAT["max_upgrade_level"]:
		var cost = EquipmentModifier.get_upgrade_cost(item, GameState.region)
		var up = _btn(bar, "强化(%d金)" % cost, func():
			if GameState.upgrade_equipped(slot):
				Sfx.play("upgrade")
				_current_data["item"] = GameState.equipment[slot]
			else:
				SignalBus.show_toast.emit("金币不足")
		, 116.0)
		up.disabled = GameState.gold < cost
	_refine_button(bar, item, { "kind": "equip", "slot": slot })
	var sm = _btn(bar, "熔炼", func():
		SignalBus.show_modal.emit("smelt", { "equip_slot": slot })
	, 80.0)
	if GameState.can_smelt(item):
		sm.tooltip_text = "花费 %d 金销毁该装备，自选一条词条萃取为精华" % int(GameData.COMBAT["smelt_cost"])
	else:
		sm.disabled = true
		sm.tooltip_text = "该装备没有可萃取的词条（基底特性与元素不可萃取）"
	var sval = EquipmentModifier.get_sell_value(item)
	_btn(bar, "出售(%d金)" % sval, func():
		if GameState.sell_equipped(slot):
			Sfx.play("coin")
			close()
	, 116.0)
	var sdust = GameData.dust_gain(int(item.rarity))
	var dis = _btn(bar, "分解(+%d粹)" % sdust, func():
		if GameState.dismantle_equipped(slot):
			close()
	, 116.0)
	dis.tooltip_text = "销毁已穿戴装备，获得 %d 精粹" % sdust
	_btn(c, "关闭", close, 120.0)

# ------------------------------------------------------------
# 存档位管理
# ------------------------------------------------------------
func _build_saves(c: VBoxContainer) -> void:
	_title(c, "存 档 位")
	_text(c, "进度随时自动保存到当前存档位。选择存档位后，继续/新远征都作用于该档。", 14, UITheme.C_TEXT_DIM)

	for i in range(GameState.SLOT_COUNT):
		var slot_i = i
		var card = PanelContainer.new()
		var is_active = (i == GameState.save_slot)
		var border = UITheme.C_GOLD if is_active else UITheme.C_BORDER
		card.add_theme_stylebox_override("panel", UITheme.flat_box(Color(0.08, 0.1, 0.16, 0.9), border, 2, 12, 10))
		c.add_child(card)
		var h = HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		card.add_child(h)

		var info_box = VBoxContainer.new()
		info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_box.custom_minimum_size = Vector2(280, 0)
		h.add_child(info_box)

		var head = Label.new()
		head.text = "存档位 %d %s" % [i + 1, "· 当前" if is_active else ""]
		head.add_theme_font_size_override("font_size", 17)
		head.add_theme_color_override("font_color", UITheme.C_GOLD if is_active else UITheme.C_TEXT)
		info_box.add_child(head)

		var info = GameState.get_slot_info(i)
		var detail = Label.new()
		if info.is_empty():
			detail.text = "（空存档位）"
		else:
			var biome = GameData.get_biome(info.region)
			var cyc = ("强化%d周目 · " % int(info.get("cycle", 0))) if int(info.get("cycle", 0)) > 0 else ""
			detail.text = "%s · %s区域 %d · %s\n金币 %d · 击杀 %d · %s" % [str(info.get("hero_name", "冒险者")), cyc, info.region + 1, biome.name, info.gold, info.kills, info.timestamp]
		detail.add_theme_font_size_override("font_size", 13)
		detail.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
		info_box.add_child(detail)

		var bcol = VBoxContainer.new()
		bcol.add_theme_constant_override("separation", 6)
		h.add_child(bcol)
		if not info.is_empty():
			_btn(bcol, "载入", func():
				if GameState.load_game(slot_i):
					close_all()
					SignalBus.show_toast.emit("已读取存档位 %d" % (slot_i + 1))
				else:
					SignalBus.show_toast.emit("存档读取失败")
			, 110.0)
			_btn(bcol, "删除", func():
				GameState.clear_save(slot_i)
				_rebuild()
				SignalBus.show_toast.emit("已删除存档位 %d" % (slot_i + 1))
			, 110.0)
		else:
			_btn(bcol, "选用此档", func():
				GameState.set_active_slot(slot_i)
				_rebuild()
			, 110.0)
		if not is_active and not info.is_empty():
			_btn(bcol, "设为当前", func():
				GameState.set_active_slot(slot_i)
				_rebuild()
			, 110.0)

	var r = _btn_row(c)
	_btn(r, "关闭", close, 140.0)

# ------------------------------------------------------------
# 区域选择（全地图开放）
# ------------------------------------------------------------
func _build_region_select(c: VBoxContainer) -> void:
	var in_run: bool = _current_data.get("in_run", false)
	_title(c, "选 择 区 域" if in_run else "开 始 新 远 征")
	var tip = "全部 5 个区域已开放，可任选其一进入。\n推荐按 1→5 顺序游玩（难度递增）。"
	if in_run and GameState.cycle > 0:
		tip += "\n当前为强化 %d 周目，切区后周目保持不变。" % GameState.cycle
	_text(c, tip, 14, UITheme.C_TEXT_DIM)

	for i in range(GameData.BIOMES.size()):
		var ri = i
		var biome = GameData.BIOMES[i]
		var names = []
		for k in biome.enemy_keys:
			names.append(GameData.get_enemy_type(k).name)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		c.add_child(row)
		var b = _btn(row, "区域 %d · %s" % [i + 1, biome.name], func():
			if in_run:
				close_all()
				GameState.switch_region(ri)
			else:
				# 新远征：先起名 + 分配天赋点
				SignalBus.show_modal.emit("new_run_setup", { "region": ri })
		, 230.0)
		if i == 0 and not in_run:
			b.add_theme_color_override("font_color", UITheme.C_GOLD)
		var d = Label.new()
		d.text = "出没: %s\n首领: %s" % ["、".join(names), biome.boss.name]
		d.add_theme_font_size_override("font_size", 13)
		d.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
		row.add_child(d)

	if not in_run:
		_text(c, "※ 新远征将覆盖当前存档位的进度", 13, Color("#cf8a6a"))
	var r = _btn_row(c)
	_btn(r, "取消", close, 140.0)

# ------------------------------------------------------------
# 属性面板：基础 + 装备 + 祝福 = 总计
# ------------------------------------------------------------
func _build_stats(c: VBoxContainer) -> void:
	_title(c, "%s 的 属 性" % GameState.hero_name)
	var bd = EquipmentModifier.calculate_stat_breakdown(GameState.equipment)
	var total = bd.total

	_text(c, "生命 %d / %d   ·   金币 %d   ·   药水 ×%d" % [GameState.hp, GameState.max_hp, GameState.gold, GameState.potions], 15, UITheme.C_GOLD)

	var grid = GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 6)
	c.add_child(grid)

	for htxt in ["属性", "基础", "装备", "总计"]:
		var hl = Label.new()
		hl.text = htxt
		hl.add_theme_font_size_override("font_size", 14)
		hl.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
		grid.add_child(hl)

	var rows = [
		["攻击力", bd.base.atk, bd.equip.atk, total.atk],
		["防御力", bd.base.def, bd.equip.def, total.def],
		["最大生命", bd.base.hp, bd.equip.hp, GameState.max_hp],
		["暴击率", "%d%%" % bd.base.crit, "+%d%%" % bd.equip.crit, "%d%%" % total.crit],
		["暴击伤害", "%d%%" % bd.base.crit_dmg, "+%d%%" % bd.equip.crit_dmg, "%d%%" % total.crit_dmg],
	]
	for row in rows:
		for j in range(4):
			var l = Label.new()
			l.text = str(row[j])
			l.add_theme_font_size_override("font_size", 15)
			if j == 3:
				l.add_theme_color_override("font_color", UITheme.C_GOLD)
			elif j == 0:
				l.add_theme_color_override("font_color", UITheme.C_TEXT)
			else:
				l.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
			grid.add_child(l)

	# 元素与周目
	var we = str(total.get("weapon_element", ""))
	var ae = str(total.get("armor_element", ""))
	var elem_parts = []
	if we != "":
		elem_parts.append("武器元素〔%s〕克%s" % [GameData.element_name(we), GameData.element_name(GameData.ELEMENTS[we].beats)])
	if ae != "":
		elem_parts.append("铠甲元素〔%s〕" % GameData.element_name(ae))
	if GameState.cycle > 0:
		elem_parts.append("强化 %d 周目（怪物按区域 +%d 成长）" % [GameState.cycle, GameState.cycle * 5])
	if elem_parts.size() > 0:
		_text(c, " · ".join(elem_parts), 14, Color("#9fd6ff"))

	# 套装
	var sets: Array = bd.get("sets", [])
	for s in sets:
		_text(c, "✪ 套装「%s·%s」(%d件)：%s" % [s.prefix, s.set_name, s.count, " / ".join(s.descs)], 14, UITheme.C_GOLD)

	if bd.buff_atk_pct > 0:
		_text(c, "✧ 区域祝福：攻击力 +%d%%（已计入总计，离开区域后消失）" % roundi(bd.buff_atk_pct), 14, UITheme.C_GREEN)
	if GameState.bonus_max_hp > 0:
		_text(c, "✧ 历练加成：最大生命 +%d（已计入总计）" % GameState.bonus_max_hp, 14, UITheme.C_GREEN)

	# 特殊效果列表
	var specials: Array = bd.specials
	if specials.size() > 0:
		_separator(c)
		_text(c, "— 生效中的被动 / 词条 / 独特效果 —", 14, UITheme.C_TEXT_DIM)
		var scroll = ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(520, mini(180, specials.size() * 26 + 10))
		c.add_child(scroll)
		var v = VBoxContainer.new()
		v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll.add_child(v)
		for sp in specials:
			var l = Label.new()
			l.text = "◆ %s — %s" % [sp.text, sp.source]
			l.add_theme_font_size_override("font_size", 13)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(500, 0)
			v.add_child(l)

	_text(c, "战斗公式：防御每点减伤 0.8 · 盾击护盾 = 4 + 防御×0.5 · 防御姿态护盾 = 5 + 防御×0.6 · 护盾上限 = 最大生命 40%", 12, UITheme.C_TEXT_DIM)

	var r = _btn_row(c)
	_btn(r, "关闭 [Esc]", close, 150.0)

# ------------------------------------------------------------
# 图鉴
# ------------------------------------------------------------
func _build_codex(c: VBoxContainer) -> void:
	_title(c, "远 征 图 鉴")
	var tab: String = _current_data.get("tab", "equip")

	# 搜索框：输入关键词定位图鉴内容；也接受隐藏指令
	var search_row = HBoxContainer.new()
	search_row.alignment = BoxContainer.ALIGNMENT_CENTER
	search_row.add_theme_constant_override("separation", 8)
	c.add_child(search_row)
	var search_edit = LineEdit.new()
	search_edit.custom_minimum_size = Vector2(320, 34)
	search_edit.placeholder_text = "搜索图鉴关键词（如：连击 / 护盾 / 史莱姆）"
	search_edit.text = str(_current_data.get("q", ""))
	search_edit.text_changed.connect(func(t): _current_data["q"] = t)
	search_edit.text_submitted.connect(func(t): _codex_do_search(t))
	search_row.add_child(search_edit)
	_btn(search_row, "搜索", func():
		_codex_do_search(str(_current_data.get("q", "")))
	, 80.0)
	if str(_current_data.get("query", "")) != "":
		_btn(search_row, "清除", func():
			_current_data.erase("query")
			_current_data["q"] = ""
			_rebuild()
		, 80.0)

	# 分页按钮
	var tabs = _btn_row(c)
	var tab_defs = [["equip", "装备库"], ["affix", "词条·套装"], ["mech", "机制"], ["perk", "天赋"], ["monster", "怪物"], ["boss", "首领"], ["event", "事件"], ["element", "元素·药水"]]
	for td in tab_defs:
		var tkey = td[0]
		var b = _btn(tabs, td[1], func():
			_current_data["tab"] = tkey
			_current_data.erase("query")
			_current_data.erase("locate")
			_rebuild()
		, 100.0)
		if tkey == tab and str(_current_data.get("query", "")) == "":
			b.add_theme_color_override("font_color", UITheme.C_GOLD)
			b.add_theme_stylebox_override("normal", UITheme.flat_box(Color("#2f3a58"), UITheme.C_GOLD, 2, 8, 6))

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 420)
	c.add_child(scroll)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	var query: String = str(_current_data.get("query", ""))
	if query != "":
		_codex_search_results(v, query)
	else:
		match tab:
			"equip":   _codex_equip(v)
			"affix":   _codex_affix(v)
			"mech":    _codex_mechanics(v)
			"perk":    _codex_perks(v)
			"monster": _codex_monsters(v)
			"boss":    _codex_bosses(v)
			"event":   _codex_events(v)
			"element": _codex_element(v)
		# 搜索跳转：滚动到包含定位文本的条目并高亮
		var locate: String = str(_current_data.get("locate", ""))
		if locate != "":
			_current_data.erase("locate")
			_codex_scroll_to(scroll, v, locate)

	var r = _btn_row(c)
	_btn(r, "关闭 [Esc]", close, 150.0)

# ------------------------------------------------------------
# 图鉴搜索：关键词索引 + 结果跳转；隐藏指令 drug/heart/money+数字
# ------------------------------------------------------------
func _codex_do_search(q: String) -> void:
	q = q.strip_edges()
	if q == "":
		_current_data.erase("query")
		_rebuild()
		return
	# 隐藏指令
	if GameState.apply_cheat(q):
		Sfx.play("upgrade")
		_current_data["q"] = ""
		_current_data.erase("query")
		_rebuild()
		return
	_current_data["query"] = q
	_rebuild()

const CODEX_TAB_NAMES = {
	"equip": "装备库", "affix": "词条·套装", "mech": "机制", "perk": "天赋",
	"monster": "怪物", "boss": "首领", "event": "事件", "element": "元素·药水",
}

## 全图鉴关键词索引：返回 [{tab, label, locate}]
func _codex_search_index(q: String) -> Array:
	var out = []
	var seen = {}
	var add = func(tab: String, label: String, locate: String):
		var k = tab + "|" + locate
		if not seen.has(k):
			seen[k] = true
			out.append({ "tab": tab, "label": label, "locate": locate })
	# 装备库（按基底）
	for entry in ItemCatalog.all_entries():
		var hay = "%s %s %s %s" % [entry.name, entry.base, entry.kind, entry.trait_desc]
		if hay.findn(q) >= 0:
			add.call("equip", "装备 · %s（%s）" % [entry.base, entry.kind], str(entry.base))
	# 词条
	for ak in GameData.AFFIX_KEYS:
		var a = GameData.AFFIXES[ak]
		if ("%s %s" % [a.name, a.desc]).findn(q) >= 0:
			add.call("affix", "词条 · %s — %s" % [a.name, a.desc], str(a.name))
	# 套装
	for p in GameData.EQUIP_PREFIXES:
		if GameData.SET_BONUSES.has(p):
			var sb = GameData.SET_BONUSES[p]
			if ("%s %s %s %s" % [p, sb.name, sb.two.desc, sb.three.desc]).findn(q) >= 0:
				add.call("affix", "套装 · %s·%s" % [p, sb.name], "%s·%s" % [p, sb.name])
	# 机制（卡片标题）
	var mech_cards = [
		"一、先后手判定", "二、行动结算细节", "三、护盾体系", "四、连击体系",
		"五、熔炼与锻打", "六、精铸与分解", "七、叠加规则速查",
		"先手 后手 盾击 防御 药水 攻击 冷却", "护盾 上限 穿透", "连击 贯连 迅捷 连环 弓",
		"熔炼 锻打 词条 精华 消除", "精铸 分解 精粹 基准 区域效能",
	]
	var mech_anchor = ["一、先后手判定", "二、行动结算细节", "三、护盾体系", "四、连击体系",
		"五、熔炼与锻打", "六、精铸与分解", "七、叠加规则速查",
		"一、先后手判定", "三、护盾体系", "四、连击体系", "五、熔炼与锻打", "六、精铸与分解"]
	for i in range(mech_cards.size()):
		if mech_cards[i].findn(q) >= 0:
			add.call("mech", "机制 · %s" % mech_anchor[i], mech_anchor[i])
	# 天赋
	for tk in GameData.TALENT_KEYS:
		var td = GameData.TALENTS[tk]
		if ("%s %s" % [td.name, td.desc]).findn(q) >= 0:
			add.call("perk", "开局天赋 · %s — %s" % [td.name, td.desc], str(td.name))
	for pk in GameData.PERK_KEYS:
		var pd = GameData.PERKS[pk]
		if ("%s %s" % [pd.name, pd.desc]).findn(q) >= 0:
			add.call("perk", "天赋词条 · %s — %s" % [pd.name, pd.desc], str(pd.name))
	# 怪物与词条
	for ek in GameData.ENEMY_TYPES:
		var t = GameData.ENEMY_TYPES[ek]
		if str(t.name).findn(q) >= 0:
			add.call("monster", "怪物 · %s" % t.name, str(t.name))
	for mk in GameData.MONSTER_AFFIX_KEYS:
		var ma = GameData.MONSTER_AFFIXES[mk]
		if ("%s %s" % [ma.name, ma.desc]).findn(q) >= 0:
			add.call("monster", "怪物词条 · %s — %s" % [ma.name, ma.desc], str(ma.name))
	# 首领
	for ri in range(GameData.BIOMES.size()):
		var biome = GameData.BIOMES[ri]
		if ("%s %s" % [biome.boss.name, biome.name]).findn(q) >= 0:
			add.call("boss", "首领 · 区域 %d %s" % [ri + 1, biome.boss.name], str(biome.boss.name))
	# 事件
	for ev in GameData.EVENT_POOL:
		if ("%s %s" % [ev.title, ev.desc]).findn(q) >= 0:
			add.call("event", "事件 · %s" % ev.title, str(ev.title))
	# 元素与药水
	for elk in GameData.ELEMENT_KEYS:
		var ed = GameData.ELEMENTS[elk]
		if ("%s %s %s %s" % [ed.name, ed.item_word, ed.proc_name, ed.proc_desc]).findn(q) >= 0:
			add.call("element", "元素 · %s（触发「%s」）" % [ed.name, ed.proc_name], str(ed.name))
	if ("%s %s" % [GameData.POTION_INFO.name, GameData.POTION_INFO.desc]).findn(q) >= 0:
		add.call("element", "道具 · %s" % GameData.POTION_INFO.name, str(GameData.POTION_INFO.name))
	return out

func _codex_search_results(v: VBoxContainer, q: String) -> void:
	var results = _codex_search_index(q)
	_codex_line(v, "", "搜索「%s」：共 %d 条结果，点击条目跳转到对应位置。" % [q, results.size()], UITheme.C_GOLD)
	if results.is_empty():
		_codex_line(v, "", "没有找到相关内容。试试：连击 / 护盾 / 破甲 / 精铸 / 套装 / 怪物名……", UITheme.C_TEXT_DIM)
		return
	for res in results.slice(0, 40):
		var tabk: String = str(res.tab)
		var loc: String = str(res.locate)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var b = _btn(row, "▶ %s" % str(res.label), func():
			_current_data.erase("query")
			_current_data["tab"] = tabk
			_current_data["locate"] = loc
			_rebuild()
		, 480.0)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var tag = Label.new()
		tag.text = "〔%s〕" % CODEX_TAB_NAMES.get(tabk, tabk)
		tag.add_theme_font_size_override("font_size", 13)
		tag.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
		tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(tag)

## 滚动到第一个包含定位文本的标签并高亮
func _codex_scroll_to(scroll: ScrollContainer, root: Control, needle: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(scroll) or not is_instance_valid(root):
		return
	var lbl = _find_label_with(root, needle)
	if lbl == null:
		return
	lbl.add_theme_color_override("font_color", UITheme.C_GOLD)
	var y = lbl.get_global_rect().position.y - root.get_global_rect().position.y
	scroll.scroll_vertical = maxi(0, int(y) - 60)

func _find_label_with(node: Node, needle: String):
	if node is Label and str(node.text).findn(needle) >= 0:
		return node
	for ch in node.get_children():
		var found = _find_label_with(ch, needle)
		if found != null:
			return found
	return null

func _codex_card(parent: Control, head: String, head_color: Color) -> VBoxContainer:
	var card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", UITheme.flat_box(Color(0.08, 0.1, 0.16, 0.9), UITheme.C_BORDER, 1, 12, 10))
	parent.add_child(card)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var h = Label.new()
	h.text = head
	h.add_theme_font_size_override("font_size", 17)
	h.add_theme_color_override("font_color", head_color)
	v.add_child(h)
	return v

func _codex_line(parent: Control, key: String, text: String, color: Color = UITheme.C_TEXT_DIM) -> void:
	var l = Label.new()
	l.text = "%s：%s" % [key, text] if key != "" else text
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(560, 0)
	parent.add_child(l)

func _codex_equip(v: VBoxContainer) -> void:
	var entries = ItemCatalog.all_entries()
	_codex_line(v, "", "装备库共 %d 件：35 个基底 × 五大元素（焰火/寒冰/大地/闪电/森林），覆盖武器/铠甲/头盔/裤子/鞋/配饰六个部位。品级随区域与周目解锁；稀有度（普通<稀有<史诗<传说）决定数值与词条数。" % entries.size(), UITheme.C_TEXT)
	# 武器职业差异
	var wc_card = _codex_card(v, "武器职业差异（含先后手）", UITheme.C_GOLD)
	_codex_line(wc_card, "剑", "标准攻击无冷却；盾击先手且护盾 +50%（剑专属）；护盾在身时普攻 +20% — 攻防一体", UITheme.C_GREEN)
	_codex_line(wc_card, "斧", "伤害 ×1.7，命中附破甲（防御 -15%/层·叠 2 层），攻击后冷却 1 回合 — 配合蓄势/处决打一击流、克高防", UITheme.C_GREEN)
	_codex_line(wc_card, "弓", "每回合 2 箭起步、每箭 ×0.4 独立触发特效；「连击/贯连」词条仅对弓生效（连击上限 5、总攻击上限 10）— 连击/吸血流", UITheme.C_GREEN)

	# 按基底分组列出 100 件
	var last_base = ""
	var grade_stars = ["Ⅰ", "Ⅱ", "Ⅲ", "Ⅳ", "Ⅴ"]
	for entry in entries:
		if entry.base != last_base:
			last_base = entry.base
			var sec = Label.new()
			var trait_txt = ("　·　" + entry.trait_desc) if entry.trait_desc != "" else ""
			sec.text = "—— %s · %s · 品级%s%s ——" % [entry.base, entry.kind, grade_stars[entry.grade - 1], trait_txt]
			sec.add_theme_font_size_override("font_size", 15)
			sec.add_theme_color_override("font_color", UITheme.C_GOLD)
			v.add_child(sec)
			var bl = Label.new()
			bl.text = str(entry.lore[1])
			bl.add_theme_font_size_override("font_size", 13)
			bl.add_theme_color_override("font_color", Color("#c8b88a"))
			bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			bl.custom_minimum_size = Vector2(620, 0)
			v.add_child(bl)
		# 五行变体行：图标 + 名称 + 元素效果
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var icon = TextureRect.new()
		icon.texture = PixelArt.item_icon({ "family": entry.base, "element": entry.element })
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.stretch_mode = TextureRect.STRETCH_SCALE
		icon.custom_minimum_size = Vector2(24, 24)
		row.add_child(icon)
		var ed = GameData.ELEMENTS[entry.element]
		var nl = Label.new()
		nl.text = "%s 〔%s〕%s：%s" % [entry.name, ed.name, ed.proc_name, ed.proc_desc]
		nl.add_theme_font_size_override("font_size", 13)
		nl.add_theme_color_override("font_color", GameData.element_color(entry.element))
		nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(nl)

func _codex_affix(v: VBoxContainer) -> void:
	_codex_line(v, "", "稀有度词条：稀有 1 条 · 史诗 2 条 · 传说 3 条；熔炼史诗+装备可萃取词条精华，锻打到其他装备（上限 4 条）。同词条锻打可强化等级（最高 Lv.3，数值按等级倍增），详见「机制」页。", UITheme.C_TEXT)
	var kinds = { "off": "进攻词条", "def": "防御词条", "exp": "探索词条" }
	for kind in ["off", "def", "exp"]:
		var card = _codex_card(v, kinds[kind], Color("#bd6fff"))
		for ak in GameData.AFFIX_KEYS:
			var a = GameData.AFFIXES[ak]
			if a.kind == kind:
				_codex_line(card, a.name, a.desc)
	var build_card = _codex_card(v, "流派构筑示例", UITheme.C_GOLD)
	_codex_line(build_card, "吸血流", "弓（多箭）+ 吸血 + 迅捷 — 多段命中反复回血", UITheme.C_GREEN)
	_codex_line(build_card, "连击流", "弓 + 精准/残忍 + 迅捷 + 震慑 — 暴击叠箭，越打越多", UITheme.C_GREEN)
	_codex_line(build_card, "一击流", "斧 + 蓄势 + 处决 + 残忍 — 防御叠层后一斧爆发", UITheme.C_GREEN)
	_codex_line(build_card, "反伤坦克", "棘甲 + 石肤 + 守护 + 坚固套装 — 站着不动磨死敌人", UITheme.C_GREEN)
	_codex_line(build_card, "盾击流", "剑/疾盾 + 盾转攻 + 盾势 + 盾魂 — 先手盾击循环输出", UITheme.C_GREEN)
	_codex_line(build_card, "攻转盾", "攻转盾 + 盾魂 + 壁垒 — 一边输出一边把伤害变成护盾", UITheme.C_GREEN)

	var set_card = _codex_card(v, "套装效果（2/3 件同前缀装备激活）", UITheme.C_GOLD)
	for p in GameData.EQUIP_PREFIXES:
		if GameData.SET_BONUSES.has(p):
			var sb = GameData.SET_BONUSES[p]
			_codex_line(set_card, "%s·%s" % [p, sb.name], "2件: %s ／ 3件: %s" % [sb.two.desc, sb.three.desc])

# ------------------------------------------------------------
# 机制总览：先后手判定 / 行动结算 / 护盾 / 连击 / 词条互动（与代码逻辑一一对应）
# ------------------------------------------------------------
func _codex_mechanics(v: VBoxContainer) -> void:
	var C = GameData.COMBAT
	_codex_line(v, "", "本页总结所有效果的精确触发条件与相互作用判定，与游戏内部结算完全一致。", UITheme.C_TEXT)

	var order_card = _codex_card(v, "一、先后手判定（每回合的行动顺序）", UITheme.C_GOLD)
	_codex_line(order_card, "快动作", "攻击 / 防御 / 药水 都是「快动作」：只有〈先手〉风格的怪物会抢在你之前行动，其余怪物在你之后行动。", UITheme.C_GREEN)
	_codex_line(order_card, "慢动作", "盾击默认是「慢动作」：你按下盾击后，所有存活敌人会先行动一轮，然后盾击才结算。", Color("#ff9b8a"))
	_codex_line(order_card, "盾击转先手", "满足任意一条即可让盾击变成快动作：① 装备剑（剑专属特性）② 任意装备带「疾盾」词条 ③ 拥有「盾击大师」天赋。三者效果相同、不叠加。", UITheme.C_GREEN)
	_codex_line(order_card, "先手怪", "〈先手〉怪（灰狼/霜狼/火元素/幽魂）每回合都先于你的快动作行动；若你使用慢动作盾击，它们也只行动一次（不会动两轮）。")
	_codex_line(order_card, "坚守怪", "〈坚守〉怪（雪人/木乃伊/构造体）在第 1、4、7…回合举盾防御（获得护盾，该回合不攻击），其余回合正常攻击。")
	_codex_line(order_card, "盾击怪", "〈盾击〉怪（守护者/沙丘劫匪）每次攻击后额外获得护盾（攻击 ×0.6，随周目增强）。")
	_codex_line(order_card, "眩晕优先", "被「震慑」眩晕的怪物轮到行动时直接跳过（含先手怪的抢先行动）。")

	var act_card = _codex_card(v, "二、行动结算细节", UITheme.C_GOLD)
	_codex_line(act_card, "攻击", "剑：1 次全额攻击，无冷却，护盾在身时伤害 +%d%%。斧：1 次 ×%.2f 攻击并附加破甲（防御 -%d%%/层·最多 %d 层·持续 %d 回合），攻击后冷却 %d 回合。弓：%d 箭起步，每箭 ×%.2f，且每箭独立判定暴击与命中特效。" % [roundi(C.sword_shield_atk_pct * 100), C.axe_dmg_mult, roundi(C.axe_sunder_pct * 100), C.axe_sunder_stacks, C.axe_sunder_turns, C.axe_cooldown, C.bow_hits, C.bow_hit_mult])
	_codex_line(act_card, "盾击", "对单体造成 ×%.2f 伤害并获得护盾（%d + 防御×%.1f；剑获得的护盾 ×1.5），冷却 %d 回合；「盾势」词条每级冷却 -1（最低 1）。" % [C.skill_dmg_mult, C.base_skill_shield, C.skill_shield_def_mult, C.skill_cooldown])
	_codex_line(act_card, "防御", "获得护盾（%d + 防御×%.1f），冷却 %d 回合；带「蓄势」词条时每次防御 +1 层（最多 3 层），下次攻击每层 +30%% 伤害，攻击后清零。" % [C.base_def_shield, C.def_shield_def_mult, C.defend_cooldown])
	_codex_line(act_card, "药水", "恢复 40%% 最大生命，战斗内冷却 %d 回合；「药理」词条恢复 +15%%/级 且冷却 -1。" % C.potion_cooldown)
	_codex_line(act_card, "伤害公式", "你受到的伤害 = 敌攻 × 元素系数 − 防御×%.1f，再依次结算：闪避 → 完全格挡 → 减伤%% → 减半格挡 → 护盾吸收 → 扣血。" % C.def_dmg_reduction)
	_codex_line(act_card, "怪物防御", "怪物拥有防御属性：你的每次攻击/每箭都固定扣减其防御值（最低 1 伤害）。多段低伤打法受防御影响更大；灼烧无视防御与护盾。", Color("#ff9b8a"))

	var shield_card = _codex_card(v, "三、护盾体系（已削弱）", Color("#5ab4e8"))
	_codex_line(shield_card, "上限", "你的护盾总量永远不会超过最大生命 × %d%%，所有来源共用此上限（超出部分浪费）。" % roundi(C.shield_cap_pct * 100), Color("#ff9b8a"))
	_codex_line(shield_card, "来源", "防御（%d+防御×%.1f）/ 盾击（%d+防御×%.1f）/「岩盾」触发（%d+防御×%.1f）/「壁垒」开战 6/级 / 头盔+5 开战 8 / 长剑+5 击杀 5 / 攻转盾（伤害 15%%）。" % [C.base_def_shield, C.def_shield_def_mult, C.base_skill_shield, C.skill_shield_def_mult, int(C.earth_shield_base), C.earth_shield_def_mult])
	_codex_line(shield_card, "加成", "「盾魂」词条（+20%/级）、守护之魂天赋（+15%）、远古套装（+15%）只放大单次获取量，不能突破上限。")
	_codex_line(shield_card, "穿透", "怪物「穿甲」词条的攻击直接无视你的护盾；你的「雷击」元素触发同样无视敌方护盾。")
	_codex_line(shield_card, "敌方护盾", "怪物护盾随周目 +%d%%/周目，但总量永远低于其生命上限的 60%%（所有来源共用此上限）；先打掉护盾才会掉血（灼烧无视护盾直接烧血）。" % roundi(C.cycle_enemy_shield_mult * 100), Color("#ff9b8a"))

	var combo_card = _codex_card(v, "四、连击体系（仅弓生效）", Color("#bd6fff"))
	_codex_line(combo_card, "仅限弓", "连击体系只对弓生效：「连击」「贯连」词条只会出现在弓或配饰上，且装备剑/斧时这些词条无效。", Color("#ff9b8a"))
	_codex_line(combo_card, "连击数", "「连击」词条每级使弓多射一箭（全额 ×%.2f）；连击数（词条+贯连累计）上限 %d。" % [C.bow_hit_mult, C.multihit_cap])
	_codex_line(combo_card, "贯连", "「贯连」词条 / 「连击之道」天赋：本次行动每出现一次暴击，本场战斗连击数 +1（每级 +1，上限 +%d）。战斗结束清零。" % C.bow_combo_cap)
	_codex_line(combo_card, "迅捷", "「迅捷」词条是独立的概率追击（15%%/级，×%.1f 伤害，可连续触发），任何武器都可用，与连击数互不影响。" % C.extra_hit_dmg_mult)
	_codex_line(combo_card, "总上限", "单次行动的总攻击数（基础箭 + 连击 + 迅捷追击）不会超过 %d 次。" % C.max_attacks_per_action, Color("#ff9b8a"))
	_codex_line(combo_card, "连环", "「连环」词条让第 2 箭/追加攻击伤害 +25%/级，放大一切多段攻击。")
	_codex_line(combo_card, "触发关系", "每一箭/每次追击都独立判定：暴击、元素触发（%d%%+触发率加成）、震慑、燃焰、吸血——攻击段数越多，特效期望越高。" % roundi(C.elem_proc_chance))

	var forge_card = _codex_card(v, "五、熔炼与锻打（词条强化）", Color("#e8a8ff"))
	_codex_line(forge_card, "熔炼", "任何带词条的装备（背包或已穿戴）都可花费 %d 金销毁，由你【自选】其中一条词条萃取为「精华」（精华袋上限 %d）。" % [int(C.smelt_cost), C.essence_cap])
	_codex_line(forge_card, "锻打新词条", "把精华打到没有该词条的装备上 → 新增词条。词条上限随稀有度：稀有 2 条 / 史诗 3 条 / 传说 4 条。")
	_codex_line(forge_card, "同词条强化", "把精华打到已有同词条的装备上 → 词条升级（最高 Lv.%d）：数值词条按等级倍增（如连击 Lv.2 = 连击数 +2，精准 Lv.2 = 暴击率 +20%%）。" % GameData.AFFIX_MAX_LEVEL, UITheme.C_GREEN)
	_codex_line(forge_card, "消除词条", "可花费 %d 金移除装备上的一条词条（背包 → 消除词条），为锻打新词条腾出位置。" % int(C.purge_cost), UITheme.C_GREEN)
	_codex_line(forge_card, "不可强化", "开关型词条（蓄势/疾盾/盾转攻/攻转盾）只有开或关，无法升级。")
	_codex_line(forge_card, "限制", "连击体系词条（连击/贯连）只能锻打到弓或配饰上。", Color("#ff9b8a"))

	var refine_card = _codex_card(v, "六、精铸与分解（区域效能）", Color("#7ad9ff"))
	_codex_line(refine_card, "问题", "区域越深怪物越强，老装备的基础数值相对越来越弱。精铸制度让心爱的史诗/传说装备保值。", UITheme.C_TEXT)
	_codex_line(refine_card, "分解", "背包中的装备可分解为「精粹」：普通 1 · 稀有 3 · 史诗 8 · 传说 20。")
	_codex_line(refine_card, "区域基准", "每件装备带有出厂时的「区域基准」：该区域下此品质/品级装备应有的标准基础数值。")
	_codex_line(refine_card, "精铸", "每消耗 %d 精粹，把史诗/传说装备的基准区域 +1（如区域 16→17），需多次精铸才能逐级追平你到达过的最高区域基准（周目也计入：每周目相当于区域 +5）。强化等级与词条完全保留，最终输出 = 新基准 × (1 + 强化加成)。" % int(C.refine_cost), UITheme.C_GREEN)

	var stack_card = _codex_card(v, "七、叠加规则速查", UITheme.C_GOLD)
	_codex_line(stack_card, "可叠加", "同名词条出现在不同装备上时数值相加（如两件「精准」= 暴击率 +20%）；天赋、套装、基底特性与词条全部相加。")
	_codex_line(stack_card, "百分比", "攻击/防御/生命的百分比加成（穿透、套装、天赋）先合计再统一乘算一次。")
	_codex_line(stack_card, "元素", "武器克制敌人元素 ×1.3（符文 3 件套翻倍加成），被克 ×0.8；铠甲元素同理影响你的受击。")

func _codex_perks(v: VBoxContainer) -> void:
	_codex_line(v, "", "通关区域 2 与区域 5 后，各可从随机三条天赋词条中选择一条（周目循环中同样）。词条上限 %d 条，超出需选择替换。开局另有 %d 点天赋点分配给生命/力量/坚韧/敏捷。" % [GameData.PERK_CAP, GameData.TALENT_POINTS], UITheme.C_TEXT)
	var t_card = _codex_card(v, "开局天赋点（新存档分配，固定 %d 点）" % GameData.TALENT_POINTS, UITheme.C_GOLD)
	for tk in GameData.TALENT_KEYS:
		var td = GameData.TALENTS[tk]
		_codex_line(t_card, td.name, td.desc)
	var p_card = _codex_card(v, "天赋词条池（区域 2 / 区域 5 通关后三选一，上限 %d 条）" % GameData.PERK_CAP, Color("#e8a8ff"))
	for pk in GameData.PERK_KEYS:
		var pd = GameData.PERKS[pk]
		var owned = "（已拥有）" if GameState.perks.has(pk) else ""
		_codex_line(p_card, pd.name + owned, pd.desc, UITheme.C_GREEN if GameState.perks.has(pk) else UITheme.C_TEXT_DIM)

func _codex_element(v: VBoxContainer) -> void:
	_codex_line(v, "", "元素克制：闪电克森林 · 森林克大地 · 大地克寒冰 · 寒冰克焰火 · 焰火克闪电。武器克制敌人时伤害 ×1.3，被克 ×0.8；铠甲元素同理影响受击。", UITheme.C_TEXT)
	for ek in GameData.ELEMENT_KEYS:
		var ed = GameData.ELEMENTS[ek]
		var beats = GameData.ELEMENTS[ed.beats]
		var card = _codex_card(v, "%s（%s）" % [ed.name, ed.item_word], GameData.element_color(ek))
		_codex_line(card, "克制", "%s（克制时伤害 ×1.3）" % beats.name, UITheme.C_GREEN)
		_codex_line(card, "触发", "「%s」：%s（每次命中 22%% 概率，可由词条/套装提升）" % [ed.proc_name, ed.proc_desc], Color("#9fd6ff"))
	_codex_potion(v)

func _codex_monsters(v: VBoxContainer) -> void:
	_codex_line(v, "", "每种怪物有自带能力，并会随机叠加额外词条形成大量变种（区域/精英/首领/周目越高词条越多）。进入战斗节点前可侦察预览。", UITheme.C_TEXT)
	var afx_card = _codex_card(v, "怪物词条一览", Color("#e8a8ff"))
	for ak in GameData.MONSTER_AFFIX_KEYS:
		var a = GameData.MONSTER_AFFIXES[ak]
		_codex_line(afx_card, a.name, a.desc)
	var style_card = _codex_card(v, "怪物战斗风格（先后手）", Color("#8aeb9a"))
	for sk in ["feral", "guard", "bash"]:
		var sd = GameData.ENEMY_STYLES[sk]
		_codex_line(style_card, sd.name, sd.desc)
	var cb_card = _codex_card(v, "周目大 Boss（区域 5 通关后的压轴战）", Color("#f4c454"))
	_codex_line(cb_card, "", "每通关区域 5 后，会有一只远古噩梦压轴登场，击败后才进入新周目。前四周目按顺序出现，第五周目起随机其一；强度明显高于区域 Boss 并随周目成长。击败掉落史诗:传奇 = 6:4。", UITheme.C_TEXT)
	for cb in GameData.CYCLE_BOSSES:
		_codex_line(cb_card, str(cb.name), "压轴 Boss · 特性：%s" % "、".join(cb.get("traits", [])))
	for ri in range(GameData.BIOMES.size()):
		var biome = GameData.BIOMES[ri]
		var sec = Label.new()
		sec.text = "—— 区域 %d · %s（元素：%s）——" % [ri + 1, biome.name, GameData.element_name(str(biome.get("element", "")))]
		sec.add_theme_font_size_override("font_size", 15)
		sec.add_theme_color_override("font_color", UITheme.C_GOLD)
		sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sec)
		for key in biome.enemy_keys:
			var t = GameData.get_enemy_type(key)
			var lore = LoreData.get_monster_lore(key)
			var base_hp = roundi((20.0 + ri * 16.0) * t.hp_mult)
			var base_atk = roundi((10.0 + ri * 7.0) * t.atk_mult)
			var base_def = roundi(2.0 + ri * 2.2)
			var card = _codex_card(v, t.name, UITheme.C_TEXT)
			_codex_line(card, "数值", "基准生命 %d · 基准攻击 %d · 基准防御 %d（精英 ×2.2 生命/×1.3 攻击/×1.3 防御；每周目相当于区域 +5 继续成长——新周目区域 1 强于上周目区域 5）" % [base_hp, base_atk, base_def], Color("#9fd6ff"))
			var st = GameData.get_enemy_style(key)
			if str(st.get("name", "")) != "":
				_codex_line(card, "风格", "%s — %s" % [st.name, st.desc], Color("#8aeb9a"))
			var innate = str(t.get("innate", ""))
			if innate != "":
				var ia = GameData.get_monster_affix(innate)
				_codex_line(card, "自带", "%s — %s" % [ia.name, ia.desc], Color("#e8a8ff"))
			_codex_line(card, "外观", lore.appearance)
			_codex_line(card, "性格", lore.personality)
			_codex_line(card, "来历", lore.origin)

func _codex_bosses(v: VBoxContainer) -> void:
	var trait_names = { "summon": "召唤从者", "shield_phase": "护盾阶段", "rage": "濒死狂暴", "heal": "引导自疗", "heavy": "蓄力重击" }
	for ri in range(GameData.BIOMES.size()):
		var biome = GameData.BIOMES[ri]
		var boss = biome.boss
		var lore = LoreData.get_boss_lore(ri)
		var hp_est = roundi((20.0 + ri * 16.0) * 5.5)
		var atk_est = roundi((10.0 + ri * 7.0) * 1.5)
		var card = _codex_card(v, "区域 %d 首领 · %s" % [ri + 1, boss.name], UITheme.C_GOLD)
		var tnames = []
		for tr in boss.traits:
			tnames.append(trait_names.get(tr, tr))
		_codex_line(card, "数值", "生命约 %d · 攻击约 %d（另随机附带 2 条怪物词条；每周目再增强）" % [hp_est, atk_est], Color("#9fd6ff"))
		_codex_line(card, "技能", "、".join(tnames), Color("#ff9b8a"))
		_codex_line(card, "战法", lore.tactics, Color("#ff9b8a"))
		_codex_line(card, "外观", lore.appearance)
		_codex_line(card, "性格", lore.personality)
		_codex_line(card, "来历", lore.origin)

func _codex_events(v: VBoxContainer) -> void:
	_codex_line(v, "", "地图上的 ? 节点会随机触发以下事件（不会与最近遇到的重复）：", UITheme.C_TEXT)
	for ev in GameData.EVENT_POOL:
		var card = _codex_card(v, ev.title, Color("#9fd6ff"))
		_codex_line(card, "", ev.desc)
		for ch in ev.choices:
			_codex_line(card, "选项", str(ch.get("label", "")), UITheme.C_TEXT_DIM)

func _codex_potion(v: VBoxContainer) -> void:
	var card = _codex_card(v, GameData.POTION_INFO.name, Color("#8aeb9a"))
	_codex_line(card, "效果", GameData.POTION_INFO.desc, UITheme.C_GREEN)
	_codex_line(card, "来历", GameData.POTION_INFO.lore)

# ------------------------------------------------------------
# 关卡预览：进入战斗节点前观察怪物数量与状况
# ------------------------------------------------------------
func _build_node_preview(c: VBoxContainer) -> void:
	var node: Dictionary = _current_data.get("node", {})
	var type_name: String = GameData.NODE_TYPE_NAMES.get(node.get("type", 0), "战斗")
	_title(c, "侦 察 情 报 · %s" % type_name)
	var foes: Array = node.get("foes", [])
	if foes.is_empty():
		_text(c, "前方情况不明……", 15, UITheme.C_TEXT_DIM)
	else:
		_text(c, "前方有 %d 个敌人（数值为实际遭遇值）：" % foes.size(), 15, UITheme.C_TEXT_DIM)
	for foe in foes:
		var st = CombatManager.enemy_stats_for(foe, GameState.region, GameState.cycle)
		var fname: String
		var head_color = UITheme.C_TEXT
		if foe.get("boss", false):
			fname = GameData.get_biome(GameState.region).boss.name
			head_color = UITheme.C_GOLD
		else:
			fname = GameData.get_enemy_type(str(foe.key)).name
			if foe.get("elite", false):
				fname = "精英" + fname
				head_color = Color("#bd6fff")
		var elem = str(foe.get("element", ""))
		var card = _codex_card(c, "〔%s〕%s" % [GameData.element_name(elem), fname], head_color)
		_codex_line(card, "数值", "生命 %d · 攻击 %d · 防御 %d" % [st.hp, st.atk, st.get("def", 0)], Color("#9fd6ff"))
		if not foe.get("boss", false):
			var style = GameData.get_enemy_style(str(foe.key))
			if str(style.get("name", "")) != "":
				_codex_line(card, "风格", "%s — %s" % [style.name, style.desc], Color("#8aeb9a"))
		var afx: Array = foe.get("affixes", [])
		if afx.size() > 0:
			var parts = []
			for a in afx:
				var ad = GameData.get_monster_affix(a)
				parts.append("%s(%s)" % [ad.name, ad.desc])
			_codex_line(card, "词条", " · ".join(parts), Color("#e8a8ff"))
		if foe.get("boss", false):
			var lore = LoreData.get_boss_lore(GameState.region)
			_codex_line(card, "战法", lore.tactics, Color("#ff9b8a"))
		# 五行克制提示
		var stats = GameState.get_player_stats()
		var wm = GameData.element_mult(str(stats.get("weapon_element", "")), elem)
		if wm > 1.0:
			_codex_line(card, "克制", "你的武器元素克制它（伤害 ×%.1f）" % wm, UITheme.C_GREEN)
		elif wm < 1.0:
			_codex_line(card, "克制", "你的武器元素被它克制（伤害 ×%.1f）" % wm, Color("#cf8a6a"))
	var r = _btn_row(c)
	_btn(r, "进 入 战 斗", func():
		close_all()
		GameState.enter_node(node)
	, 180.0)
	_btn(r, "再 想 想", close, 140.0)

# ------------------------------------------------------------
# 锻打消除：花费 40 金移除装备上的一条词条（腾位置换新词条）
# ------------------------------------------------------------
func _build_purge(c: VBoxContainer) -> void:
	var cost = int(GameData.COMBAT["purge_cost"])
	_title(c, "锻 打 消 除 词 条", Color("#cf8a6a"))
	_text(c, "花费 %d 金币移除一条已有词条（不可恢复），为锻打新词条腾出位置。金币 %d" % [cost, GameState.gold], 14, UITheme.C_TEXT_DIM)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 360)
	c.add_child(scroll)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	var shown = 0
	for slot in GameData.EQUIP_SLOTS:
		var it = GameState.equipment.get(slot)
		if it and it.affixes.size() > 0:
			shown += 1
			_purge_item_rows(inner, it, "已装备·%s" % GameData.slot_name(slot), { "kind": "equip", "slot": slot }, cost)
	for i in range(GameState.bag.size()):
		var it = GameState.bag[i]
		if it.affixes.size() > 0:
			shown += 1
			_purge_item_rows(inner, it, "背包", { "kind": "bag", "index": i }, cost)
	if shown == 0:
		_text(inner, "（没有带词条的装备）", 14, UITheme.C_TEXT_DIM)

	var r = _btn_row(c)
	_btn(r, "关闭", close, 140.0)

func _purge_item_rows(parent: Control, it: Dictionary, tag: String, target: Dictionary, cost: int) -> void:
	var head = Label.new()
	head.text = "[%s] %s" % [tag, it.get("name", it.base_name)]
	head.add_theme_font_size_override("font_size", 14)
	head.add_theme_color_override("font_color", UITheme.rarity_color(it.rarity))
	parent.add_child(head)
	for a in it.affixes:
		var ak = str(a)
		var ad = GameData.AFFIXES.get(ak, {})
		var lv = GameState.affix_level_of(it, ak)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		parent.add_child(row)
		var l = Label.new()
		l.text = "　◆ %s%s · %s" % [ad.get("name", ak), (" Lv.%d" % lv) if lv > 1 else "", GameData.affix_desc(ak, lv)]
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(360, 0)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var b = _btn(row, "消除(%d金)" % cost, func():
			if GameState.purge_affix(target, ak):
				_rebuild()
		, 110.0)
		b.disabled = GameState.gold < cost

# ------------------------------------------------------------
# 天赋词条三选一（通关区域 2 / 区域 5 后，上限 5 条）
# ------------------------------------------------------------
func _build_perk_choice(c: VBoxContainer) -> void:
	_title(c, "天 赋 觉 醒", Color("#e8a8ff"))
	_text(c, "首领的力量涌入体内——选择一条天赋词条（永久生效，可与装备词条配合）：", 15)
	if GameState.perks.size() >= GameData.PERK_CAP:
		_text(c, "※ 词条已达上限 %d 条，选择新词条后需要替换一条旧词条" % GameData.PERK_CAP, 13, Color("#cf8a6a"))
	var offers: Array = _current_data.get("offers", [])
	for pk in offers:
		var pd = GameData.get_perk(str(pk))
		var key = str(pk)
		var row = _btn_row(c)
		var b = _btn(row, "%s — %s" % [pd.name, pd.desc], func():
			close_all()
			GameState.choose_perk(key)
		, 420.0)
		b.add_theme_color_override("font_color", Color("#e8a8ff"))
	if GameState.perks.size() > 0:
		var owned = []
		for p in GameState.perks:
			owned.append(GameData.get_perk(p).name)
		_text(c, "已有天赋（%d/%d）：%s" % [GameState.perks.size(), GameData.PERK_CAP, "、".join(owned)], 13, UITheme.C_TEXT_DIM)
	var r = _btn_row(c)
	_btn(r, "都不需要（跳过）", func():
		close_all()
		GameState.skip_perk()
	, 200.0)

# ------------------------------------------------------------
# 天赋词条替换（上限 5 条时选了新词条）
# ------------------------------------------------------------
func _build_perk_replace(c: VBoxContainer) -> void:
	var new_key = str(_current_data.get("new", ""))
	var nd = GameData.get_perk(new_key)
	_title(c, "替 换 天 赋 词 条", Color("#e8a8ff"))
	_text(c, "新词条：「%s」 — %s" % [nd.name, nd.desc], 15, Color("#e8a8ff"))
	_text(c, "词条已满 %d 条，选择一条旧词条让位：" % GameData.PERK_CAP, 14, UITheme.C_TEXT_DIM)
	for pk in GameState.perks:
		var od = GameData.get_perk(str(pk))
		var old_key = str(pk)
		var row = _btn_row(c)
		_btn(row, "替换「%s」 — %s" % [od.name, od.desc], func():
			close_all()
			GameState.replace_perk(old_key, new_key)
		, 420.0)
	var r = _btn_row(c)
	_btn(r, "放弃新词条", func():
		close_all()
		GameState.skip_perk()
	, 180.0)

# ------------------------------------------------------------
# 新远征设置：角色起名 + 天赋点分配（固定 10 点）
# ------------------------------------------------------------
func _build_new_run_setup(c: VBoxContainer) -> void:
	var region = int(_current_data.get("region", 0))
	var biome = GameData.get_biome(region)
	_title(c, "远 征 准 备")
	_text(c, "目的地：区域 %d · %s" % [region + 1, biome.name], 15, UITheme.C_TEXT_DIM)

	# 角色名输入
	var name_row = HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 10)
	c.add_child(name_row)
	var name_lbl = Label.new()
	name_lbl.text = "冒险者之名："
	name_lbl.add_theme_font_size_override("font_size", 16)
	name_row.add_child(name_lbl)
	var name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(220, 36)
	name_edit.max_length = 12
	name_edit.placeholder_text = "冒险者"
	name_edit.text = str(_current_data.get("name", ""))
	name_edit.text_changed.connect(func(t): _current_data["name"] = t)
	name_row.add_child(name_edit)

	# 天赋点分配
	var talents: Dictionary = _current_data.get("talents", {})
	if talents.is_empty():
		for k in GameData.TALENT_KEYS:
			talents[k] = 0
		_current_data["talents"] = talents
	var used = 0
	for k in GameData.TALENT_KEYS:
		used += int(talents.get(k, 0))
	var remain = GameData.TALENT_POINTS - used

	_text(c, "分配天赋点（剩余 %d / %d）" % [remain, GameData.TALENT_POINTS], 16, UITheme.C_GOLD)
	for k in GameData.TALENT_KEYS:
		var tk = k
		var td = GameData.TALENTS[k]
		var row = HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 10)
		c.add_child(row)
		var lab = Label.new()
		lab.text = "%s（%s）" % [td.name, td.desc]
		lab.add_theme_font_size_override("font_size", 15)
		lab.custom_minimum_size = Vector2(260, 0)
		row.add_child(lab)
		var minus = _btn(row, "−", func():
			if int(talents.get(tk, 0)) > 0:
				talents[tk] = int(talents[tk]) - 1
				_rebuild()
		, 44.0)
		minus.disabled = int(talents.get(tk, 0)) <= 0
		var v = Label.new()
		v.text = str(int(talents.get(tk, 0)))
		v.add_theme_font_size_override("font_size", 18)
		v.add_theme_color_override("font_color", UITheme.C_GOLD)
		v.custom_minimum_size = Vector2(34, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(v)
		var plus = _btn(row, "＋", func():
			if remain > 0:
				talents[tk] = int(talents.get(tk, 0)) + 1
				_rebuild()
		, 44.0)
		plus.disabled = remain <= 0

	_text(c, "※ 天赋点伴随整个存档，无法重新分配——想清楚再出发！", 13, Color("#cf8a6a"))
	var r = _btn_row(c)
	var start = _btn(r, "踏 上 远 征", func():
		close_all()
		GameState.start_new_game(region, str(_current_data.get("name", "")), talents)
	, 200.0)
	if remain > 0:
		start.text = "踏上远征（还剩 %d 点未分配）" % remain
		start.custom_minimum_size = Vector2(280, 42)
	_btn(r, "返回", func():
		SignalBus.show_modal.emit("region_select", { "in_run": false })
	, 120.0)

# ------------------------------------------------------------
# 熔炼：收费 40 金，随机萃取一条词条（不可挑选）
# ------------------------------------------------------------
func _build_smelt(c: VBoxContainer) -> void:
	# 支持背包装备（index）与已穿戴装备（equip_slot）两种来源
	var eslot = str(_current_data.get("equip_slot", ""))
	var it
	var idx = int(_current_data.get("index", -1))
	if eslot != "":
		it = GameState.equipment.get(eslot)
	else:
		if idx < 0 or idx >= GameState.bag.size():
			close()
			return
		it = GameState.bag[idx]
	if it == null:
		close()
		return
	var cost = int(GameData.COMBAT["smelt_cost"])
	_title(c, "熔 炼 装 备", Color("#e8a8ff"))
	_item_card(c, it, true)
	_text(c, "装备将被销毁，由你【自选】其中一条词条萃取为精华（费用 %d 金币）：" % cost, 14, Color("#cf8a6a"))
	_text(c, "精华袋 %d/%d   ·   金币 %d" % [GameState.essences.size(), GameData.COMBAT["essence_cap"], GameState.gold], 13, UITheme.C_TEXT_DIM)
	for a in it.affixes:
		var ad = GameData.AFFIXES.get(a, {})
		var akey = str(a)
		var r = _btn_row(c)
		var b = _btn(r, "萃取「%s」（%d 金币）" % [ad.get("name", akey), cost], func():
			var ok = GameState.smelt_equipped(eslot, akey) if eslot != "" else GameState.smelt_bag_item(idx, akey)
			if ok:
				close()
		, 300.0)
		b.disabled = GameState.gold < cost
		b.tooltip_text = str(ad.get("desc", ""))
	var r2 = _btn_row(c)
	_btn(r2, "取消", close, 140.0)

# ------------------------------------------------------------
# 锻打：把词条精华赋予一件装备
# ------------------------------------------------------------
func _build_forge(c: VBoxContainer) -> void:
	var ei = int(_current_data.get("essence_idx", -1))
	if ei < 0 or ei >= GameState.essences.size():
		close()
		return
	var es = GameState.essences[ei]
	var ad = GameData.AFFIXES.get(es.affix, {})
	_title(c, "锻 打 词 条", Color("#e8a8ff"))
	_text(c, "精华：「%s」 — %s" % [ad.get("name", es.affix), ad.get("desc", "")], 15, Color("#e8a8ff"))
	var cost = GameState.get_forge_cost()
	_text(c, "选择目标装备（花费 %d 金币 · 词条上限随稀有度：稀有2/史诗3/传说4 · 同词条=强化）：" % cost, 14, UITheme.C_TEXT_DIM)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 320)
	c.add_child(scroll)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	for slot in GameData.EQUIP_SLOTS:
		var it = GameState.equipment.get(slot)
		if not it:
			continue
		_forge_target_row(inner, it, "已装备·%s" % GameData.slot_name(slot), es, ei, { "kind": "equip", "slot": slot }, cost)
	for i in range(GameState.bag.size()):
		_forge_target_row(inner, GameState.bag[i], "背包", es, ei, { "kind": "bag", "index": i }, cost)

	var r = _btn_row(c)
	_btn(r, "取消", close, 140.0)

func _forge_target_row(parent: Control, it: Dictionary, tag: String, es: Dictionary, ei: int, target: Dictionary, cost: int) -> void:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var rc = UITheme.rarity_color(it.rarity)
	var l = Label.new()
	var chk = GameState.can_forge_to(it, str(es.affix))
	var note = ""
	if it.affixes.has(es.affix):
		var cur_lv = GameState.affix_level_of(it, str(es.affix))
		note = "（已有该词条 Lv.%d%s）" % [cur_lv, ("，可强化至 Lv.%d" % int(chk.to_lv)) if chk.ok else ""]
	l.text = "[%s] %s（词条 %d/%d）%s" % [tag, it.get("name", it.base_name), it.affixes.size(), GameData.affix_cap(int(it.get("rarity", 0))), note]
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", rc)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var btn_text = "强化" if (it.affixes.has(es.affix) and chk.ok) else "锻打"
	var b = _btn(row, btn_text, func():
		if GameState.forge_essence(ei, target):
			close()
	, 90.0)
	b.disabled = not chk.ok or GameState.gold < cost
	if not chk.ok:
		b.tooltip_text = str(chk.why)
	elif GameState.gold < cost:
		b.tooltip_text = "金币不足"
	elif it.affixes.has(es.affix):
		b.tooltip_text = "同词条强化：%s" % GameData.affix_desc(str(es.affix), int(chk.to_lv))
