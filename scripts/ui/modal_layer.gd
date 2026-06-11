class_name ModalLayer
extends Control

# ============================================================
# 弹窗层 - 游戏所有对话框
# shop / bag / treasure / event / reward / region_clear /
# victory / defeat / help / equip_detail
# ============================================================

var _dim: ColorRect
var _panel: PanelContainer
var _current_type: String = ""
var _current_data: Dictionary = {}
var _dirty: bool = false

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.62)
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
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
	if visible and _current_type in ["bag", "shop", "equip_detail"]:
		_dirty = true

func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		_rebuild()

# ------------------------------------------------------------
# 开关
# ------------------------------------------------------------
func open(modal_type: String, data: Dictionary) -> void:
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

func close() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_current_type = ""

func is_open() -> bool:
	return visible

## ESC 行为：可安全关闭的弹窗才响应
func try_escape() -> void:
	match _current_type:
		"bag", "equip_detail", "help":
			Sfx.play("click")
			close()
		"shop":
			Sfx.play("click")
			close()
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
		"shop":         _build_shop(content)
		"bag":          _build_bag(content)
		"treasure":     _build_treasure(content)
		"event":        _build_event(content)
		"reward":       _build_reward(content)
		"region_clear": _build_region_clear(content)
		"victory":      _build_victory(content)
		"defeat":       _build_defeat(content)
		"help":         _build_help(content)
		"equip_detail": _build_equip_detail(content)
		_:              close()

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

func _text(parent: Control, text: String, size: int = 16, color: Color = UITheme.C_TEXT, center: bool = true) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(440, 0)
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

## 装备卡片
func _item_card(parent: Control, item: Dictionary, compact: bool = false) -> void:
	var card = PanelContainer.new()
	var rc = UITheme.rarity_color(item.rarity)
	card.add_theme_stylebox_override("panel", UITheme.flat_box(Color(0.08, 0.1, 0.16, 0.9), rc, 2, 12, 10))
	parent.add_child(card)
	var v = VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)

	var nm = Label.new()
	var lvl_txt = (" +%d" % item.level) if item.level > 0 else ""
	nm.text = "%s%s · %s" % [item.get("name", item.base_name), lvl_txt, GameData.get_rarity_name(item.rarity)]
	nm.add_theme_font_size_override("font_size", 18)
	nm.add_theme_color_override("font_color", rc)
	v.add_child(nm)

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
			al.custom_minimum_size = Vector2(400, 0)
			v.add_child(al)

# ------------------------------------------------------------
# 各弹窗
# ------------------------------------------------------------
func _build_shop(c: VBoxContainer) -> void:
	_title(c, "旅 行 商 店")
	_text(c, "金币: %d" % GameState.gold, 16, UITheme.C_GOLD)

	var stock: Array = GameState.shop_stock
	if stock.is_empty():
		_text(c, "货架已空 — 都被你买光了！", 15, UITheme.C_TEXT_DIM)
	for i in range(stock.size()):
		var it = stock[i]
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		c.add_child(row)
		var cardbox = VBoxContainer.new()
		cardbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(cardbox)
		_item_card(cardbox, it, true)
		var idx = i
		var buy = _btn(row, "%d 金币" % it.price, func():
			if GameState.buy_shop_item(idx):
				Sfx.play("coin")
			else:
				SignalBus.show_toast.emit("金币不足或背包已满")
		, 110.0)
		buy.disabled = GameState.gold < it.price or GameState.bag.size() >= GameData.PLAYER_BASE["bag_capacity"]

	# 药水
	var prow = _btn_row(c)
	var pot = _btn(prow, "购买药水 (%d 金币) — 现有 ×%d" % [GameState.potion_price, GameState.potions], func():
		if GameState.buy_potion():
			Sfx.play("coin")
		else:
			SignalBus.show_toast.emit("金币不足或药水已达上限")
	, 320.0)
	pot.disabled = GameState.gold < GameState.potion_price or GameState.potions >= GameData.PLAYER_BASE["max_potions"]

	var brow = _btn_row(c)
	_btn(brow, "离开商店", func():
		close()
		GameState.back_to_map()
	, 180.0)

func _build_bag(c: VBoxContainer) -> void:
	_title(c, "背 包")
	_text(c, "金币: %d   ·   容量 %d/%d" % [GameState.gold, GameState.bag.size(), GameData.PLAYER_BASE["bag_capacity"]], 15, UITheme.C_TEXT_DIM)

	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(520, 360)
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
		if it.level < GameData.COMBAT["max_upgrade_level"]:
			var cost = EquipmentModifier.get_upgrade_cost(it, GameState.region)
			var s = slot
			var up = _btn(r, "强化 (%d金)" % cost, func():
				if GameState.upgrade_equipped(s):
					Sfx.play("upgrade")
				else:
					SignalBus.show_toast.emit("金币不足")
			, 130.0)
			up.disabled = GameState.gold < cost
		else:
			_text(r, "已满级 +5", 14, UITheme.C_GOLD, false)

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
			up.disabled = GameState.gold < cost
		var val = EquipmentModifier.get_sell_value(it)
		_btn(r, "出售 (%d金)" % val, func():
			GameState.sell_bag_item(idx)
			Sfx.play("coin")
		, 130.0)

	var brow = _btn_row(c)
	_btn(brow, "关闭 [Esc]", close, 160.0)

func _build_treasure(c: VBoxContainer) -> void:
	_title(c, "宝 箱 开 启 ！")
	if _current_data.get("type") == "gold":
		_text(c, "你撬开箱盖，金光涌出 ——", 16)
		_text(c, "+%d 金币" % _current_data.get("gold", 0), 26, UITheme.C_GOLD)
		var r = _btn_row(c)
		_btn(r, "收下继续", func():
			Sfx.play("coin")
			close()
			GameState.back_to_map()
		, 170.0)
	else:
		_text(c, "箱中静卧着一件装备：", 16)
		var item = _current_data.get("item", {})
		_item_card(c, item)
		_drop_choice_buttons(c, true)

func _build_event(c: VBoxContainer) -> void:
	var key = _current_data.get("key", "")
	_title(c, _current_data.get("title", "神秘事件"))
	_text(c, _current_data.get("desc", ""), 16, UITheme.C_TEXT)

	var r = _btn_row(c)
	match key:
		"merchant":
			var cost = _current_data.get("cost", 45)
			var pay = _btn(r, "支付 %d 金币" % cost, func():
				close()
				GameState.handle_event_choice("merchant", "pay")
			, 170.0)
			pay.disabled = GameState.gold < cost
			_btn(r, "婉拒离开", func():
				close()
				GameState.handle_event_choice("merchant", "leave")
			, 150.0)
		"shrine":
			_btn(r, "献祭 (失去 %d 生命，攻击 +15%%)" % _current_data.get("hp_cost", 0), func():
				close()
				Sfx.play("skill")
				GameState.handle_event_choice("shrine", "offer")
			, 300.0)
			_btn(r, "敬而远之", func():
				close()
				GameState.handle_event_choice("shrine", "refuse")
			, 140.0)
		"cave":
			_btn(r, "明亮通道 (+%d 金币)" % _current_data.get("safe_gold", 0), func():
				close()
				Sfx.play("coin")
				GameState.handle_event_choice("cave", "safe")
			, 220.0)
			_btn(r, "黑暗通道 (一搏)", func():
				close()
				GameState.handle_event_choice("cave", "risky")
			, 190.0)
		_:
			_btn(r, "继续", func():
				close()
				GameState.back_to_map()
			, 140.0)

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
		_drop_choice_buttons(c, false)
	else:
		var r = _btn_row(c)
		_btn(r, "继 续", func():
			close()
			GameState.close_reward()
		, 170.0)

## 装备/入包/出售/放弃 四连按钮 (treasure 与 reward 通用)
func _drop_choice_buttons(c: VBoxContainer, _from_treasure: bool) -> void:
	var r = _btn_row(c)
	_btn(r, "装备", func():
		close()
		Sfx.play("equip")
		GameState.handle_drop("equip")
	, 110.0)
	var bag_btn = _btn(r, "放入背包", func():
		close()
		GameState.handle_drop("bag")
	, 130.0)
	bag_btn.disabled = GameState.bag.size() >= GameData.PLAYER_BASE["bag_capacity"]
	var drop = GameState.pending_drop
	var val = EquipmentModifier.get_sell_value(drop) if drop else 0
	_btn(r, "出售 (%d金)" % val, func():
		close()
		Sfx.play("coin")
		GameState.handle_drop("sell")
	, 140.0)
	_btn(r, "放弃", func():
		close()
		GameState.pending_drop = null
		GameState.close_reward()
	, 100.0)

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
		close()
		Sfx.play("victory")
		GameState.next_region()
	, 200.0)

func _build_victory(c: VBoxContainer) -> void:
	_title(c, "✦ 远 征 完 成 ✦")
	_text(c, "五大区域全部攻克，传奇就此铸成！", 17)
	_stats_block(c, _current_data.get("stats", {}))
	_text(c, "最终金币: %d" % _current_data.get("gold", 0), 16, UITheme.C_GOLD)
	var r = _btn_row(c)
	_btn(r, "再 来 一 局", func():
		close()
		GameState.start_new_game()
	, 170.0)
	_btn(r, "返回标题", func():
		close()
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
		close()
		GameState.retry_region()
	, 160.0)
	_btn(r, "返回标题", func():
		close()
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

func _build_help(c: VBoxContainer) -> void:
	_title(c, "冒 险 指 南")
	var lines = [
		"◆ 目标：穿越 5 大区域，击败每区首领，完成远征。",
		"◆ 地图：点击发光节点前进 — 战斗/精英/宝箱/商店/事件/首领。",
		"◆ 战斗：攻击[1] · 盾击[2](伤害+护盾, 3回合冷却) · 防御[3] · 药水[4]。",
		"◆ 点击敌人可切换攻击目标。",
		"◆ 装备：+3 解锁被动，+5 解锁独特效果；词条提供额外加成。",
		"◆ 阵亡损失一半金币，但装备保留，可在本区域重新出发。",
		"◆ 进度自动保存 — 标题画面可继续远征。",
		"◆ 快捷键：B 背包 · Esc 关闭窗口。",
	]
	for line in lines:
		_text(c, line, 15, UITheme.C_TEXT, false)
	var r = _btn_row(c)
	_btn(r, "明白了", close, 150.0)

func _build_equip_detail(c: VBoxContainer) -> void:
	var item = _current_data.get("item", {})
	var slot = _current_data.get("slot", "")
	_title(c, "装 备 详 情")
	_item_card(c, item)
	var r = _btn_row(c)
	if item.level < GameData.COMBAT["max_upgrade_level"]:
		var cost = EquipmentModifier.get_upgrade_cost(item, GameState.region)
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
