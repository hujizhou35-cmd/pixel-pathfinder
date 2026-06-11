class_name EquipmentModifier
extends RefCounted

# ============================================================
# 装备修饰器 - 计算装备属性、升级费用、出售价格
# ============================================================

static func get_upgrade_cost(item: Dictionary, region: int) -> int:
	return roundi((item.level + 1) * 22 * (1 + region * 0.55) / 5.0) * 5

static func get_sell_value(item: Dictionary) -> int:
	return item.value + item.level * 12

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

static func format_affixes(item: Dictionary) -> Array:
	var lines = []
	for a in item.affixes:
		var data = GameData.AFFIXES.get(a, {})
		lines.append("◆ %s" % data.get("desc", ""))

	if item.level >= 3:
		var passive = ""
		match item.slot:
			"weapon": passive = "暴击率 +10%"
			"armor": passive = "格挡率 +10%"
			"accessory": passive = "每回合恢复 +2 生命"
		lines.append("★ 被动: %s" % passive)
	else:
		lines.append("★ +3 解锁被动")

	if item.level >= 5:
		lines.append("✦ 独特: %s" % item.unique_5)
	else:
		lines.append("✦ +5 解锁: %s" % item.unique_5)

	return lines
