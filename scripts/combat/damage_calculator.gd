class_name DamageCalculator
extends RefCounted

# ============================================================
# 伤害计算器 - 所有伤害计算逻辑
# ============================================================

static func calc_player_hit(stats: Dictionary, target, mult: float = 1.0) -> Dictionary:
	var dmg = stats.atk * randf_range(0.85, 1.15) * mult
	var is_crit = randf() * 100 < stats.crit
	if is_crit:
		dmg *= stats.crit_dmg / 100.0

	# 战斧 +5 效果
	if stats.axe_bonus > 0 and target and target.hp > target.maxhp * 0.7:
		dmg *= 1.0 + stats.axe_bonus

	return {
		"damage": max(1, roundi(dmg)),
		"is_crit": is_crit,
	}

static func apply_damage_to_enemy(enemy: Dictionary, dmg: int, is_crit: bool = false) -> void:
	if enemy.shield > 0:
		var absorbed = mini(enemy.shield, dmg)
		enemy.shield -= absorbed
		dmg -= absorbed
		SignalBus.enemy_shield_changed.emit(0, enemy.shield)

	if dmg > 0:
		enemy.hp = maxi(0, enemy.hp - dmg)
		enemy.hit_flash = 8
		SignalBus.enemy_hp_changed.emit(-1, enemy.hp, enemy.maxhp)

static func calc_enemy_damage(enemy_atk: int, stats: Dictionary) -> int:
	var dmg = maxi(1, roundi(enemy_atk - stats.def * GameData.COMBAT["def_dmg_reduction"]))

	# 完全格挡
	if stats.full_block_chance > 0 and randf() * 100 < stats.full_block_chance:
		SignalBus.combat_log_message.emit("护甲完全格挡了攻击！", "player")
		return 0

	# 伤害减免
	if stats.dmg_reduction > 0:
		dmg = maxi(1, roundi(dmg * (1.0 - stats.dmg_reduction / 100.0)))

	# 减半格挡
	if randf() * 100 < stats.block_chance:
		dmg = maxi(1, roundi(dmg / 2.0))
		SignalBus.combat_log_message.emit("格挡减半！", "player")

	return dmg

static func apply_damage_to_player(raw_dmg: int, source_name: String) -> void:
	if raw_dmg <= 0:
		SignalBus.combat_log_message.emit("%s 的攻击被完全格挡！" % source_name, "player")
		return

	var combat = GameState.combat_state
	if combat and combat.shield > 0:
		var absorbed = mini(combat.shield, raw_dmg)
		combat.shield -= absorbed
		raw_dmg -= absorbed
		SignalBus.shield_changed.emit(combat.shield)
		if absorbed > 0:
			SignalBus.combat_log_message.emit("护盾吸收了 %d 点伤害" % absorbed, "system")

	if raw_dmg > 0:
		GameState.hp = maxi(0, GameState.hp - raw_dmg)
		GameState.run_stats.dmg_taken += raw_dmg
		SignalBus.hp_changed.emit(GameState.hp, GameState.max_hp)
		SignalBus.damage_taken.emit("player", raw_dmg)
		SignalBus.combat_log_message.emit("%s 对你造成了 %d 点伤害" % [source_name, raw_dmg], "enemy")
		Sfx.play("hurt")
		SignalBus.shake_screen.emit(6.0, 0.18)
	else:
		SignalBus.combat_log_message.emit("护盾完全吸收了伤害", "system")
