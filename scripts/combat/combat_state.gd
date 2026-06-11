extends Node
class_name CombatStateMachine

const DamageCalculator = preload("res://scripts/combat/damage_calculator.gd")
const LootSystem = preload("res://scripts/equipment/loot_system.gd")

# ============================================================
# 战斗状态机
# - 行动冷却：盾击3 / 防御2 / 药水3 / 斧攻击1（不能无脑堆防御）
# - 武器差异：剑标准无冷却 / 斧 ×1.55 有冷却 / 弓双段独立触发特效
# - 五行触发：锐金/回春/缠流/引燃/厚土；克制 ×1.3
# - 怪物词条运行时：穿甲/嗜血/迅捷双动/荆棘/再生/狂暴/虚体/眩晕…
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

	# 敌方词条提示
	for e in data.enemies:
		var afx: Array = e.get("affixes", [])
		if afx.size() > 0:
			SignalBus.combat_log_message.emit("%s 带有词条：%s" % [e.name, GameData.monster_affix_names(afx)], "enemy")

	# 护符 +5 / 晨曦套装：战斗开始时恢复生命
	var stats = GameState.get_player_stats()
	if stats.battle_heal > 0 and GameState.hp > 0 and GameState.hp < GameState.max_hp:
		var heal = roundi(GameState.max_hp * stats.battle_heal)
		GameState.hp = mini(GameState.hp + heal, GameState.max_hp)
		SignalBus.hp_changed.emit(GameState.hp, GameState.max_hp)
		SignalBus.combat_log_message.emit("微光闪烁：恢复 %d 生命" % heal, "system")

	if combat_data.shield > 0:
		SignalBus.shield_changed.emit(combat_data.shield)

	SignalBus.cooldowns_changed.emit()
	SignalBus.player_turn_started.emit()

func _in_combat() -> bool:
	return is_inside_tree() and GameState.current_state == GameState.State.COMBAT and not combat_data.is_empty()

func can_player_act() -> bool:
	return phase == Phase.PLAYER and not busy and combat_data.get("player_turn", false)

func get_cooldown(action: String) -> int:
	return int(combat_data.get("cooldowns", {}).get(action, 0))

func _resolve_target(target_idx: int) -> Dictionary:
	var enemies = combat_data.enemies
	if target_idx >= 0 and target_idx < enemies.size() and enemies[target_idx].hp > 0:
		return { "index": target_idx, "enemy": enemies[target_idx] }
	return _get_first_alive_enemy(enemies)

## 护盾获取统一入口
func _shield_gain(stats: Dictionary, base: float) -> int:
	if base <= 0:
		return 0
	return maxi(1, roundi(base * (1.0 + stats.get("shield_gain_pct", 0) / 100.0)))

# ------------------------------------------------------------
# 玩家行动
# ------------------------------------------------------------
func player_attack(target_idx: int = -1) -> void:
	if not can_player_act():
		return
	if get_cooldown("attack") > 0:
		SignalBus.show_toast.emit("武器尚在冷却")
		return
	busy = true

	var stats = GameState.get_player_stats()
	var weapon = GameState.equipment.get("weapon")
	var wkey = weapon.get("key", "sword") if weapon else "sword"

	var hits = 1
	var per_mult = 1.0
	match wkey:
		"bow":
			hits = GameData.COMBAT["bow_hits"]
			per_mult = GameData.COMBAT["bow_hit_mult"]
		"axe":
			per_mult = GameData.COMBAT["axe_dmg_mult"]

	# 全局增伤：晨曦首回合 / 蓄势爆发 / 长弓首击
	var base_extra = 1.0
	if combat_data.turn == 0 and stats.first_turn_pct > 0:
		base_extra *= 1.0 + stats.first_turn_pct / 100.0
	if combat_data.get("focus", 0) > 0:
		base_extra *= 1.0 + 0.30 * combat_data.focus
		SignalBus.combat_log_message.emit("蓄势爆发！%d 层蓄势全部释放（伤害 +%d%%）" % [combat_data.focus, combat_data.focus * 30], "crit")
		combat_data.focus = 0
		SignalBus.cooldowns_changed.emit()
	if combat_data.first_attack and stats.first_double:
		base_extra *= 2.0
		SignalBus.combat_log_message.emit("长弓蓄势：首击双倍伤害！", "system")
	combat_data.first_attack = false

	var first_dmg = 0
	for h in range(hits):
		var target = _resolve_target(target_idx)
		if target.index < 0:
			break
		var hm = per_mult * base_extra
		if h > 0:
			hm *= 1.0 + stats.combo_dmg / 100.0
		var dealt = _do_hit(target.index, hm, stats, wkey)
		if h == 0:
			first_dmg = dealt

	# 斧攻击冷却（攻击后下回合不可攻击 → 防御蓄势的节奏）
	if wkey == "axe":
		combat_data.cooldowns["attack"] = GameData.COMBAT["axe_cooldown"] + 1
		SignalBus.cooldowns_changed.emit()

	# 连锁词条：溅射（按首段伤害）
	if stats.splash > 0 and first_dmg > 0:
		var enemies = combat_data.enemies
		var main = _resolve_target(target_idx)
		for i in range(enemies.size()):
			if i == main.index or enemies[i].hp <= 0:
				continue
			var sd = max(1, roundi(first_dmg * stats.splash / 100.0))
			DamageCalculator.apply_damage_to_enemy(enemies[i], sd, false)
			GameState.run_stats.dmg_dealt += sd
			SignalBus.player_attacked.emit(i, sd, false)
			SignalBus.combat_log_message.emit("剑气溅射 %s，造成 %d 点伤害" % [enemies[i].name, sd], "player")

	# 迅捷词条：追加连击
	var t2 = _resolve_target(target_idx)
	if t2.index >= 0 and randf() * 100 < stats.extra_hit:
		var em = GameData.COMBAT["extra_hit_dmg_mult"] * (1.0 + stats.combo_dmg / 100.0)
		SignalBus.combat_log_message.emit("迅捷连击！", "player")
		_do_hit(t2.index, em * per_mult, stats, wkey)

	_kill_check()
	_queue_next(_end_player_turn, 0.45)

## 单次命中结算：闪避 → 元素触发 → 伤害 → 词条触发 → 荆棘反伤
## 返回实际造成的伤害（供溅射基准）
func _do_hit(t_idx: int, mult: float, stats: Dictionary, wkey: String) -> int:
	var enemies = combat_data.enemies
	if t_idx < 0 or t_idx >= enemies.size():
		return 0
	var e = enemies[t_idx]
	if e.hp <= 0:
		return 0

	# 虚体：闪避
	if e.get("affixes", []).has("ethereal") and randf() < 0.25:
		SignalBus.player_attacked.emit(t_idx, 0, false)
		SignalBus.combat_log_message.emit("%s 虚体一闪，躲过了攻击！" % e.name, "enemy")
		return 0

	# 元素触发判定（每次命中独立判定 → 弓双段触发率高）
	var proc = ""
	var welem = str(stats.get("weapon_element", ""))
	if welem != "" and randf() * 100 < GameData.COMBAT["elem_proc_chance"] + stats.get("elem_proc", 0):
		proc = welem

	var hit_mult = mult
	var opts = {}
	if proc == "metal":
		opts["pierce_shield"] = true
		hit_mult *= 1.15

	var result = DamageCalculator.calc_player_hit(stats, e, hit_mult)
	var dealt = DamageCalculator.apply_damage_to_enemy(e, result.damage, result.is_crit, opts)
	GameState.run_stats.dmg_dealt += result.damage
	SignalBus.player_attacked.emit(t_idx, result.damage, result.is_crit)
	Sfx.play("crit" if result.is_crit else "attack")

	var verbs = { "sword": "你挥剑斩向", "bow": "箭矢射中", "axe": "你抡斧劈向" }
	var msg = "%s %s，造成 %d 点伤害" % [verbs.get(wkey, "你攻击了"), e.name, result.damage]
	if result.is_crit:
		msg = "会心一击！你对 %s 造成 %d 点伤害" % [e.name, result.damage]
	if result.elem_tag != "":
		msg += "（五行%s）" % result.elem_tag
	SignalBus.combat_log_message.emit(msg, "crit" if result.is_crit else "player")

	# 元素触发效果
	match proc:
		"metal":
			SignalBus.combat_log_message.emit("「锐金」触发：无视护盾，伤害 +15%！", "crit")
		"wood":
			var heal = maxi(1, roundi(result.damage * 0.30))
			if GameState.hp < GameState.max_hp:
				GameState.hp = mini(GameState.hp + heal, GameState.max_hp)
				SignalBus.hp_changed.emit(GameState.hp, GameState.max_hp)
				SignalBus.combat_log_message.emit("「回春」触发：恢复 %d 生命" % heal, "heal")
		"water":
			e.weaken = 2
			SignalBus.combat_log_message.emit("「缠流」触发：%s 攻击 -30%%（2 回合）" % e.name, "system")
			SignalBus.enemy_hp_changed.emit(t_idx, e.hp, e.maxhp)
		"fire":
			_ignite(e, stats, t_idx)
			SignalBus.combat_log_message.emit("「引燃」触发：%s 燃烧起来了！" % e.name, "crit")
		"earth":
			var sg = _shield_gain(stats, 6.0 + stats.def * 0.8)
			combat_data.shield += sg
			SignalBus.shield_changed.emit(combat_data.shield)
			SignalBus.combat_log_message.emit("「厚土」触发：获得 %d 护盾" % sg, "system")

	# 装备词条触发（每次命中独立判定）
	if e.hp > 0 and stats.stun_chance > 0 and randf() * 100 < stats.stun_chance:
		e.stun = 1
		SignalBus.combat_log_message.emit("震慑！%s 被眩晕，下回合无法行动" % e.name, "crit")
		SignalBus.enemy_hp_changed.emit(t_idx, e.hp, e.maxhp)
	if e.hp > 0 and stats.burn_chance > 0 and randf() * 100 < stats.burn_chance:
		_ignite(e, stats, t_idx)
		SignalBus.combat_log_message.emit("燃焰词条：%s 被点燃！" % e.name, "player")
	if e.hp > 0 and stats.weaken_chance > 0 and randf() * 100 < stats.weaken_chance:
		e.weaken = maxi(e.weaken, 2)
		SignalBus.combat_log_message.emit("寒霜侵蚀：%s 攻击被削弱" % e.name, "system")
	if stats.lifesteal > 0 and dealt > 0 and GameState.hp < GameState.max_hp:
		var ls = maxi(1, roundi(result.damage * stats.lifesteal / 100.0))
		GameState.hp = mini(GameState.hp + ls, GameState.max_hp)
		SignalBus.hp_changed.emit(GameState.hp, GameState.max_hp)
		SignalBus.combat_log_message.emit("吸血：恢复 %d 生命" % ls, "heal")

	# 荆棘：反弹伤害
	if e.get("affixes", []).has("thorns") and dealt > 0 and GameState.hp > 0:
		var ref = maxi(1, roundi(dealt * 0.20))
		GameState.hp = maxi(0, GameState.hp - ref)
		GameState.run_stats.dmg_taken += ref
		SignalBus.hp_changed.emit(GameState.hp, GameState.max_hp)
		SignalBus.damage_taken.emit("player", ref)
		SignalBus.combat_log_message.emit("%s 的荆棘反弹了 %d 点伤害" % [e.name, ref], "enemy")

	return dealt

func _ignite(e: Dictionary, stats: Dictionary, idx: int) -> void:
	e.burn = GameData.COMBAT["burn_turns"]
	var mult = 2.0 if stats.get("burn_x2", false) else 1.0
	e.burn_dmg = maxi(1, roundi(stats.atk * GameData.COMBAT["burn_atk_pct"] * mult))
	SignalBus.enemy_hp_changed.emit(idx, e.hp, e.maxhp)

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

	var weapon = GameState.equipment.get("weapon")
	var wkey = weapon.get("key", "sword") if weapon else "sword"
	_do_hit(target.index, GameData.COMBAT["skill_dmg_mult"], stats, wkey)
	Sfx.play("skill")

	var shield_amt = _shield_gain(stats, GameData.COMBAT["base_skill_shield"] + stats.def * GameData.COMBAT["skill_shield_def_mult"])
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
	if get_cooldown("defend") > 0:
		SignalBus.show_toast.emit("防御尚在冷却（%d 回合）" % get_cooldown("defend"))
		return
	busy = true
	var stats = GameState.get_player_stats()
	var shield_amt = _shield_gain(stats, GameData.COMBAT["base_def_shield"] + stats.def * GameData.COMBAT["def_shield_def_mult"])
	combat_data.shield += shield_amt
	combat_data.cooldowns["defend"] = GameData.COMBAT["defend_cooldown"] + 1
	SignalBus.shield_changed.emit(combat_data.shield)
	SignalBus.combat_log_message.emit("你举盾固守：+%d 护盾" % shield_amt, "player")
	# 蓄势词条：防御积累爆发
	if stats.get("has_focus", false) and combat_data.get("focus", 0) < 3:
		combat_data.focus = combat_data.get("focus", 0) + 1
		SignalBus.combat_log_message.emit("蓄势 %d 层（下次攻击每层 +30%%）" % combat_data.focus, "system")
	SignalBus.cooldowns_changed.emit()
	Sfx.play("shield")
	_queue_next(_end_player_turn, 0.3)

func player_potion() -> void:
	if not can_player_act():
		return
	if get_cooldown("potion") > 0:
		SignalBus.show_toast.emit("药水尚在冷却（%d 回合）" % get_cooldown("potion"))
		return
	if GameState.potions <= 0:
		return
	if GameState.hp >= GameState.max_hp:
		SignalBus.show_toast.emit("生命已满，无需饮用药水")
		return
	busy = true
	var stats = GameState.get_player_stats()
	var heal = GameState.use_potion(stats.get("potion_bonus_pct", 0))
	var cd = GameData.COMBAT["potion_cooldown"] + 1 - int(stats.get("potion_cd_reduce", 0))
	combat_data.cooldowns["potion"] = maxi(2, cd)
	SignalBus.cooldowns_changed.emit()
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
	_kill_check()
	if GameState.hp <= 0:
		_combat_end(false)
		return
	_enemy_index += 1
	_queue_next(_enemy_step, 0.55)

func _process_enemy_action(e, idx: int) -> void:
	# 灼烧结算
	if int(e.get("burn", 0)) > 0:
		e.burn -= 1
		var bd = int(e.get("burn_dmg", 1))
		DamageCalculator.apply_damage_to_enemy(e, bd, false, { "pierce_shield": true })
		GameState.run_stats.dmg_dealt += bd
		SignalBus.player_attacked.emit(idx, bd, false)
		SignalBus.combat_log_message.emit("%s 被灼烧，受到 %d 点伤害" % [e.name, bd], "crit")
		if e.hp <= 0:
			return

	# 眩晕：跳过行动
	if int(e.get("stun", 0)) > 0:
		e.stun -= 1
		SignalBus.combat_log_message.emit("%s 眩晕中，无法行动！" % e.name, "system")
		SignalBus.enemy_hp_changed.emit(idx, e.hp, e.maxhp)
		return

	var afx: Array = e.get("affixes", [])

	# 再生词条
	if afx.has("regen") and e.hp > 0 and e.hp < e.maxhp:
		var rh = maxi(1, roundi(e.maxhp * 0.06))
		e.hp = mini(e.maxhp, e.hp + rh)
		SignalBus.enemy_hp_changed.emit(idx, e.hp, e.maxhp)
		SignalBus.combat_log_message.emit("%s 的伤口正在再生（+%d）" % [e.name, rh], "enemy")

	# 狂暴词条
	if afx.has("berserk") and not e.get("berserk_done", false) and e.hp <= e.maxhp * 0.5:
		e.berserk_done = true
		e.atk = roundi(e.atk * 1.4)
		SignalBus.combat_log_message.emit("%s 进入狂暴状态！攻击 +40%%" % e.name, "enemy")
		Sfx.play("boss")

	# Boss 特性
	if e.is_boss and e.traits:
		if _boss_trait_action(e, idx):
			return

	# 普通攻击（迅捷词条：双动）
	var stats = GameState.get_player_stats()
	var acts = 2 if afx.has("swift") else 1
	for i in range(acts):
		if GameState.hp <= 0 or e.hp <= 0:
			break
		var atk_eff = float(e.atk)
		if int(e.get("weaken", 0)) > 0:
			atk_eff *= 1.0 - GameData.COMBAT["weaken_pct"]
		if i > 0:
			atk_eff *= 0.6
			SignalBus.combat_log_message.emit("%s 迅捷追击！" % e.name, "enemy")
		var raw = DamageCalculator.calc_enemy_damage(roundi(atk_eff * randf_range(0.85, 1.15)), stats, str(e.get("element", "")))
		var dealt = DamageCalculator.apply_damage_to_player(raw, e.name, afx.has("piercing"))
		if afx.has("vampiric") and dealt > 0 and e.hp < e.maxhp:
			var vh = maxi(1, roundi(dealt * 0.4))
			e.hp = mini(e.maxhp, e.hp + vh)
			SignalBus.enemy_hp_changed.emit(idx, e.hp, e.maxhp)
			SignalBus.combat_log_message.emit("%s 嗜血吸取了 %d 生命" % [e.name, vh], "enemy")

	# 削弱回合数衰减
	if int(e.get("weaken", 0)) > 0:
		e.weaken -= 1
		if e.weaken == 0:
			SignalBus.combat_log_message.emit("%s 摆脱了缠流" % e.name, "system")

## Boss 特性行动；返回 true 表示本回合用掉了行动
func _boss_trait_action(e, idx: int) -> bool:
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
		return true

	if traits.has("rage") and not T.raged and e.hp <= e.maxhp * 0.3:
		T.raged = true
		e.atk = roundi(e.atk * 1.5)
		e["raged"] = true
		SignalBus.combat_log_message.emit("%s 双目赤红，陷入狂暴！攻击大幅提升！" % e.name, "enemy")
		Sfx.play("boss")
		return true

	if traits.has("heal") and T.turn % 4 == 0 and e.hp < e.maxhp:
		var h = roundi(e.maxhp * 0.12)
		e.hp = mini(e.maxhp, e.hp + h)
		SignalBus.enemy_hp_changed.emit(idx, e.hp, e.maxhp)
		SignalBus.combat_log_message.emit("%s 引导能量，恢复 %d 生命" % [e.name, h], "enemy")
		Sfx.play("heal")
		return true

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
			"base_atk": maxi(1, roundi(e.atk * 0.4)),
			"shield": 0, "is_boss": false, "is_elite": false,
			"traits": null, "scale": 4.0,
			"affixes": [], "element": str(biome.get("element", "")),
			"stun": 0, "weaken": 0, "burn": 0, "burn_dmg": 0, "berserk_done": false,
			"gold_reward": 0, "anim": 0, "hit_flash": 0, "counted": false,
		}
		combat_data.enemies.append(summon)
		SignalBus.combat_started.emit(combat_data.enemies)
		SignalBus.combat_log_message.emit("%s 召唤了 %s！" % [e.name, summon.name], "enemy")
		Sfx.play("boss")
		return true

	if traits.has("heavy") and randf() < 0.3:
		SignalBus.combat_log_message.emit("%s 高高跃起，蓄力重击！" % e.name, "enemy")
		var stats_h = GameState.get_player_stats()
		var atk_eff = e.atk * (1.0 - GameData.COMBAT["weaken_pct"] if int(e.get("weaken", 0)) > 0 else 1.0)
		var raw = DamageCalculator.calc_enemy_damage(roundi(atk_eff * 1.6 * randf_range(0.9, 1.1)), stats_h, str(e.get("element", "")))
		DamageCalculator.apply_damage_to_player(raw, e.name, e.get("affixes", []).has("piercing"))
		return true

	return false

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

	# 行动冷却衰减
	var cds: Dictionary = combat_data.get("cooldowns", {})
	for k in cds:
		if cds[k] > 0:
			cds[k] -= 1
	SignalBus.cooldowns_changed.emit()

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
				var ks = _shield_gain(stats, stats.kill_shield)
				combat_data.shield += ks
				SignalBus.shield_changed.emit(combat_data.shield)
				SignalBus.combat_log_message.emit("长剑饮血：击杀获得 %d 护盾" % ks, "system")
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
