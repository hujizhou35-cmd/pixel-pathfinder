class_name LootSystem
extends RefCounted

# ============================================================
# 掉落系统 - 处理战斗后奖励计算
# ============================================================

static func calculate_combat_rewards(enemies: Array, is_boss: bool, is_elite: bool) -> Dictionary:
	var gold_gain = 0
	for e in enemies:
		gold_gain += e.gold_reward

	var stats = GameState.get_player_stats()
	gold_gain = roundi(gold_gain * (1.0 + stats.gold_pct / 100.0))

	var drop = null
	var drop_chance = 100.0 if (is_boss or is_elite) else 38.0 + stats.loot_pct
	if randf() * 100.0 < drop_chance:
		var min_rar = 2 if is_boss else 1 if is_elite else 0
		drop = EquipmentFactory.generate_item(GameState.region, "", min_rar)

	return {
		"gold": gold_gain,
		"drop": drop,
		"is_boss": is_boss,
	}

static func get_region_clear_bonus(region: int) -> int:
	return 60 + region * 40
