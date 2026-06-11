class_name EquipmentModifier
extends RefCounted

# ============================================================
# 装备修饰器 - 属性结算中心
# 基础 + 装备(含强化) + 基底特性 + 词条 + 套装 + 区域祝福
# 出售价 = 基础价值 + 强化等级补贴 + 已投入强化费用的 50% (+镀金套装加成)
# ============================================================

static func get_upgrade_cost(item: Dictionary, region: int) -> int:
	return roundi((item.level + 1) * 22 * (1 + region * 0.55) / 5.0) * 5

static func get_sell_value(item: Dictionary, sell_pct: float = -1.0) -> int:
	var invested: int = int(item.get("invested", 0))
	if sell_pct < 0:
		sell_pct = 0.0
		if GameState:
			sell_pct = float(GameState.get_player_stats().get("sell_pct", 0))
	var base = item.value * (1.0 + sell_pct / 100.0)
	return roundi(base) + item.level * 12 + roundi(invested * GameData.COMBAT["sell_refund_pct"])

static func get_stat_multiplier(level: int) -> float:
	return 1.0 + level * GameData.COMBAT["upgrade_stat_mult"]

static func calculate_total_stats(equipment: Dictionary) -> Dictionary:
	var S = {
		"atk": GameData.PLAYER_BASE["atk"],
		"def": GameData.PLAYER_BASE["def"],
		"hp": 0,
		"crit": GameData.PLAYER_BASE["crit"],
		"crit_dmg": GameData.PLAYER_BASE["crit_dmg"],
		"extra_hit": 0,
		"splash": 0,
		"block_chance": 0,
		"dmg_reduction": 0,
		"regen": 0,
		"shield_start": 0,
		"gold_pct": 0,
		"loot_pct": 0,
		"discount": 0,
		"first_double": false,
		"kill_shield": 0,
		"axe_bonus": 0.0,
		"full_block_chance": 0,
		"battle_heal": 0.0,
		# 新词条 / 流派
		"lifesteal": 0,
		"stun_chance": 0,
		"burn_chance": 0,
		"burn_x2": false,
		"combo_dmg": 0,
		"has_focus": false,
		"execute_bonus": 0,
		"shield_gain_pct": 0,
		"potion_bonus_pct": 0,
		"potion_cd_reduce": 0,
		"thorns_pct": 0,
		"elem_proc": 0,
		"elem_counter_x2": false,
		"first_turn_pct": 0,
		"weaken_chance": 0,
		"sell_pct": 0,
		# 百分比累积（最后统一应用）
		"atk_pct": 0,
		"def_pct": 0,
		"hp_pct": 0,
		# 五行
		"weapon_element": "",
		"armor_element": "",
	}

	for slot in ["weapon", "armor", "accessory"]:
		var it = equipment.get(slot)
		if not it:
			continue

		var upm = get_stat_multiplier(it.level)
		S.atk += roundi(it.stats.atk * upm)
		S.def += roundi(it.stats.def * upm)
		S.hp += roundi(it.stats.hp * upm)

		if slot == "weapon":
			S.weapon_element = str(it.get("element", ""))
		elif slot == "armor":
			S.armor_element = str(it.get("element", ""))

		# 基底特性（短剑轻巧 / 刺剑锋芒 / 板甲钢壁…）
		_apply_fx(S, it.get("trait", {}))

		# +3 被动
		if it.level >= 3:
			match slot:
				"weapon": S.crit += 10
				"armor": S.block_chance += 10
				"accessory": S.regen += 2

		# +5 独特
		if it.level >= 5:
			match it.key:
				"sword": S.kill_shield = 8
				"bow": S.first_double = true
				"axe": S.axe_bonus = 0.35
				"armor": S.full_block_chance = 25
				"amulet": S.battle_heal += 0.15

		# 词条
		for a in it.affixes:
			match a:
				"crit": S.crit += 10
				"critdmg": S.crit_dmg += 40
				"swift": S.extra_hit += 15
				"pierce": S.atk_pct += 12
				"chain": S.splash += 30
				"lifesteal": S.lifesteal += 12
				"stun": S.stun_chance += 12
				"burn": S.burn_chance += 20
				"combo": S.combo_dmg += 25
				"focus": S.has_focus = true
				"execute": S.execute_bonus += 40
				"block": S.block_chance += 10
				"bulwark": S.shield_start += 10
				"regen": S.regen += 2
				"stone": S.dmg_reduction += 10
				"shieldm": S.shield_gain_pct += 40
				"thornsp": S.thorns_pct += 20
				"greed": S.gold_pct += 25
				"fortune": S.loot_pct += 15
				"haggle": S.discount += 15
				"alchemy":
					S.potion_bonus_pct += 15
					S.potion_cd_reduce += 1

	# 套装效果
	var sets = get_active_sets(equipment)
	for s in sets:
		_apply_fx(S, s.fx)

	# 百分比统一应用
	S.atk = roundi(S.atk * (1.0 + S.atk_pct / 100.0))
	S.def = roundi(S.def * (1.0 + S.def_pct / 100.0))
	S.hp = roundi(S.hp * (1.0 + S.hp_pct / 100.0))

	# 区域buff
	var region_buff = GameState.region_buff if GameState else 0.0
	if region_buff > 0:
		S.atk = roundi(S.atk * (1.0 + region_buff))

	return S

## 通用效果应用器：套装 fx / 基底 trait 共用
static func _apply_fx(S: Dictionary, fx: Dictionary) -> void:
	for k in fx:
		var v = fx[k]
		match k:
			"atk_pct": S.atk_pct += v
			"def_pct": S.def_pct += v
			"hp_pct": S.hp_pct += v
			"crit": S.crit += v
			"crit_dmg": S.crit_dmg += v
			"extra_hit": S.extra_hit += v
			"combo_dmg": S.combo_dmg += v
			"gold_pct": S.gold_pct += v
			"loot_pct": S.loot_pct += v
			"discount": S.discount += v
			"regen": S.regen += v
			"dmg_reduction": S.dmg_reduction += v
			"block_chance": S.block_chance += v
			"shield_gain_pct": S.shield_gain_pct += v
			"shield_start": S.shield_start += v
			"elem_proc": S.elem_proc += v
			"elem_counter_x2": S.elem_counter_x2 = true
			"first_turn_pct": S.first_turn_pct += v
			"battle_heal": S.battle_heal += v / 100.0
			"burn_chance": S.burn_chance += v
			"burn_x2": S.burn_x2 = true
			"weaken_chance": S.weaken_chance += v
			"sell_pct": S.sell_pct += v

# ------------------------------------------------------------
# 套装：身上 2/3 件同前缀装备激活套装效果
# 返回 [{prefix, set_name, count, fx, descs}]
# ------------------------------------------------------------
static func get_active_sets(equipment: Dictionary) -> Array:
	var counts = {}
	for slot in ["weapon", "armor", "accessory"]:
		var it = equipment.get(slot)
		if not it:
			continue
		var p = str(it.get("prefix", ""))
		if p == "":
			continue
		counts[p] = counts.get(p, 0) + 1

	var out = []
	for p in counts:
		var n = counts[p]
		if n < 2 or not GameData.SET_BONUSES.has(p):
			continue
		var sb = GameData.SET_BONUSES[p]
		var fx = sb.two.fx.duplicate()
		var descs = ["2件: %s" % sb.two.desc]
		if n >= 3:
			for k in sb.three.fx:
				var v3 = sb.three.fx[k]
				if fx.has(k) and (v3 is int or v3 is float):
					fx[k] += v3
				else:
					fx[k] = v3
			descs.append("3件: %s" % sb.three.desc)
		out.append({ "prefix": p, "set_name": sb.name, "count": n, "fx": fx, "descs": descs })
	return out

# ------------------------------------------------------------
# 属性分解：基础 / 装备 / 祝福，供属性面板清晰展示
# ------------------------------------------------------------
static func calculate_stat_breakdown(equipment: Dictionary) -> Dictionary:
	var base = {
		"atk": GameData.PLAYER_BASE["atk"],
		"def": GameData.PLAYER_BASE["def"],
		"hp": GameData.PLAYER_BASE["max_hp"],
		"crit": GameData.PLAYER_BASE["crit"],
		"crit_dmg": GameData.PLAYER_BASE["crit_dmg"],
	}
	var equip = { "atk": 0, "def": 0, "hp": 0, "crit": 0, "crit_dmg": 0 }
	var specials = []   # [{source, text}]

	var slot_names = { "weapon": "武器", "armor": "护甲", "accessory": "饰品" }
	for slot in ["weapon", "armor", "accessory"]:
		var it = equipment.get(slot)
		if not it:
			continue
		var src = "%s「%s」" % [slot_names[slot], it.get("name", it.base_name)]
		var upm = get_stat_multiplier(it.level)
		equip.atk += roundi(it.stats.atk * upm)
		equip.def += roundi(it.stats.def * upm)
		equip.hp += roundi(it.stats.hp * upm)

		var elem = str(it.get("element", ""))
		if elem != "":
			var ed = GameData.ELEMENTS.get(elem, {})
			specials.append({ "source": src, "text": "元素: %s — 克制时伤害×1.3 · %s(%s)" % [GameData.element_name(elem), ed.get("proc_name", ""), ed.get("proc_desc", "")] })
		var td = str(it.get("trait_desc", ""))
		if td != "":
			specials.append({ "source": src, "text": "基底特性: %s" % td })

		if it.level >= 3:
			match slot:
				"weapon":
					equip.crit += 10
					specials.append({ "source": src, "text": "被动: 暴击率 +10%" })
				"armor":
					specials.append({ "source": src, "text": "被动: 格挡率 +10%" })
				"accessory":
					specials.append({ "source": src, "text": "被动: 每回合恢复 2 生命" })
		if it.level >= 5:
			specials.append({ "source": src, "text": "独特: %s" % it.unique_5 })
		for a in it.affixes:
			var ad = GameData.AFFIXES.get(a, {})
			if a == "crit":
				equip.crit += 10
			elif a == "critdmg":
				equip.crit_dmg += 40
			specials.append({ "source": src, "text": "词条: %s — %s" % [ad.get("name", a), ad.get("desc", "")] })

	var sets = get_active_sets(equipment)
	for s in sets:
		specials.append({ "source": "套装「%s·%s」(%d件)" % [s.prefix, s.set_name, s.count], "text": " / ".join(s.descs) })

	var buff_pct = (GameState.region_buff if GameState else 0.0) * 100.0
	return {
		"base": base,
		"equip": equip,
		"buff_atk_pct": buff_pct,
		"specials": specials,
		"sets": sets,
		"total": calculate_total_stats(equipment),
	}

static func format_item_stats(item: Dictionary) -> String:
	var upm = get_stat_multiplier(item.level)
	var parts = []
	var elem = str(item.get("element", ""))
	if elem != "":
		parts.append("〔%s〕" % GameData.element_name(elem))
	if item.stats.atk > 0:
		parts.append("攻击 %d" % roundi(item.stats.atk * upm))
	if item.stats.def > 0:
		parts.append("防御 %d" % roundi(item.stats.def * upm))
	if item.stats.hp > 0:
		parts.append("生命 +%d" % roundi(item.stats.hp * upm))
	return " · ".join(parts)

## 强化后的属性增益预览（强化前 → 强化后）
static func format_upgrade_preview(item: Dictionary) -> String:
	if item.level >= GameData.COMBAT["max_upgrade_level"]:
		return ""
	var cur = get_stat_multiplier(item.level)
	var nxt = get_stat_multiplier(item.level + 1)
	var parts = []
	if item.stats.atk > 0:
		parts.append("攻击 %d→%d" % [roundi(item.stats.atk * cur), roundi(item.stats.atk * nxt)])
	if item.stats.def > 0:
		parts.append("防御 %d→%d" % [roundi(item.stats.def * cur), roundi(item.stats.def * nxt)])
	if item.stats.hp > 0:
		parts.append("生命 %d→%d" % [roundi(item.stats.hp * cur), roundi(item.stats.hp * nxt)])
	return " · ".join(parts)

## 武器职业说明（剑/斧/弓差异）
static func weapon_class_desc(key: String) -> String:
	match key:
		"axe": return "斧：伤害 ×1.55，攻击后冷却 1 回合（空档可防御蓄势）"
		"bow": return "弓：每回合射出 2 箭，每箭 ×0.62 且独立触发命中特效"
		"sword": return "剑：标准攻击，无冷却"
	return ""

static func format_affixes(item: Dictionary) -> Array:
	var lines = []
	var wc = weapon_class_desc(str(item.get("key", "")))
	if wc != "":
		lines.append("◈ %s" % wc)
	var td = str(item.get("trait_desc", ""))
	if td != "":
		lines.append("◈ 基底特性 · %s" % td)
	var elem = str(item.get("element", ""))
	if elem != "":
		var ed = GameData.ELEMENTS.get(elem, {})
		lines.append("〔%s〕克制时伤害×1.3 · 触发「%s」: %s" % [GameData.element_name(elem), ed.get("proc_name", ""), ed.get("proc_desc", "")])
	var pfx = str(item.get("prefix", ""))
	if pfx != "" and GameData.SET_BONUSES.has(pfx):
		var sb = GameData.SET_BONUSES[pfx]
		lines.append("✪ 套装「%s·%s」 2件: %s / 3件: %s" % [pfx, sb.name, sb.two.desc, sb.three.desc])

	for a in item.affixes:
		var data = GameData.AFFIXES.get(a, {})
		lines.append("◆ %s · %s" % [data.get("name", a), data.get("desc", "")])

	if item.level >= 3:
		var passive = ""
		match item.slot:
			"weapon": passive = "暴击率 +10%"
			"armor": passive = "格挡率 +10%"
			"accessory": passive = "每回合恢复 +2 生命"
		lines.append("★ 被动(已解锁): %s" % passive)
	else:
		lines.append("★ +3 解锁被动")

	if item.level >= 5:
		lines.append("✦ 独特(已解锁): %s" % item.unique_5)
	else:
		lines.append("✦ +5 解锁: %s" % item.unique_5)

	var invested: int = int(item.get("invested", 0))
	if invested > 0:
		lines.append("◇ 已投入强化 %d 金 · 出售时返还 50%%（+%d 金）" % [invested, roundi(invested * GameData.COMBAT["sell_refund_pct"])])

	return lines
