class_name CombatManager
extends RefCounted

# ============================================================
# 战斗管理器 - 设置和管理战斗
# ============================================================

static func setup_combat(region: int, depth: int, elite: bool, boss: bool) -> Dictionary:
	var enemies = []
	var biome = GameData.get_biome(region)

	if boss:
		enemies.append(_create_boss(region, depth, biome))
	elif elite:
		enemies.append(_create_enemy(region, depth, biome, true))
	else:
		var roll = randf()
		var n = 1
		if roll < 0.15:
			n = 3
		elif roll < 0.60:
			n = 2
		for i in range(n):
			enemies.append(_create_enemy(region, depth, biome, false))

	var stats = GameState.get_player_stats()
	var shield = stats.shield_start
	if shield > 0:
		SignalBus.combat_log_message.emit("壁垒词条：战斗开始获得 %d 护盾" % shield, "system")

	return {
		"enemies": enemies,
		"player_turn": true,
		"skill_cooldown": 0,
		"shield": shield,
		"turn": 0,
		"first_attack": true,
		"is_elite": elite,
		"is_boss": boss,
		"hero_anim": 0,
		"busy": false,
	}

static func _create_enemy(region: int, depth: int, biome: Dictionary, is_elite: bool) -> Dictionary:
	var enemy_keys = biome.enemy_keys
	var key = enemy_keys[randi() % enemy_keys.size()]
	var template = GameData.get_enemy_type(key)
	var dscale = 1.0 + depth * 0.10
	var name = template.name
	var hp_mult = template.hp_mult
	var atk_mult = template.atk_mult

	if is_elite:
		name = "精英" + name
		hp_mult *= 2.0
		atk_mult *= 1.25

	var maxhp = roundi((16.0 + region * 13.0) * hp_mult * dscale)
	var atk = roundi((4.0 + region * 3.0) * atk_mult * dscale)
	var gold_reward = roundi((8.0 + region * 6.0) * (3.0 if is_elite else 1.0) * randf_range(0.8, 1.2))

	return {
		"name": name,
		"sprite_key": key,
		"palette": template.palette,
		"maxhp": maxhp,
		"hp": maxhp,
		"atk": atk,
		"gold_reward": gold_reward,
		"shield": 0,
		"is_boss": false,
		"is_elite": is_elite,
		"traits": null,
		"scale": 5.4 if is_elite else 4.4,
		"anim": 0,
		"hit_flash": 0,
		"counted": false,
	}

static func _create_boss(region: int, depth: int, biome: Dictionary) -> Dictionary:
	var boss_data = biome.boss
	var dscale = 1.0 + depth * 0.10
	var maxhp = roundi((16.0 + region * 13.0) * 5.2 * dscale)
	var atk = roundi((4.0 + region * 3.0) * 1.4 * dscale)
	var gold_reward = roundi((8.0 + region * 6.0) * 6.0 * randf_range(0.8, 1.2))

	return {
		"name": boss_data.name,
		"sprite_key": boss_data.sprite,
		"palette": boss_data.palette,
		"maxhp": maxhp,
		"hp": maxhp,
		"atk": atk,
		"gold_reward": gold_reward,
		"shield": 0,
		"is_boss": true,
		"is_elite": false,
		"traits": {
			"list": boss_data.traits.duplicate(),
			"shield_used": false,
			"raged": false,
			"turn": 0,
		},
		"scale": 7.0,
		"anim": 0,
		"hit_flash": 0,
		"counted": false,
	}
