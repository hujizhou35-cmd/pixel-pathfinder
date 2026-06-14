class_name DamageCalculator
extends RefCounted

# ============================================================
# 伤害计算器
# - 五行克制：攻方元素克守方 ×1.3，被克 ×0.8（符文套装可翻倍加成）
# - 怪物词条：坚甲(减伤25%) / 穿甲(无视护盾) 在此结算
# ============================================================

static func calc_player_hit(stats: Dictionary, target, mult: float = 1.0) -> Dictionary:
	var dmg = stats.atk * randf_range(0.85, 1.15) * mult
	var is_crit = randf() * 100 < stats.crit
	if is_crit:
		dmg *= stats.crit_dmg / 100.0

	# 五行克制（武器元素 vs 怪物元素）
	var elem_tag = ""
	if target and target is Dictionary:
		var em = GameData.element_mult(str(stats.get("weapon_element", "")), str(target.get("element", "")))
		if em > 1.0:
			if stats.get("elem_counter_x2", false):
				em = 1.0 + (em - 1.0) * 2.0
			elem_tag = "克制"
		elif em < 1.0:
			elem_tag = "受克"
		dmg *= em

	# 处决：对低生命敌人增伤
	if stats.get("execute_bonus", 0) > 0 and target and target.hp <= target.maxhp * 0.30:
		dmg *= 1.0 + stats.execute_bonus / 100.0

	# 战斧 +5 效果：对高生命敌人增伤
	if stats.axe_bonus > 0 and target and target.hp > target.maxhp * 0.7:
		dmg *= 1.0 + stats.axe_bonus

	return {
		"damage": max(1, roundi(dmg)),
		"is_crit": is_crit,
		"elem_tag": elem_tag,
	}

## opts: pierce_shield 无视护盾（雷击触发）；ignore_def 无视防御（灼烧）
static func apply_damage_to_enemy(enemy: Dictionary, dmg: int, is_crit: bool = false, opts: Dictionary = {}) -> int:
	# 怪物防御：固定减免每次受到的伤害（最低 1 点；灼烧无视防御）
	# 斧·破甲层数：每层使目标防御 -15%
	if not opts.get("ignore_def", false):
		var edef := float(enemy.get("def", 0))
		var sunder := int(enemy.get("sunder", 0))
		if sunder > 0:
			edef *= 1.0 - GameData.COMBAT["axe_sunder_pct"] * sunder
		dmg = maxi(1, dmg - roundi(edef))

	# 坚甲词条：受到伤害 -25%
	if enemy.get("affixes", []).has("armored"):
		dmg = maxi(1, roundi(dmg * 0.75))

	if enemy.shield > 0 and not opts.get("pierce_shield", false):
		var absorbed = mini(enemy.shield, dmg)
		enemy.shield -= absorbed
		dmg -= absorbed
		SignalBus.enemy_shield_changed.emit(0, enemy.shield)

	if dmg > 0:
		enemy.hp = maxi(0, enemy.hp - dmg)
		enemy.hit_flash = 8
		SignalBus.enemy_hp_changed.emit(-1, enemy.hp, enemy.maxhp)
	return dmg

static func calc_enemy_damage(enemy_atk: int, stats: Dictionary, enemy_element: String = "") -> int:
	var raw = float(enemy_atk)

	# 五行克制（怪物元素 vs 护甲元素）
	if enemy_element != "":
		raw *= GameData.element_mult(enemy_element, str(stats.get("armor_element", "")))

	var dmg = maxi(1, roundi(raw - stats.def * GameData.COMBAT["def_dmg_reduction"]))

	# 闪避（鞋 +5 独特 / 龙行靴特性）
	if stats.get("dodge_chance", 0) > 0 and randf() * 100 < stats.dodge_chance:
		SignalBus.combat_log_message.emit("你侧身闪过了攻击！", "player")
		return 0

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

## 返回实际打到生命上的伤害（供嗜血怪吸血）；pierce: 穿甲无视护盾
static func apply_damage_to_player(raw_dmg: int, source_name: String, pierce: bool = false) -> int:
	if raw_dmg <= 0:
		SignalBus.combat_log_message.emit("%s 的攻击被完全格挡！" % source_name, "player")
		return 0

	var combat = GameState.combat_state
	if combat and combat.shield > 0 and not pierce:
		var absorbed = mini(combat.shield, raw_dmg)
		combat.shield -= absorbed
		raw_dmg -= absorbed
		SignalBus.shield_changed.emit(combat.shield)
		if absorbed > 0:
			SignalBus.combat_log_message.emit("护盾吸收了 %d 点伤害" % absorbed, "system")
	elif pierce and combat and combat.shield > 0:
		SignalBus.combat_log_message.emit("穿甲攻击无视了你的护盾！", "enemy")

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
	return raw_dmg
