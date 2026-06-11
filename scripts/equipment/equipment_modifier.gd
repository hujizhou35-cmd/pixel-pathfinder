class_name EquipmentModifier
extends RefCounted

# ============================================================
# 装备修饰器 - 计算装备属性、升级费用、出售价格
# 出售价 = 基础价值 + 强化等级补贴 + 已投入强化费用的 50%
# ============================================================

static func get_upgrade_cost(item: Dictionary, region: int) -> int:
	return roundi((item.level + 1) * 22 * (1 + region * 0.55) / 5.0) * 5

static func get_sell_value(item: Dictionary) -> int:
	var invested: int = int(item.get("invested", 0))
	return item.value + item.level * 12 + roundi(invested * GameData.COMBAT["sell_refund_pct"])

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
	}

	for slot in ["weapon", "armor", "accessory"]:
		var it = equipment.get(slot)
		if not it:
			continue

		var upm = get_stat_multiplier(it.level)
		S.atk += roundi(it.stats.atk * upm)
		S.def += roundi(it.stats.def * upm)
		S.hp += roundi(it.stats.hp * upm)

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
				"amulet": S.battle_heal = 0.15

		# 词条
		for a in it.affixes:
			match a:
				"crit": S.crit += 10
				"critdmg": S.crit_dmg += 40
				"swift": S.extra_hit += 15
				"pierce": S.atk = roundi(S.atk * 1.12)
				"chain": S.splash += 30
				"block": S.block_chance += 10
				"bulwark": S.shield_start += 10
				"regen": S.regen += 2
				"stone": S.dmg_reduction += 10
				"greed": S.gold_pct += 25
				"fortune": S.loot_pct += 15
				"haggle": S.discount += 15

	# 区域buff
	var region_buff = GameState.region_buff if GameState else 0.0
	if region_buff > 0:
		S.atk = roundi(S.atk * (1.0 + region_buff))

	return S

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

	var buff_pct = (GameState.region_buff if GameState else 0.0) * 100.0
	return {
		"base": base,
		"equip": equip,
		"buff_atk_pct": buff_pct,
		"specials": specials,
		"total": calculate_total_stats(equipment),
	}

static func format_item_stats(item: Dictionary) -> String:
	var upm = get_stat_multiplier(item.level)
	var parts = []
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

static func format_affixes(item: Dictionary) -> Array:
	var lines = []
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
