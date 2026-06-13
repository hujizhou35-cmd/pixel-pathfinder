class_name LootSystem
extends RefCounted

# ============================================================
# 掉落系统 - 处理战斗后奖励计算
# 普通怪爆率低（但随区域提升）；精英必掉稀有+；首领必掉史诗+
# ============================================================

static func calculate_combat_rewards(enemies: Array, is_boss: bool, is_elite: bool, tier_override: String = "") -> Dictionary:
	var gold_gain = 0
	for e in enemies:
		gold_gain += e.gold_reward

	var stats = GameState.get_player_stats()
	gold_gain = roundi(gold_gain * (1.0 + stats.gold_pct / 100.0))

	var tier = tier_override if tier_override != "" else ("boss" if is_boss else "elite" if is_elite else "normal")
	var rule = GameData.DROP_RULES[tier]
	var drop_chance = rule.chance + rule.region_bonus * GameState.region + stats.loot_pct

	var drop = null
	if randf() * 100.0 < drop_chance:
		drop = EquipmentFactory.generate_item(GameState.region, "", rule.min_rarity, tier)

	return {
		"gold": gold_gain,
		"drop": drop,
		"is_boss": is_boss,
	}

static func get_region_clear_bonus(region: int) -> int:
	return 60 + region * 40
