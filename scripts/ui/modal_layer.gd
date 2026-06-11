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
const OVERLAY_TYPES = ["bag", "equip_detail", "help", "codex", "stats", "smelt", "forge"]

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
# 背包
# ------------------------------------------------------------
func _build_bag(c: VBoxContainer) -> void:
	_title(c, "背 包")
	_text(c, "金币: %d   ·   容量 %d/%d   ·   药水 ×%d" % [GameState.gold, GameState.bag.size(), GameData.PLAYER_BASE["bag_capacity"], GameState.potions], 15, UITheme.C_TEXT_DIM)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 380)
	c.add_child(scroll)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 8)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	# 已装备
	var eq_lbl = Label.new()
	eq_lbl.text = "— 已装备 —"
	eq_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	eq_lbl.add_theme_font_size_override("font_size", 14)
	inner.add_child(eq_lbl)
	for slot in ["weapon", "armor", "accessory"]:
		var it = GameState.equipment.get(slot)
		if not it:
			continue
		_item_card(inner, it, true)
		var r = HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		inner.add_child(r)
		var s = slot
		_btn(r, "详情", func():
			SignalBus.show_modal.emit("equip_detail", { "slot": s, "item": GameState.equipment[s] })
		, 80.0)
		if it.level < GameData.COMBAT["max_upgrade_level"]:
			var cost = EquipmentModifier.get_upgrade_cost(it, GameState.region)
			var up = _btn(r, "强化 (%d金)" % cost, func():
				if GameState.upgrade_equipped(s):
					Sfx.play("upgrade")
				else:
					SignalBus.show_toast.emit("金币不足")
			, 130.0)
			up.tooltip_text = EquipmentModifier.format_upgrade_preview(it)
			up.disabled = GameState.gold < cost
		else:
			_text(r, "已满级 +5", 14, UITheme.C_GOLD, false, 100.0)

	# 背包物品
	var bag_lbl = Label.new()
	bag_lbl.text = "— 背包物品 —"
	bag_lbl.add_theme_color_override("font_color", UITheme.C_TEXT_DIM)
	bag_lbl.add_theme_font_size_override("font_size", 14)
	inner.add_child(bag_lbl)
	if GameState.bag.is_empty():
		_text(inner, "(空空如也)", 14, UITheme.C_TEXT_DIM)
	for i in range(GameState.bag.size()):
		var it = GameState.bag[i]
		_item_card(inner, it, true)
		var r = HBoxContainer.new()
		r.add_theme_constant_override("separation", 8)
		inner.add_child(r)
		var idx = i
		_btn(r, "装备", func():
			GameState.equip_item(GameState.bag[idx])
			Sfx.play("equip")
		, 90.0)
		if it.level < GameData.COMBAT["max_upgrade_level"]:
			var cost = EquipmentModifier.get_upgrade_cost(it, GameState.region)
			var up = _btn(r, "强化 (%d金)" % cost, func():
				if GameState.upgrade_bag_item(idx):
					Sfx.play("upgrade")
				else:
					SignalBus.show_toast.emit("金币不足")
			, 130.0)
			up.tooltip_text = EquipmentModifier.format_upgrade_preview(it)
			up.disabled = GameState.gold < cost
		var val = EquipmentModifier.get_sell_value(it)
		_btn(r, "出售 (%d金)" % val, func():
			GameState.sell_bag_item(idx)
			Sfx.play("coin")
		, 130.0)
		# 熔炼：史诗+且有词条的装备可萃取词条精华
		if GameState.can_smelt(it):
			var sm = _btn(r, "熔炼", func():
				SignalBus.show_modal.emit("smelt", { "index": idx })
			, 80.0)
			sm.tooltip_text = "销毁该装备，自选萃取其一条词条为精华（可锻打到其他装备上）"

	# 词条精华（熔炼所得，可锻打）
	var ess_lbl = Label.new()
	ess_lbl.text = "— 词条精华 %d/%d（锻打费用 %d 金）—" % [GameState.essences.size(), GameData.COMBAT["essence_cap"], GameState.get_forge_cost()]
	ess_lbl.add_theme_color_override("font_color", Color("#e8a8ff"))
	ess_lbl.add_theme_font_size_override("font_size", 14)
	inner.add_child(ess_lbl)
	if GameState.essences.is_empty():
		_text(inner, "(熔炼史诗或传说装备可获得词条精华)", 13, UITheme.C_TEXT_DIM)
	for i in range(GameState.essences.size()):
		var es = GameState.essences[i]
		var ad = GameData.AFFIXES.get(es.affix, {})
		var er = HBoxContainer.new()
		er.add_theme_constant_override("separation", 8)
		inner.add_child(er)
		var el = Label.new()
		el.text = "◈ %s — %s（萃取自 %s）" % [ad.get("name", es.affix), ad.get("desc", ""), es.get("from", "?")]
		el.add_theme_font_size_override("font_size", 13)
		el.add_theme_color_override("font_color", Color("#e8a8ff"))
		el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		el.custom_minimum_size = Vector2(360, 0)
		el.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		er.add_child(el)
		var ei = i
		_btn(er, "锻打", func():
			SignalBus.show_modal.emit("forge", { "essence_idx": ei })
		, 80.0)

	var brow = _btn_row(c)
	_btn(brow, "关闭 [Esc]", close, 160.0)

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
		"◆ 地图自由探索：所有节点随时可进，收集完资源再挑战首领（或直奔首领）。",
		"◆ 战斗节点可先侦察：怪物数量、词条、精确数值一目了然。",
		"◆ 战斗：攻击[1] · 盾击[2]（冷却3）· 防御[3]（冷却2）· 药水[4]（冷却3）。",
		"◆ 武器差异：剑无冷却 / 斧 ×1.55 攻击后冷却1回合 / 弓每回合两箭。",
		"◆ 五行：金克木·木克土·土克水·水克火·火克金，克制伤害 ×1.3，各有触发效果。",
		"◆ 怪物有自带能力与随机词条（穿甲/嗜血/迅捷/荆棘…），点击敌人可换目标。",
		"◆ 装备：同前缀 2/3 件成套装；+3 被动 +5 独特；强化投入出售返还 50%。",
		"◆ 熔炼：史诗+装备可萃取词条精华，锻打到其他装备上（背包内操作）。",
		"◆ 掉落：普通怪爆率低，精英必掉稀有+，首领必掉史诗+；周目越高越好。",
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
	_title(c, "装 备 详 情")
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

	if item.level < GameData.COMBAT["max_upgrade_level"]:
		var cost = EquipmentModifier.get_upgrade_cost(item, GameState.region)
		var preview = EquipmentModifier.format_upgrade_preview(item)
		if preview != "":
			_text(c, "强化预览：%s" % preview, 14, UITheme.C_GREEN)
		var up = _btn(r, "强化 (%d 金币)" % cost, func():
			if GameState.upgrade_equipped(slot):
				Sfx.play("upgrade")
				_current_data["item"] = GameState.equipment[slot]
			else:
				SignalBus.show_toast.emit("金币不足")
		, 180.0)
		up.disabled = GameState.gold < cost
	else:
		_text(c, "已强化至满级 +5", 15, UITheme.C_GOLD)
	_btn(r, "关闭", close, 120.0)

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
			detail.text = "%s区域 %d · %s\n金币 %d · 击杀 %d · %s" % [cyc, info.region + 1, biome.name, info.gold, info.kills, info.timestamp]
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
			close_all()
			if in_run:
				GameState.switch_region(ri)
			else:
				GameState.start_new_game(ri)
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
	_title(c, "我 的 属 性")
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

	# 五行与周目
	var we = str(total.get("weapon_element", ""))
	var ae = str(total.get("armor_element", ""))
	var elem_parts = []
	if we != "":
		elem_parts.append("武器五行〔%s〕克%s" % [GameData.element_name(we), GameData.element_name(GameData.ELEMENTS[we].beats)])
	if ae != "":
		elem_parts.append("护甲五行〔%s〕" % GameData.element_name(ae))
	if GameState.cycle > 0:
		elem_parts.append("强化 %d 周目（怪物 +%d%% 生命/+%d%% 攻击）" % [GameState.cycle, roundi(GameState.cycle * 55.0), roundi(GameState.cycle * 45.0)])
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

	_text(c, "战斗公式：防御每点减伤 0.8 · 盾击护盾 = 6 + 防御×1.2 · 防御姿态护盾 = 7 + 防御×1.6", 12, UITheme.C_TEXT_DIM)

	var r = _btn_row(c)
	_btn(r, "关闭 [Esc]", close, 150.0)

# ------------------------------------------------------------
# 图鉴
# ------------------------------------------------------------
func _build_codex(c: VBoxContainer) -> void:
	_title(c, "远 征 图 鉴")
	var tab: String = _current_data.get("tab", "equip")

	# 分页按钮
	var tabs = _btn_row(c)
	var tab_defs = [["equip", "装备库"], ["affix", "词条·套装"], ["monster", "怪物"], ["boss", "首领"], ["event", "事件"], ["element", "五行·药水"]]
	for td in tab_defs:
		var tkey = td[0]
		var b = _btn(tabs, td[1], func():
			_current_data["tab"] = tkey
			_rebuild()
		, 100.0)
		if tkey == tab:
			b.add_theme_color_override("font_color", UITheme.C_GOLD)
			b.add_theme_stylebox_override("normal", UITheme.flat_box(Color("#2f3a58"), UITheme.C_GOLD, 2, 8, 6))

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 420)
	c.add_child(scroll)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(v)

	match tab:
		"equip":   _codex_equip(v)
		"affix":   _codex_affix(v)
		"monster": _codex_monsters(v)
		"boss":    _codex_bosses(v)
		"event":   _codex_events(v)
		"element": _codex_element(v)

	var r = _btn_row(c)
	_btn(r, "关闭 [Esc]", close, 150.0)

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
	_codex_line(v, "", "装备库共 %d 件：20 个基底 × 金木水火土五行。品级随区域与周目解锁；稀有度（普通<稀有<史诗<传说）决定数值与词条数。" % entries.size(), UITheme.C_TEXT)
	# 武器职业差异
	var wc_card = _codex_card(v, "武器职业差异", UITheme.C_GOLD)
	_codex_line(wc_card, "剑", "标准攻击，无冷却 — 均衡", UITheme.C_GREEN)
	_codex_line(wc_card, "斧", "伤害 ×1.55，攻击后冷却 1 回合 — 配合蓄势/处决打一击流", UITheme.C_GREEN)
	_codex_line(wc_card, "弓", "每回合两箭、每箭 ×0.62 且独立触发命中特效 — 配合吸血/震慑/燃焰打连击流", UITheme.C_GREEN)

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
	_codex_line(v, "", "稀有度词条：稀有 1 条 · 史诗 2 条 · 传说 3 条；熔炼史诗+装备可萃取词条精华，锻打到其他装备（上限 4 条）。", UITheme.C_TEXT)
	var kinds = { "off": "进攻词条", "def": "防御词条", "exp": "探索词条" }
	for kind in ["off", "def", "exp"]:
		var card = _codex_card(v, kinds[kind], Color("#bd6fff"))
		for ak in GameData.AFFIX_KEYS:
			var a = GameData.AFFIXES[ak]
			if a.kind == kind:
				_codex_line(card, a.name, a.desc)
	var build_card = _codex_card(v, "流派构筑示例", UITheme.C_GOLD)
	_codex_line(build_card, "吸血流", "弓（两箭）+ 吸血 + 迅捷 — 多段命中反复回血", UITheme.C_GREEN)
	_codex_line(build_card, "连击流", "弓 + 迅捷 + 连环 + 震慑 — 高频触发眩晕控场", UITheme.C_GREEN)
	_codex_line(build_card, "一击流", "斧 + 蓄势 + 处决 + 残忍 — 防御叠层后一斧爆发", UITheme.C_GREEN)
	_codex_line(build_card, "反伤坦克", "棘甲 + 石肤 + 守护 + 坚固套装 — 站着不动磨死敌人", UITheme.C_GREEN)

	var set_card = _codex_card(v, "套装效果（2/3 件同前缀装备激活）", UITheme.C_GOLD)
	for p in GameData.EQUIP_PREFIXES:
		if GameData.SET_BONUSES.has(p):
			var sb = GameData.SET_BONUSES[p]
			_codex_line(set_card, "%s·%s" % [p, sb.name], "2件: %s ／ 3件: %s" % [sb.two.desc, sb.three.desc])

func _codex_element(v: VBoxContainer) -> void:
	_codex_line(v, "", "五行相克：金克木 · 木克土 · 土克水 · 水克火 · 火克金。武器克制敌人时伤害 ×1.3，被克 ×0.8；护甲五行同理影响受击。", UITheme.C_TEXT)
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
	for ri in range(GameData.BIOMES.size()):
		var biome = GameData.BIOMES[ri]
		var sec = Label.new()
		sec.text = "—— 区域 %d · %s（五行属%s）——" % [ri + 1, biome.name, GameData.element_name(str(biome.get("element", "")))]
		sec.add_theme_font_size_override("font_size", 15)
		sec.add_theme_color_override("font_color", UITheme.C_GOLD)
		sec.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sec)
		for key in biome.enemy_keys:
			var t = GameData.get_enemy_type(key)
			var lore = LoreData.get_monster_lore(key)
			var base_hp = roundi((20.0 + ri * 16.0) * t.hp_mult)
			var base_atk = roundi((5.0 + ri * 3.4) * t.atk_mult)
			var card = _codex_card(v, t.name, UITheme.C_TEXT)
			_codex_line(card, "数值", "基准生命 %d · 基准攻击 %d（精英 ×2.2 生命/×1.3 攻击；每周目再 +55%%/+45%%）" % [base_hp, base_atk], Color("#9fd6ff"))
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
		var atk_est = roundi((5.0 + ri * 3.4) * 1.5)
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
		_codex_line(card, "数值", "生命 %d · 攻击 %d" % [st.hp, st.atk], Color("#9fd6ff"))
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
			_codex_line(card, "克制", "你的武器五行克制它（伤害 ×%.1f）" % wm, UITheme.C_GREEN)
		elif wm < 1.0:
			_codex_line(card, "克制", "你的武器五行被它克制（伤害 ×%.1f）" % wm, Color("#cf8a6a"))
	var r = _btn_row(c)
	_btn(r, "进 入 战 斗", func():
		close_all()
		GameState.enter_node(node)
	, 180.0)
	_btn(r, "再 想 想", close, 140.0)

# ------------------------------------------------------------
# 熔炼：选择要萃取的词条
# ------------------------------------------------------------
func _build_smelt(c: VBoxContainer) -> void:
	var idx = int(_current_data.get("index", -1))
	if idx < 0 or idx >= GameState.bag.size():
		close()
		return
	var it = GameState.bag[idx]
	_title(c, "熔 炼 装 备", Color("#e8a8ff"))
	_item_card(c, it, true)
	_text(c, "装备将被销毁，从下列词条中选择一条萃取为精华：", 14, Color("#cf8a6a"))
	for a in it.affixes:
		var ad = GameData.AFFIXES.get(a, {})
		var ak = a
		var row = _btn_row(c)
		_btn(row, "萃取「%s」 — %s" % [ad.get("name", a), ad.get("desc", "")], func():
			if GameState.smelt_bag_item(idx, ak):
				close()
		, 420.0)
	_text(c, "精华袋 %d/%d" % [GameState.essences.size(), GameData.COMBAT["essence_cap"]], 13, UITheme.C_TEXT_DIM)
	var r = _btn_row(c)
	_btn(r, "取消", close, 140.0)

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
	_text(c, "选择目标装备（花费 %d 金币 · 单件词条上限 %d 条 · 不可重复）：" % [cost, GameData.COMBAT["max_affix_total"]], 14, UITheme.C_TEXT_DIM)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(540, 320)
	c.add_child(scroll)
	var inner = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)

	var slot_names = { "weapon": "武器", "armor": "护甲", "accessory": "饰品" }
	for slot in ["weapon", "armor", "accessory"]:
		var it = GameState.equipment.get(slot)
		if not it:
			continue
		_forge_target_row(inner, it, "已装备·%s" % slot_names[slot], es, ei, { "kind": "equip", "slot": slot }, cost)
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
	l.text = "[%s] %s（词条 %d/%d）" % [tag, it.get("name", it.base_name), it.affixes.size(), GameData.COMBAT["max_affix_total"]]
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", rc)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(340, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	var ok = not it.affixes.has(es.affix) and it.affixes.size() < GameData.COMBAT["max_affix_total"] and GameState.gold >= cost
	var b = _btn(row, "锻打", func():
		if GameState.forge_essence(ei, target):
			close()
	, 90.0)
	b.disabled = not ok
	if it.affixes.has(es.affix):
		b.tooltip_text = "已拥有该词条"
	elif it.affixes.size() >= GameData.COMBAT["max_affix_total"]:
		b.tooltip_text = "词条已达上限"
	elif GameState.gold < cost:
		b.tooltip_text = "金币不足"
