extends Node
class_name CombatStateMachine

const DamageCalculator = preload("res://scripts/combat/damage_calculator.gd")
const LootSystem = preload("res://scripts/equipment/loot_system.gd")

# ============================================================
# 战斗状态机
# - 玩家可选择目标
# - 敌方逐个行动（带节奏延迟，便于动画表现）
# - 召唤物当回合不行动
# ============================================================

enum Phase { PLAYER, ENEMY, END }

var phase: int = Phase.PLAYER
var combat_data: Dictionary = {}
var busy: bool = false
var _enemy_index: int = 0
var _enemy_count_this_turn: int = 0

func start_combat(data: Dictionary) -> void:
	combat_data = data
	phase = Phase.PLAYER
	busy = false
	GameState.combat_state = data

	SignalBus.combat_log_message.emit("—— 战斗开始 ——", "system")
	if data.is_boss:
		SignalBus.combat_log_message.emit("强大的气息逼近……", "enemy")
		Sfx.play("boss")
	elif data.is_elite:
		Sfx.play("boss")

	# 护符 +5：战斗开始时恢复生命
	var stats = GameState.get_player_stats()
	if stats.battle_heal > 0 and GameState.hp > 0 and GameState.hp < GameState.max_hp:
		var heal = roundi(GameState.max_hp * stats.battle_heal)
		GameState.hp = mini(GameState.hp + heal, GameState.max_hp)
		SignalBus.hp_changed.emit(GameState.hp, GameState.max_hp)
		SignalBus.combat_log_message.emit("护符微光闪烁：恢复 %d 生命" % heal, "system")

	if combat_data.shield > 0:
		SignalBus.shield_changed.emit(combat_data.shield)

	SignalBus.player_turn_started.emit()

func _in_combat() -> bool:
	return is_inside_tree() and GameState.current_state == GameState.State.COMBAT and not combat_data.is_empty()

func can_player_act() -> bool:
	return phase == Phase.PLAYER and not busy and combat_data.get("player_turn", false)

func _resolve_target(target_idx: int) -> Dictionary:
	var enemies = combat_data.enemies
	if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx].hp > 0:
		return { "index": target_idx, "enemy": enemies[target_idx] }
	return _get_first_alive_enemy(enemies)

# ------------------------------------------------------------
# 玩家行动
# ------------------------------------------------------------
func player_attack(target_idx: int = -1) -> void:
	if not can_player_act():
		return
	busy = true

	var stats = GameState.get_player_stats()
	var enemies = combat_data.enemies
	var target = _resolve_target(target_idx)
	if target.index < 0:
		busy = false
		return

	var t = target.enemy
	var mult = 1.0

	# 长弓 +5：每场战斗首次攻击双倍
	if combat_data.first_attack and stats.first_double:
		mult *= 2.0
		SignalBus.combat_log_message.emit("长弓蓄势：首击双倍伤害！", "system")
	combat_data.first_attack = false

	var result = DamageCalculator.calc_player_hit(stats, t, mult)
	DamageCalculator.apply_damage_to_enemy(t, result.damage, result.is_crit)
	GameState.run_stats.dmg_dealt += result.damage
	SignalBus.player_attacked.emit(target.index, result.damage, result.is_crit)
	Sfx.play("crit" if result.is_crit else "attack")

	var msg = "你挥剑斩向 %s，造成 %d 点伤害" % [t.name, result.damage]
	if result.is_crit:
		msg = "会心一击！你对 %s 造成 %d 点伤害" % [t.name, result.damage]
	SignalBus.combat_log_message.emit(msg, "crit" if result.is_crit else "player")

	# 连锁词条：溅射
	if stats.splash > 0 and result.damage > 0:
		for i in range(enemies.size()):
			if i == target.index or enemies[i].hp <= 0:
				continue
			var sd = max(1, roundi(result.damage * stats.splash / 100.0))
			DamageCalculator.apply_damage_to_enemy(enemies[i], sd, false)
			GameState.run_stats.dmg_dealt += sd
			SignalBus.player_attacked.emit(i, sd, false)
			SignalBus.combat_log_message.emit("剑气溅射 %s，造成 %d 点伤害" % [enemies[i].name, sd], "player")

	# 迅捷词条：连击
	if randf() * 100 < stats.extra_hit and t.hp > 0:
		var h2 = DamageCalculator.calc_player_hit(stats, t, GameData.COMBAT["extra_hit_dmg_mult"])
		DamageCalculator.apply_damage_to_enemy(t, h2.damage, h2.is_crit)
		GameState.run_stats.dmg_dealt += h2.damage
		SignalBus.player_attacked.emit(target.index, h2.damage, h2.is_crit)
		SignalBus.combat_log_message.emit("迅捷连击！额外造成 %d 点伤害" % h2.damage, "player")
		Sfx.play("attack")

	_kill_check()
	_queue_next(_end_player_turn, 0.45)

func player_skill(target_idx: int = -1) -> void:
	if not can_player_act():
		return
	if combat_data.get("skill_cooldown", 0) > 0:
		return

	busy = true
	var stats = GameState.get_player_stats()
	var target = _resolve_target(target_idx)
	if target.index < 0:
		busy = false
		return

	var result = DamageCalculator.calc_player_hit(stats, target.enemy, GameData.COMBAT["skill_dmg_mult"])
	DamageCalculator.apply_damage_to_enemy(target.enemy, result.damage, result.is_crit)
	GameState.run_stats.dmg_dealt += result.damage
	SignalBus.player_attacked.emit(target.index, result.damage, result.is_crit)
	Sfx.play("skill")

	var msg = "盾击轰中 %s，造成 %d 点伤害" % [target.enemy.name, result.damage]
	if result.is_crit:
		msg += "（暴击！）"
	SignalBus.combat_log_message.emit(msg, "crit" if result.is_crit else "player")

	var shield_amt = roundi(GameData.COMBAT["base_skill_shield"] + stats.def * GameData.COMBAT["skill_shield_def_mult"])
	combat_data.shield += shield_amt
	combat_data.skill_cooldown = GameData.COMBAT["skill_cooldown"]
	SignalBus.shield_changed.emit(combat_data.shield)
	SignalBus.skill_cooldown_changed.emit(combat_data.skill_cooldown)
	SignalBus.combat_log_message.emit("盾击余势：获得 %d 点护盾" % shield_amt, "player")

	_kill_check()
	_queue_next(_end_player_turn, 0.45)

func player_defend() -> void:
	if not can_player_act():
		return
	busy = true
	var stats = GameState.get_player_stats()
	var shield_amt = roundi(GameData.COMBAT["base_def_shield"] + stats.def * GameData.COMBAT["def_shield_def_mult"])
	combat_data.shield += shield_amt
	SignalBus.shield_changed.emit(combat_data.shield)
	SignalBus.combat_log_message.emit("你举盾固守：+%d 护盾" % shield_amt, "player")
	Sfx.play("shield")
	_queue_next(_end_player_turn, 0.3)

func player_potion() -> void:
	if not can_player_act():
		return
	if GameState.potions <= 0:
		return
	if GameState.hp >= GameState.max_hp:
		SignalBus.show_toast.emit("生命已满，无需饮用药水")
		return
	busy = true
	GameState.use_potion()
	var heal = roundi(GameState.max_hp * GameData.COMBAT["potion_heal_pct"])
	SignalBus.combat_log_message.emit("你饮下药水，恢复 %d 生命" % heal, "heal")
	Sfx.play("heal")
	_queue_next(_end_player_turn, 0.3)

# ------------------------------------------------------------
# 回合流转
# ------------------------------------------------------------
func _queue_next(callable: Callable, delay: float) -> void:
	if not is_inside_tree():
		return
	var timer = get_tree().create_timer(delay)
	timer.timeout.connect(callable)

func _end_player_turn() -> void:
	if not _in_combat():
		return
	if _check_combat_end():
		return
	phase = Phase.ENEMY
	combat_data.player_turn = false
	SignalBus.enemy_turn_started.emit()
	_enemy_index = 0
	_enemy_count_this_turn = combat_data.enemies.size()
	_queue_next(_enemy_step, 0.5)

func _enemy_step() -> void:
	if not _in_combat() or phase != Phase.ENEMY:
		return
	var enemies = combat_data.enemies
	while _enemy_index < _enemy_count_this_turn and enemies[_enemy_index].hp <= 0:
		_enemy_index += 1
	if _enemy_index >= _enemy_count_this_turn:
		if _check_combat_end():
			return
		_end_round()
		return

	var e = enemies[_enemy_index]
	SignalBus.enemy_acted.emit(_enemy_index, "act")
	_process_enemy_action(e, _enemy_index)
	if GameState.hp <= 0:
		_combat_end(false)
		return
	_enemy_index += 1
	_queue_next(_enemy_step, 0.55)

func _process_enemy_action(e, idx: int) -> void:
	# Boss 特性
	if e.is_boss and e.traits:
		var T = e.traits
		T.turn += 1
		var traits = T.list

		if traits.has("shield_phase") and not T.shield_used and e.hp <= e.maxhp * 0.5:
			T.shield_used = true
			var s = roundi(e.maxhp * 0.25)
			e.shield += s
			SignalBus.enemy_shield_changed.emit(idx, e.shield)
			SignalBus.combat_log_message.emit("%s 凝聚岩壳进入护盾阶段！+%d 护盾" % [e.name, s], "enemy")
			Sfx.play("shield")
			return

		if traits.has("rage") and not T.raged and e.hp <= e.maxhp * 0.3:
			T.raged = true
			e.atk = roundi(e.atk * 1.5)
			e["raged"] = true
			SignalBus.combat_log_message.emit("%s 双目赤红，陷入狂暴！攻击大幅提升！" % e.name, "enemy")
			Sfx.play("boss")
			return

		if traits.has("heal") and T.turn % 4 == 0 and e.hp < e.maxhp:
			var h = roundi(e.maxhp * 0.12)
			e.hp = mini(e.maxhp, e.hp + h)
			SignalBus.enemy_hp_changed.emit(idx, e.hp, e.maxhp)
			SignalBus.combat_log_message.emit("%s 引导能量，恢复 %d 生命" % [e.name, h], "enemy")
			Sfx.play("heal")
			return

		if traits.has("summon") and T.turn % 3 == 0 and combat_data.enemies.size() < 3:
			var biome = GameData.get_biome(GameState.region)
			var key = biome.enemy_keys[randi() % biome.enemy_keys.size()]
			var template = GameData.get_enemy_type(key)
			var summon = {
				"name": template.name + "·从者",
				"sprite_key": key,
				"palette": template.palette,
				"hp": maxi(1, roundi(e.maxhp * 0.15)),
				"maxhp": maxi(1, roundi(e.maxhp * 0.15)),
				"atk": maxi(1, roundi(e.atk * 0.4)),
				"shield": 0, "is_boss": false, "is_elite": false,
				"traits": null, "scale": 4.0,
				"gold_reward": 0, "anim": 0, "hit_flash": 0, "counted": false,
			}
			combat_data.enemies.append(summon)
			SignalBus.combat_started.emit(combat_data.enemies)
			SignalBus.combat_log_message.emit("%s 召唤了 %s！" % [e.name, summon.name], "enemy")
			Sfx.play("boss")
			return

		if traits.has("heavy") and randf() < 0.3:
			SignalBus.combat_log_message.emit("%s 高高跃起，蓄力重击！" % e.name, "enemy")
			var stats_h = GameState.get_player_stats()
			var raw = DamageCalculator.calc_enemy_damage(roundi(e.atk * 1.6 * randf_range(0.9, 1.1)), stats_h)
			DamageCalculator.apply_damage_to_player(raw, e.name)
			return

	# 普通攻击
	var stats = GameState.get_player_stats()
	var raw = DamageCalculator.calc_enemy_damage(roundi(e.atk * randf_range(0.85, 1.15)), stats)
	DamageCalculator.apply_damage_to_player(raw, e.name)

func _end_round() -> void:
	if not _in_combat():
		return
	phase = Phase.PLAYER
	combat_data.turn += 1
	GameState.run_stats.turns += 1

	var stats = GameState.get_player_stats()
	if stats.regen > 0 and GameState.hp > 0 and GameState.hp < GameState.max_hp:
		GameState.hp = mini(GameState.hp + stats.regen, GameState.max_hp)
		SignalBus.hp_changed.emit(GameState.hp, GameState.max_hp)
		SignalBus.combat_log_message.emit("再生词条：恢复 %d 生命" % stats.regen, "heal")

	if combat_data.skill_cooldown > 0:
		combat_data.skill_cooldown -= 1
		SignalBus.skill_cooldown_changed.emit(combat_data.skill_cooldown)

	combat_data.player_turn = true
	busy = false
	SignalBus.player_turn_started.emit()

# ------------------------------------------------------------
# 结算
# ------------------------------------------------------------
func _get_first_alive_enemy(enemies: Array) -> Dictionary:
	for i in range(enemies.size()):
		if enemies[i].hp > 0:
			return { "index": i, "enemy": enemies[i] }
	return { "index": -1, "enemy": null }

func _kill_check() -> void:
	var stats = GameState.get_player_stats()
	for i in range(combat_data.enemies.size()):
		var e = combat_data.enemies[i]
		if e.hp <= 0 and not e.counted:
			e.counted = true
			GameState.run_stats.kills += 1
			if e.is_boss:
				GameState.run_stats.boss_kills += 1
			elif e.is_elite:
				GameState.run_stats.elite_kills += 1
			SignalBus.enemy_defeated.emit(i)
			if stats.kill_shield > 0:
				combat_data.shield += stats.kill_shield
				SignalBus.shield_changed.emit(combat_data.shield)
				SignalBus.combat_log_message.emit("长剑饮血：击杀获得 %d 护盾" % stats.kill_shield, "system")
			SignalBus.combat_log_message.emit("%s 被击败！" % e.name, "system")

func _check_combat_end() -> bool:
	var all_dead = true
	for e in combat_data.enemies:
		if e.hp > 0:
			all_dead = false
			break
	if all_dead:
		_combat_end(true)
		return true
	if GameState.hp <= 0:
		_combat_end(false)
		return true
	return false

func _combat_end(victory: bool) -> void:
	busy = false
	phase = Phase.END
	if victory:
		var rewards = LootSystem.calculate_combat_rewards(
			combat_data.enemies,
			combat_data.is_boss,
			combat_data.is_elite
		)
		GameState.add_gold(rewards.gold)
		GameState.run_stats.gold_earned += rewards.gold
		if rewards.drop:
			GameState.run_stats.items_looted += 1
		GameState.pending_drop = rewards.drop
		GameState.pending_boss = combat_data.is_boss
		GameState.change_state(GameState.State.REWARD)
		SignalBus.combat_ended.emit(true)
		Sfx.play("victory")
		SignalBus.show_modal.emit("reward", rewards)
	else:
		Sfx.play("defeat")
		GameState.player_defeated()
		SignalBus.combat_ended.emit(false)
