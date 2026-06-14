class_name CombatManager
extends RefCounted

# ============================================================
# 战斗管理器
# - roll_foes: 预先掷出关卡的怪物构成（种类/词条/元素），供地图预览
# - build_enemy: 按构成确定性地生成战斗实例（预览数值 = 实战数值）
# - 数值随区域与无限周目(cycle)缩放；词条组合产生大量变种
# ============================================================

## 掷出一场战斗的怪物构成；存入地图节点，进场前可预览
static func roll_foes(region: int, cycle: int, elite: bool, boss: bool) -> Array:
	var biome = GameData.get_biome(region)
	var foes = []
	if boss:
		foes.append(_roll_foe(region, cycle, biome, false, true))
	elif elite:
		foes.append(_roll_foe(region, cycle, biome, true, false))
	else:
		var roll = randf()
		var n = 1
		if roll < 0.15:
			n = 3
		elif roll < 0.60:
			n = 2
		for i in range(n):
			foes.append(_roll_foe(region, cycle, biome, false, false))
	return foes

static func _roll_foe(region: int, cycle: int, biome: Dictionary, elite: bool, boss: bool) -> Dictionary:
	var key = ""
	var innate = ""
	if boss:
		key = "boss"
	else:
		key = biome.enemy_keys[randi() % biome.enemy_keys.size()]
		innate = str(GameData.get_enemy_type(key).get("innate", ""))

	# 元素：默认随区域，30% 变异成其它元素
	var elem = str(biome.get("element", "wood"))
	if randf() < 0.30:
		elem = GameData.ELEMENT_KEYS[randi() % GameData.ELEMENT_KEYS.size()]

	# 词条：自带 + 随机追加（区域/周目/级别越高越多）
	var affixes = []
	if innate != "":
		affixes.append(innate)
	var extra = 0
	if boss:
		extra = 2
	elif elite:
		extra = 1 + (1 if region >= 3 or cycle > 0 else 0)
	else:
		var chance = 0.20 + region * 0.07 + cycle * 0.20
		if randf() < chance:
			extra = 1
		if cycle > 0 and randf() < 0.25:
			extra += 1
	var pool = GameData.MONSTER_AFFIX_KEYS.duplicate()
	pool.shuffle()
	for k in pool:
		if extra <= 0:
			break
		if affixes.has(k):
			continue
		affixes.append(k)
		extra -= 1

	return { "key": key, "elite": elite, "boss": boss, "affixes": affixes, "element": elem }

## 确定性数值（供预览与实战共用）
## 有效区域 = 区域 + 周目×5：新周目区域 1 的敌人严格强于上一周目区域 5，无限递增
static func enemy_stats_for(foe: Dictionary, region: int, cycle: int) -> Dictionary:
	var boss = bool(foe.get("boss", false))
	var elite = bool(foe.get("elite", false))
	var hp_mult = 1.0
	var atk_mult = 1.0
	var def_mult = 1.0
	if not boss:
		var t = GameData.get_enemy_type(str(foe.key))
		hp_mult = t.hp_mult
		atk_mult = t.atk_mult
	if boss:
		hp_mult *= 5.5
		atk_mult *= 1.5
		def_mult *= 1.6
	elif elite:
		hp_mult *= 2.2
		atk_mult *= 1.3
		def_mult *= 1.3
	var affixes: Array = foe.get("affixes", [])
	if affixes.has("tough"):
		hp_mult *= 1.5
	if affixes.has("mighty"):
		atk_mult *= 1.3
	# 周目缩放：按"有效区域"继续沿区域曲线成长（区域 + 周目×5）
	var eff = float(region + cycle * 5)
	return {
		"hp": maxi(1, roundi((20.0 + eff * 16.0) * hp_mult)),
		"atk": maxi(1, roundi((10.0 + eff * 7.0) * atk_mult)),
		"def": maxi(1, roundi((2.0 + eff * 2.2) * def_mult)),
	}

## 按构成生成战斗实例
static func build_enemy(foe: Dictionary, region: int, cycle: int) -> Dictionary:
	var biome = GameData.get_biome(region)
	var boss = bool(foe.get("boss", false))
	var elite = bool(foe.get("elite", false))
	var st = enemy_stats_for(foe, region, cycle)
	var affixes: Array = foe.get("affixes", []).duplicate()

	var name: String
	var sprite_key: String
	var palette: Dictionary
	var traits = null
	var style := "normal"
	if boss:
		name = biome.boss.name
		sprite_key = "boss"
		palette = biome.boss.palette
		traits = {
			"list": biome.boss.traits.duplicate(),
			"shield_used": false,
			"raged": false,
			"turn": 0,
		}
	else:
		var template = GameData.get_enemy_type(str(foe.key))
		name = ("精英" + template.name) if elite else template.name
		sprite_key = str(foe.key)
		palette = template.palette
		style = str(template.get("style", "normal"))

	var gold_mult = 6.0 if boss else (3.0 if elite else 1.0)
	var gold_reward = roundi((8.0 + region * 6.0) * gold_mult * (1.0 + cycle * GameData.COMBAT["cycle_gold_mult"]) * randf_range(0.8, 1.2))

	var shield = 0
	if affixes.has("shielded"):
		# 结界护盾随周目增强；但始终低于生命上限的 60%
		shield = roundi(st.hp * 0.25 * (1.0 + cycle * GameData.COMBAT["cycle_enemy_shield_mult"]))
		shield = mini(shield, maxi(1, floori(st.hp * 0.6)))

	return {
		"name": name,
		"sprite_key": sprite_key,
		"palette": palette,
		"maxhp": st.hp,
		"hp": st.hp,
		"atk": st.atk,
		"base_atk": st.atk,
		"def": st.def,
		"gold_reward": gold_reward,
		"shield": shield,
		"is_boss": boss,
		"is_elite": elite,
		"traits": traits,
		"affixes": affixes,
		"element": str(foe.get("element", "")),
		"style": style,
		"scale": 7.0 if boss else (5.4 if elite else 4.4),
		"anim": 0,
		"hit_flash": 0,
		"counted": false,
		# 运行时状态
		"stun": 0,
		"weaken": 0,
		"burn": 0,
		"burn_dmg": 0,
		"sunder": 0,           # 斧破甲：层数（每层防御 -15%）
		"sunder_turns": 0,     # 斧破甲：剩余回合
		"berserk_done": false,
		"acted": false,        # 先后手机制：本回合是否已行动
		"guard_turn": 0,       # 坚守风格：举盾计数
	}

## 周目大 Boss 实例：以末区 Boss 数值为基底，再乘 bdef 倍率（明显强于区域 Boss）
static func build_cycle_boss_enemy(bdef: Dictionary, region: int, cycle: int) -> Dictionary:
	var base = enemy_stats_for({ "boss": true, "affixes": [] }, region, cycle)
	var hp = maxi(1, roundi(base.hp * float(bdef.get("hp_mult", 1.5))))
	var atk = maxi(1, roundi(base.atk * float(bdef.get("atk_mult", 1.5))))
	var df = maxi(1, roundi(base.def * float(bdef.get("def_mult", 1.4))))
	var gold_reward = roundi((8.0 + region * 6.0) * 9.0 * (1.0 + cycle * GameData.COMBAT["cycle_gold_mult"]) * randf_range(0.9, 1.1))
	return {
		"name": str(bdef.name),
		"sprite_key": str(bdef.get("sprite", "boss")),
		"cycle_boss": true,
		"cycle_sprite": str(bdef.get("sprite", "boss")),
		"palette": bdef.palette,
		"maxhp": hp,
		"hp": hp,
		"atk": atk,
		"base_atk": atk,
		"def": df,
		"gold_reward": gold_reward,
		"shield": 0,
		"is_boss": true,
		"is_elite": false,
		"traits": { "list": bdef.get("traits", []).duplicate(), "shield_used": false, "raged": false, "turn": 0 },
		"affixes": [],
		"element": "",
		"style": "normal",
		"scale": 8.2,
		"anim": 0, "hit_flash": 0, "counted": false,
		"stun": 0, "weaken": 0, "burn": 0, "burn_dmg": 0,
		"sunder": 0, "sunder_turns": 0, "berserk_done": false,
		"acted": false, "guard_turn": 0,
	}

## 建立周目大 Boss 战斗（单体压轴战）
static func setup_cycle_boss(cycle: int, bdef: Dictionary) -> Dictionary:
	var region = GameData.BIOMES.size() - 1
	var data = setup_combat(region, cycle, false, false, [])
	data.enemies = [build_cycle_boss_enemy(bdef, region, cycle)]
	data.is_boss = true
	data.cycle_boss = true
	return data

## 建立战斗数据；foes 为空时现场掷一组（事件遭遇战等）
static func setup_combat(region: int, cycle: int, elite: bool, boss: bool, foes: Array = []) -> Dictionary:
	if foes.is_empty():
		foes = roll_foes(region, cycle, elite, boss)
	var enemies = []
	for foe in foes:
		enemies.append(build_enemy(foe, region, cycle))

	var stats = GameState.get_player_stats()
	var shield = _shield_gain(stats, stats.shield_start)
	# 开战护盾同样受护盾上限约束（最大生命 × 40%）
	shield = mini(shield, roundi(GameState.max_hp * GameData.COMBAT["shield_cap_pct"]))
	if shield > 0:
		SignalBus.combat_log_message.emit("壁垒：战斗开始获得 %d 护盾" % shield, "system")

	var is_elite = elite
	var is_boss = boss
	for e in enemies:
		if e.is_boss:
			is_boss = true
		elif e.is_elite:
			is_elite = true

	return {
		"enemies": enemies,
		"player_turn": true,
		"skill_cooldown": 0,
		"cooldowns": { "attack": 0, "defend": 0, "potion": 0 },
		"focus": 0,
		"shield": shield,
		"turn": 0,
		"first_attack": true,
		"is_elite": is_elite,
		"is_boss": is_boss,
		"hero_anim": 0,
		"busy": false,
		"bow_combo": 0,          # 弓：暴击叠加的额外连击数（本场战斗有效）
		"crits_this_action": 0,  # 本次行动的暴击计数
	}

## 护盾获取统一入口（盾魂词条/远古套装加成）
static func _shield_gain(stats: Dictionary, base: int) -> int:
	if base <= 0:
		return 0
	return maxi(1, roundi(base * (1.0 + stats.get("shield_gain_pct", 0) / 100.0)))
