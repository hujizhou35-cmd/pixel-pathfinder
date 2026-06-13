extends Node
class_name CombatStateMachine

const DamageCalculator = preload("res://scripts/combat/damage_calculator.gd")
const LootSystem = preload("res://scripts/equipment/loot_system.gd")

# ============================================================
# 战斗状态机
# - 行动冷却：盾击3 / 防御2 / 药水3 / 斧攻击1（不能无脑堆防御）
# - 武器差异：剑无冷却、盾击先手且护盾+50%、有盾增伤 / 斧 ×1.7 破甲有冷却 / 弓多段（连击体系仅弓生效）
# - 先后手机制：普攻/防御/药水先手（仅"先手"风格怪抢先）；
#   盾击后手（全部敌人先动，剑/疾盾词条/盾击大师天赋可免）
# - 怪物战斗风格：feral 必先手 / guard 周期举盾 / bash 攻击附带护盾
# - 元素触发：雷击/回春/冰缚/引燃/岩盾；克制 ×1.3
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

## 护盾获取统一入口（仅计算量，不入账）
func _shield_gain(stats: Dictionary, base: float) -> int:
	if base <= 0:
		return 0
	return maxi(1, roundi(base * (1.0 + stats.get("shield_gain_pct", 0) / 100.0)))

## 玩家护盾入账统一入口：应用盾魂等加成后，总量不超过最大生命 × 40%
## 返回实际获得量（触顶时被截断）
func _grant_player_shield(stats: Dictionary, base: float) -> int:
	var amt = _shield_gain(stats, base)
	if amt <= 0:
		return 0
	var cap = maxi(1, roundi(GameState.max_hp * GameData.COMBAT["shield_cap_pct"]))
	var before = int(combat_data.shield)
	combat_data.shield = mini(cap, before + amt)
	var gained = combat_data.shield - before
	SignalBus.shield_changed.emit(combat_data.shield)
	if gained < amt:
		SignalBus.combat_log_message.emit("护盾已达上限（最大生命的 %d%%）" % roundi(GameData.COMBAT["shield_cap_pct"] * 100), "system")
	return gained

## 怪物护盾随周目增强的系数
func _enemy_shield_mult() -> float:
	return 1.0 + GameState.cycle * GameData.COMBAT["cycle_enemy_shield_mult"]

## 怪物护盾上限：始终低于其生命上限的 60%
func _cap_enemy_shield(e) -> void:
	var cap = maxi(1, floori(float(e.maxhp) * 0.6))
	if int(e.get("shield", 0)) > cap:
		e.shield = cap

# ------------------------------------------------------------
# 先后手机制
# - 玩家普攻/防御/药水为先手动作：只有"先手(feral)"风格的怪抢先行动
# - 玩家盾击为后手动作：所有敌人先行动（剑/疾盾词条/盾击大师天赋豁免）
# ------------------------------------------------------------
## 在玩家动作前出手的敌人；all_enemies=true 时全部未行动敌人先动
## 返回 false 表示玩家在先手攻击中倒下（动作中止）
func _pre_strike(all_enemies: bool) -> bool:
	var enemies: Array = combat_data.enemies
	for i in range(enemies.size()):
		var e = enemies[i]
		if e.hp <= 0 or e.get("acted", false):
			continue
		if all_enemies or str(e.get("style", "normal")) == "feral":
			if not all_enemies:
				SignalBus.combat_log_message.emit("%s 身手迅捷，抢先出手！" % e.name, "enemy")
			SignalBus.enemy_acted.emit(i, "act")
			e.acted = true
			_process_enemy_action(e, i)
			if GameState.hp <= 0:
				_combat_end(false)
				return false
	return true

## 盾击是否先手：剑专属 / 疾盾词条 / 盾击大师天赋
func _bash_is_fast(stats: Dictionary, wkey: String) -> bool:
	return wkey == "sword" or bool(stats.get("bash_fast", false))

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

	# 先手风格怪抢先行动
	if not _pre_strike(false):
		return

	var stats = GameState.get_player_stats()
	var weapon = GameState.equipment.get("weapon")
	var wkey = weapon.get("key", "sword") if weapon else "sword"

	# 连击数 = 连击词条(multihit) + 贯连/连击之道积累的连击计数（本场战斗有效）
	# 连击体系仅对弓生效，且连击数上限 5
	var bonus_hits = 0
	if wkey == "bow":
		bonus_hits = mini(int(GameData.COMBAT["multihit_cap"]),
			int(stats.get("multihit", 0)) + int(combat_data.get("bow_combo", 0)))
	var hits = 1 + bonus_hits
	var per_mult = 1.0
	match wkey:
		"bow":
			# 弓：基础 2 箭 + 连击数（每箭都是完整 ×0.4 一箭）
			hits = GameData.COMBAT["bow_hits"] + bonus_hits
			per_mult = GameData.COMBAT["bow_hit_mult"]
		"axe":
			per_mult = GameData.COMBAT["axe_dmg_mult"]
	# 单次行动总攻击数硬上限（含迅捷追击）
	var max_attacks = int(GameData.COMBAT["max_attacks_per_action"])
	hits = mini(hits, max_attacks)

	# 攻转盾词条：伤害打折，攻击后按总伤害获得护盾
	if stats.get("atk2shield", false):
		per_mult *= 0.85
	combat_data["crits_this_action"] = 0

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

	# 剑·护盾增伤：护盾在身时普通攻击 +20%
	if wkey == "sword" and int(combat_data.shield) > 0:
		base_extra *= 1.0 + GameData.COMBAT["sword_shield_atk_pct"]
		if not combat_data.get("sword_shield_tip", false):
			combat_data["sword_shield_tip"] = true
			SignalBus.combat_log_message.emit("剑盾合璧：护盾在身，剑刃伤害 +%d%%" % roundi(GameData.COMBAT["sword_shield_atk_pct"] * 100), "system")

	var first_dmg = 0
	var total_dmg = 0
	var attacks_done = 0
	for h in range(hits):
		var target = _resolve_target(target_idx)
		if target.index < 0:
			break
		var hm = per_mult * base_extra
		if h > 0:
			hm *= 1.0 + stats.combo_dmg / 100.0
			# 非弓武器的追加连击按 80% 伤害结算（弓的每箭本就是独立一箭）
			if wkey != "bow":
				hm *= GameData.COMBAT["extra_hit_dmg_mult"]
		var dealt = _do_hit(target.index, hm, stats, wkey)
		attacks_done += 1
		total_dmg += dealt
		if h == 0:
			first_dmg = dealt

	# 贯连词条 / 连击之道天赋：本次行动每次暴击 → 本场战斗连击数 +Lv
	# 仅弓生效，上限 +2（不再是弓的自带能力，需玩家自行搭配词条或天赋）
	var cc = int(stats.get("crit_combo", 0))
	if cc > 0 and wkey == "bow":
		var crits = int(combat_data.get("crits_this_action", 0))
		if crits > 0:
			var cap = int(GameData.COMBAT["bow_combo_cap"])
			var before = int(combat_data.get("bow_combo", 0))
			combat_data.bow_combo = mini(cap, before + crits * cc)
			if combat_data.bow_combo > before:
				SignalBus.combat_log_message.emit("贯连触发！连击数 +%d（本场战斗累计 +%d）" % [combat_data.bow_combo - before, combat_data.bow_combo], "crit")
				SignalBus.bow_combo_changed.emit(combat_data.bow_combo)

	# 攻转盾词条：按总伤害 15% 获得护盾（受护盾上限约束）
	if stats.get("atk2shield", false) and total_dmg > 0:
		var asg = _grant_player_shield(stats, total_dmg * 0.15)
		if asg > 0:
			SignalBus.combat_log_message.emit("攻转盾：获得 %d 护盾" % asg, "system")

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

	# 迅捷词条：概率追加连击（可连续触发，但总攻击数不超过上限 10）
	while attacks_done < max_attacks:
		var t2 = _resolve_target(target_idx)
		if t2.index < 0 or randf() * 100 >= stats.extra_hit:
			break
		var em = GameData.COMBAT["extra_hit_dmg_mult"] * (1.0 + stats.combo_dmg / 100.0)
		SignalBus.combat_log_message.emit("迅捷连击！", "player")
		_do_hit(t2.index, em * per_mult, stats, wkey)
		attacks_done += 1

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
	if result.is_crit:
		combat_data["crits_this_action"] = int(combat_data.get("crits_this_action", 0)) + 1
	SignalBus.player_attacked.emit(t_idx, result.damage, result.is_crit)
	Sfx.play("crit" if result.is_crit else "attack")

	var verbs = { "sword": "你挥剑斩向", "bow": "箭矢射中", "axe": "你抡斧劈向" }
	var msg = "%s %s，造成 %d 点伤害" % [verbs.get(wkey, "你攻击了"), e.name, result.damage]
	if result.is_crit:
		msg = "会心一击！你对 %s 造成 %d 点伤害" % [e.name, result.damage]
	if result.elem_tag != "":
		msg += "（元素%s）" % result.elem_tag
	SignalBus.combat_log_message.emit(msg, "crit" if result.is_crit else "player")

	# 元素触发效果
	if proc != "":
		_apply_elem_proc(proc, e, t_idx, stats, result.damage)

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

	# 斧·破甲打击：命中后降低目标防御 15%/层，持续 2 回合，最多 2 层
	if wkey == "axe" and e.hp > 0:
		var max_st = int(GameData.COMBAT["axe_sunder_stacks"])
		var prev_st = int(e.get("sunder", 0))
		e.sunder = mini(max_st, prev_st + 1)
		e.sunder_turns = int(GameData.COMBAT["axe_sunder_turns"])
		if e.sunder > prev_st:
			SignalBus.combat_log_message.emit("破甲！%s 防御 -%d%%（%d 层）" % [e.name, roundi(GameData.COMBAT["axe_sunder_pct"] * 100 * e.sunder), e.sunder], "player")

	# 荆棘：反弹伤害
	if e.get("affixes", []).has("thorns") and dealt > 0 and GameState.hp > 0:
		var ref = maxi(1, roundi(dealt * 0.20))
		GameState.hp = maxi(0, GameState.hp - ref)
		GameState.run_stats.dmg_taken += ref
		SignalBus.hp_changed.emit(GameState.hp, GameState.max_hp)
		SignalBus.damage_taken.emit("player", ref)
		SignalBus.combat_log_message.emit("%s 的荆棘反弹了 %d 点伤害" % [e.name, ref], "enemy")

	return dealt

## 元素触发效果结算（独立函数：冒烟测试直接调用以验证被动真实生效）
## proc: 元素 key；dmg: 本次命中造成的伤害（回春/数值参考）
func _apply_elem_proc(proc: String, e: Dictionary, t_idx: int, stats: Dictionary, dmg: int) -> void:
	var pname = str(GameData.ELEMENTS.get(proc, {}).get("proc_name", proc))
	SignalBus.elem_proc_triggered.emit(t_idx, pname)
	match proc:
		"metal":
			SignalBus.combat_log_message.emit("「%s」触发：无视护盾，伤害 +15%%！" % pname, "crit")
		"wood":
			var heal = maxi(1, roundi(dmg * 0.30))
			if GameState.hp < GameState.max_hp:
				GameState.hp = mini(GameState.hp + heal, GameState.max_hp)
				SignalBus.hp_changed.emit(GameState.hp, GameState.max_hp)
				SignalBus.combat_log_message.emit("「%s」触发：恢复 %d 生命" % [pname, heal], "heal")
		"water":
			e.weaken = 2
			SignalBus.combat_log_message.emit("「%s」触发：%s 攻击 -30%%（2 回合）" % [pname, e.name], "system")
			SignalBus.enemy_hp_changed.emit(t_idx, e.hp, e.maxhp)
		"fire":
			_ignite(e, stats, t_idx)
			SignalBus.combat_log_message.emit("「%s」触发：%s 燃烧起来了！" % [pname, e.name], "crit")
		"earth":
			var sg = _grant_player_shield(stats, GameData.COMBAT["earth_shield_base"] + stats.def * GameData.COMBAT["earth_shield_def_mult"])
			SignalBus.combat_log_message.emit("「%s」触发：获得 %d 护盾" % [pname, sg], "system")

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
	var weapon = GameState.equipment.get("weapon")
	var wkey = weapon.get("key", "sword") if weapon else "sword"

	# 盾击默认后手：所有敌人先行动（剑 / 疾盾词条 / 盾击大师天赋豁免）
	var is_fast = _bash_is_fast(stats, wkey)
	combat_data["last_action_slow"] = not is_fast
	if not is_fast:
		SignalBus.combat_log_message.emit("你蓄力盾击（后手）——敌人抢先行动！", "system")
		if not _pre_strike(true):
			return
	else:
		if not _pre_strike(false):
			return

	var target = _resolve_target(target_idx)
	if target.index >= 0:
		var dmg_mult: float = GameData.COMBAT["skill_dmg_mult"]
		var shield_base: float = GameData.COMBAT["base_skill_shield"] + stats.def * GameData.COMBAT["skill_shield_def_mult"]
		# 剑·盾击精通：盾击获得的护盾量 +50%
		if wkey == "sword":
			shield_base *= GameData.COMBAT["sword_bash_shield_mult"]
		# 盾转攻词条：护盾减半 → 伤害 +60%
		if stats.get("shield2atk", false):
			dmg_mult *= 1.6
			shield_base *= 0.5
		_do_hit(target.index, dmg_mult, stats, wkey)
		Sfx.play("skill")

		var shield_amt = _grant_player_shield(stats, shield_base)
		combat_data.skill_cooldown = maxi(1, int(GameData.COMBAT["skill_cooldown"]) - int(stats.get("bash_cd_reduce", 0)))
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
	if not _pre_strike(false):
		return
	var stats = GameState.get_player_stats()
	var shield_amt = _grant_player_shield(stats, GameData.COMBAT["base_def_shield"] + stats.def * GameData.COMBAT["def_shield_def_mult"])
	combat_data.cooldowns["defend"] = GameData.COMBAT["defend_cooldown"] + 1
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
	if not _pre_strike(false):
		return
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
	# 跳过已死亡与本回合已行动（先手抢攻过）的敌人
	while _enemy_index < _enemy_count_this_turn and (enemies[_enemy_index].hp <= 0 or enemies[_enemy_index].get("acted", false)):
		_enemy_index += 1
	if _enemy_index >= _enemy_count_this_turn:
		if _check_combat_end():
			return
		_end_round()
		return

	var e = enemies[_enemy_index]
	SignalBus.enemy_acted.emit(_enemy_index, "act")
	e.acted = true
	_process_enemy_action(e, _enemy_index)
	_kill_check()
	if GameState.hp <= 0:
		_combat_end(false)
		return
	_enemy_index += 1
	_queue_next(_enemy_step, 0.55)

func _process_enemy_action(e, idx: int) -> void:
	# 灼烧结算（无视护盾与防御）
	if int(e.get("burn", 0)) > 0:
		e.burn -= 1
		var bd = int(e.get("burn_dmg", 1))
		DamageCalculator.apply_damage_to_enemy(e, bd, false, { "pierce_shield": true, "ignore_def": true })
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

	# 坚守风格：周期性举盾（第 1、4、7…回合防御，跳过攻击；护盾随周目增强）
	if str(e.get("style", "normal")) == "guard":
		e.guard_turn = int(e.get("guard_turn", 0)) + 1
		if (e.guard_turn - 1) % 3 == 0:
			var gs = maxi(2, roundi(e.maxhp * 0.12 * _enemy_shield_mult()))
			e.shield += gs
			_cap_enemy_shield(e)
			SignalBus.enemy_shield_changed.emit(idx, e.shield)
			SignalBus.combat_log_message.emit("%s 举盾坚守，获得 %d 护盾（本回合不攻击）" % [e.name, gs], "enemy")
			Sfx.play("shield")
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

	# 盾击风格：攻击同时获得护盾（护盾随周目增强）
	if str(e.get("style", "normal")) == "bash" and e.hp > 0:
		var bs = maxi(1, roundi(float(e.atk) * 0.6 * _enemy_shield_mult()))
		e.shield += bs
		_cap_enemy_shield(e)
		SignalBus.enemy_shield_changed.emit(idx, e.shield)
		SignalBus.combat_log_message.emit("%s 盾击姿态：获得 %d 护盾" % [e.name, bs], "enemy")

	# 削弱回合数衰减
	if int(e.get("weaken", 0)) > 0:
		e.weaken -= 1
		if e.weaken == 0:
			SignalBus.combat_log_message.emit("%s 摆脱了缠流" % e.name, "system")

	# 破甲回合数衰减
	if int(e.get("sunder_turns", 0)) > 0:
		e.sunder_turns -= 1
		if e.sunder_turns == 0 and int(e.get("sunder", 0)) > 0:
			e.sunder = 0
			SignalBus.combat_log_message.emit("%s 的甲胄恢复了" % e.name, "system")

## Boss 特性行动；返回 true 表示本回合用掉了行动
func _boss_trait_action(e, idx: int) -> bool:
	var T = e.traits
	T.turn += 1
	var traits = T.list

	if traits.has("shield_phase") and not T.shield_used and e.hp <= e.maxhp * 0.5:
		T.shield_used = true
		var s = roundi(e.maxhp * 0.25 * _enemy_shield_mult())
		e.shield += s
		_cap_enemy_shield(e)
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
			"def": maxi(0, roundi(int(e.get("def", 0)) * 0.5)),
			"shield": 0, "is_boss": false, "is_elite": false,
			"traits": null, "scale": 4.0,
			"affixes": [], "element": str(biome.get("element", "")),
			"style": str(template.get("style", "normal")),
			"stun": 0, "weaken": 0, "burn": 0, "burn_dmg": 0, "berserk_done": false,
			"sunder": 0, "sunder_turns": 0,
			"acted": true, "guard_turn": 0,
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

	# 重置先后手行动标记
	for e in combat_data.enemies:
		e.acted = false

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
				var ks = _grant_player_shield(stats, stats.kill_shield)
				if ks > 0:
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
		var is_cycle = bool(combat_data.get("cycle_boss", false))
		var rewards = LootSystem.calculate_combat_rewards(
			combat_data.enemies,
			combat_data.is_boss,
			combat_data.is_elite,
			"cycleboss" if is_cycle else ""
		)
		GameState.add_gold(rewards.gold)
		GameState.run_stats.gold_earned += rewards.gold
		if rewards.drop:
			GameState.run_stats.items_looted += 1
		GameState.pending_drop = rewards.drop
		# 周目大 Boss 走专属胜利链（战败 CG + 新周目欢迎 → 进入下一周目）
		GameState.pending_cycle_boss = is_cycle
		GameState.pending_boss = combat_data.is_boss and not is_cycle
		GameState.change_state(GameState.State.REWARD)
		SignalBus.combat_ended.emit(true)
		Sfx.play("victory")
		SignalBus.show_modal.emit("reward", rewards)
	else:
		Sfx.play("defeat")
		GameState.player_defeated()
		SignalBus.combat_ended.emit(false)
