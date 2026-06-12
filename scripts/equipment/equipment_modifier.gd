class_name EquipmentModifier
extends RefCounted

# ============================================================
# 装备修饰器 - 属性结算中心
# 基础 + 装备(含强化) + 基底特性 + 词条 + 套装 + 区域祝福
# 出售价 = 基础价值 + 强化等级补贴 + 已投入强化费用的 50% (+镀金套装加成)
# ============================================================

# +3 解锁的槽位被动说明
const SLOT_PASSIVE_DESC = {
	"weapon": "暴击率 +10%", "armor": "格挡率 +10%", "helmet": "受到伤害 -4%",
	"pants": "每回合恢复 1 生命", "boots": "连击概率 +6%", "accessory": "每回合恢复 2 生命",
}

static func get_upgrade_cost(item: Dictionary, region: int) -> int:
	return roundi((item.level + 1) * 22 * (1 + region * 0.55) / 5.0) * 5

static func get_sell_value(item: Dictionary, sell_pct: float = -1.0) -> int:
	var invested: int = int(item.get("invested", 0))
	if sell_pct < 0:
		sell_pct = 0.0
		if GameState:
			sell_pct = float(GameState.get_player_stats().get("sell_pct", 0))
	var base = item.value * (1.0 + sell_pct / 100.0)
	return roundi(base) + item.level * 12 + roundi(invested * GameData.COMBAT["sell_refund_pct"])

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
		# 新词条 / 流派
		"lifesteal": 0,
		"stun_chance": 0,
		"burn_chance": 0,
		"burn_x2": false,
		"combo_dmg": 0,
		"has_focus": false,
		"execute_bonus": 0,
		"shield_gain_pct": 0,
		"potion_bonus_pct": 0,
		"potion_cd_reduce": 0,
		"thorns_pct": 0,
		"elem_proc": 0,
		"elem_counter_x2": false,
		"first_turn_pct": 0,
		"weaken_chance": 0,
		"sell_pct": 0,
		# 先后手 / 盾击流派 / 闪避
		"bash_fast": false,
		"bash_cd_reduce": 0,
		"shield2atk": false,
		"atk2shield": false,
		"dodge_chance": 0,
		# 连击体系（词条/天赋驱动）
		"multihit": 0,
		"crit_combo": 0,
		# 百分比累积（最后统一应用）
		"atk_pct": 0,
		"def_pct": 0,
		"hp_pct": 0,
		# 五行
		"weapon_element": "",
		"armor_element": "",
	}

	for slot in GameData.EQUIP_SLOTS:
		var it = equipment.get(slot)
		if not it:
			continue

		var upm = get_stat_multiplier(it.level)
		S.atk += roundi(it.stats.atk * upm)
		S.def += roundi(it.stats.def * upm)
		S.hp += roundi(it.stats.hp * upm)

		if slot == "weapon":
			S.weapon_element = str(it.get("element", ""))
		elif slot == "armor":
			S.armor_element = str(it.get("element", ""))

		# 基底特性（短剑轻巧 / 刺剑锋芒 / 板甲钢壁…）
		_apply_fx(S, it.get("trait", {}))

		# +3 被动
		if it.level >= 3:
			match slot:
				"weapon": S.crit += 10
				"armor": S.block_chance += 10
				"helmet": S.dmg_reduction += 4
				"pants": S.regen += 1
				"boots": S.extra_hit += 6
				"accessory": S.regen += 2

		# +5 独特
		if it.level >= 5:
			match it.key:
				"sword": S.kill_shield = 5
				"bow": S.first_double = true
				"axe": S.axe_bonus = 0.35
				"armor": S.full_block_chance = 25
				"helmet": S.shield_start += 8
				"pants": S.regen += 3
				"boots": S.dodge_chance += 15
				"amulet": S.battle_heal += 0.15

		# 词条（数值型词条按锻打强化等级 Lv 倍增；开关型不受等级影响）
		for a in it.affixes:
			var lv = 1
			var lvs = it.get("affix_lv", {})
			if lvs is Dictionary:
				lv = maxi(1, int(lvs.get(a, 1)))
			match a:
				"crit": S.crit += 10 * lv
				"critdmg": S.crit_dmg += 40 * lv
				"multihit": S.multihit += lv
				"critcombo": S.crit_combo += lv
				"swift": S.extra_hit += 15 * lv
				"pierce": S.atk_pct += 12 * lv
				"chain": S.splash += 30 * lv
				"lifesteal": S.lifesteal += 12 * lv
				"stun": S.stun_chance += 12 * lv
				"burn": S.burn_chance += 20 * lv
				"combo": S.combo_dmg += 25 * lv
				"focus": S.has_focus = true
				"execute": S.execute_bonus += 40 * lv
				"block": S.block_chance += 10 * lv
				"bulwark": S.shield_start += 6 * lv
				"regen": S.regen += 2 * lv
				"stone": S.dmg_reduction += 10 * lv
				"shieldm": S.shield_gain_pct += 20 * lv
				"thornsp": S.thorns_pct += 20 * lv
				"greed": S.gold_pct += 25 * lv
				"fortune": S.loot_pct += 15 * lv
				"haggle": S.discount += 15 * lv
				"alchemy":
					S.potion_bonus_pct += 15 * lv
					S.potion_cd_reduce += 1
				"swiftbash": S.bash_fast = true
				"bashcd": S.bash_cd_reduce += lv
				"shield2atk": S.shield2atk = true
				"atk2shield": S.atk2shield = true

	# 套装效果
	var sets = get_active_sets(equipment)
	for s in sets:
		_apply_fx(S, s.fx)

	# 开局天赋点（生命在 _recalc_stats 经 S.hp 计入最大生命）
	var talents: Dictionary = GameState.talents if GameState else {}
	S.hp += int(talents.get("vit", 0)) * 8
	S.atk += int(talents.get("str", 0))
	S.def += int(talents.get("tough", 0))
	S.crit += int(talents.get("agi", 0)) * 2

	# 天赋词条（击败首领获得）
	if GameState:
		for p in GameState.perks:
			_apply_fx(S, GameData.get_perk(p).fx)

	# 百分比统一应用
	S.atk = roundi(S.atk * (1.0 + S.atk_pct / 100.0))
	S.def = roundi(S.def * (1.0 + S.def_pct / 100.0))
	S.hp = roundi(S.hp * (1.0 + S.hp_pct / 100.0))

	# 区域buff
	var region_buff = GameState.region_buff if GameState else 0.0
	if region_buff > 0:
		S.atk = roundi(S.atk * (1.0 + region_buff))

	return S

## 通用效果应用器：套装 fx / 基底 trait 共用
static func _apply_fx(S: Dictionary, fx: Dictionary) -> void:
	for k in fx:
		var v = fx[k]
		match k:
			"atk_pct": S.atk_pct += v
			"def_pct": S.def_pct += v
			"hp_pct": S.hp_pct += v
			"crit": S.crit += v
			"crit_dmg": S.crit_dmg += v
			"extra_hit": S.extra_hit += v
			"combo_dmg": S.combo_dmg += v
			"gold_pct": S.gold_pct += v
			"loot_pct": S.loot_pct += v
			"discount": S.discount += v
			"regen": S.regen += v
			"dmg_reduction": S.dmg_reduction += v
			"block_chance": S.block_chance += v
			"shield_gain_pct": S.shield_gain_pct += v
			"shield_start": S.shield_start += v
			"elem_proc": S.elem_proc += v
			"elem_counter_x2": S.elem_counter_x2 = true
			"first_turn_pct": S.first_turn_pct += v
			"battle_heal": S.battle_heal += v / 100.0
			"burn_chance": S.burn_chance += v
			"burn_x2": S.burn_x2 = true
			"weaken_chance": S.weaken_chance += v
			"sell_pct": S.sell_pct += v
			"lifesteal": S.lifesteal += v
			"dodge_chance": S.dodge_chance += v
			"bash_fast": S.bash_fast = true
			"bash_cd_reduce": S.bash_cd_reduce += v
			"first_double": S.first_double = true
			"crit_combo": S.crit_combo += v
			"multihit": S.multihit += v

# ------------------------------------------------------------
# 套装：身上 2/3 件同前缀装备激活套装效果（六个槽位都计入）
# 返回 [{prefix, set_name, count, fx, descs}]
# ------------------------------------------------------------
static func get_active_sets(equipment: Dictionary) -> Array:
	var counts = {}
	for slot in GameData.EQUIP_SLOTS:
		var it = equipment.get(slot)
		if not it:
			continue
		var p = str(it.get("prefix", ""))
		if p == "":
			continue
		counts[p] = counts.get(p, 0) + 1

	var out = []
	for p in counts:
		var n = counts[p]
		if n < 2 or not GameData.SET_BONUSES.has(p):
			continue
		var sb = GameData.SET_BONUSES[p]
		var fx = sb.two.fx.duplicate()
		var descs = ["2件: %s" % sb.two.desc]
		if n >= 3:
			for k in sb.three.fx:
				var v3 = sb.three.fx[k]
				if fx.has(k) and (v3 is int or v3 is float):
					fx[k] += v3
				else:
					fx[k] = v3
			descs.append("3件: %s" % sb.three.desc)
		out.append({ "prefix": p, "set_name": sb.name, "count": n, "fx": fx, "descs": descs })
	return out

# ------------------------------------------------------------
# 属性分解：基础 / 装备 / 祝福，供属性面板清晰展示
# ------------------------------------------------------------
static func calculate_stat_breakdown(equipment: Dictionary) -> Dictionary:
	var base = {
		"atk": GameData.PLAYER_BASE["atk"],
		"def": GameData.PLAYER_BASE["def"],
		"hp": GameData.PLAYER_BASE["max_hp"],
		"crit": GameData.PLAYER_BASE["crit"],
		"crit_dmg": GameData.PLAYER_BASE["crit_dmg"],
	}
	var equip = { "atk": 0, "def": 0, "hp": 0, "crit": 0, "crit_dmg": 0 }
	var specials = []   # [{source, text}]

	for slot in GameData.EQUIP_SLOTS:
		var it = equipment.get(slot)
		if not it:
			continue
		var src = "%s「%s」" % [GameData.slot_name(slot), it.get("name", it.base_name)]
		var upm = get_stat_multiplier(it.level)
		equip.atk += roundi(it.stats.atk * upm)
		equip.def += roundi(it.stats.def * upm)
		equip.hp += roundi(it.stats.hp * upm)

		var elem = str(it.get("element", ""))
		if elem != "":
			var ed = GameData.ELEMENTS.get(elem, {})
			specials.append({ "source": src, "text": "元素: %s — 克制时伤害×1.3 · %s(%s)" % [GameData.element_name(elem), ed.get("proc_name", ""), ed.get("proc_desc", "")] })
		var td = str(it.get("trait_desc", ""))
		if td != "":
			specials.append({ "source": src, "text": "基底特性: %s" % td })

		if it.level >= 3:
			if slot == "weapon":
				equip.crit += 10
			specials.append({ "source": src, "text": "被动: %s" % SLOT_PASSIVE_DESC.get(slot, "") })
		if it.level >= 5:
			specials.append({ "source": src, "text": "独特: %s" % it.unique_5 })
		for a in it.affixes:
			var ad = GameData.AFFIXES.get(a, {})
			if a == "crit":
				equip.crit += 10
			elif a == "critdmg":
				equip.crit_dmg += 40
			specials.append({ "source": src, "text": "词条: %s — %s" % [ad.get("name", a), ad.get("desc", "")] })

	var sets = get_active_sets(equipment)
	for s in sets:
		specials.append({ "source": "套装「%s·%s」(%d件)" % [s.prefix, s.set_name, s.count], "text": " / ".join(s.descs) })

	# 开局天赋与首领天赋词条
	if GameState:
		var tparts = []
		for tk in GameData.TALENT_KEYS:
			var tv = int(GameState.talents.get(tk, 0))
			if tv > 0:
				tparts.append("%s %d" % [GameData.TALENTS[tk].name, tv])
		if tparts.size() > 0:
			specials.append({ "source": "开局天赋", "text": " · ".join(tparts) })
		for p in GameState.perks:
			var pd = GameData.get_perk(p)
			specials.append({ "source": "天赋词条", "text": "%s — %s" % [pd.name, pd.desc] })

	var buff_pct = (GameState.region_buff if GameState else 0.0) * 100.0
	return {
		"base": base,
		"equip": equip,
		"buff_atk_pct": buff_pct,
		"specials": specials,
		"sets": sets,
		"total": calculate_total_stats(equipment),
	}

static func format_item_stats(item: Dictionary) -> String:
	var upm = get_stat_multiplier(item.level)
	var parts = []
	var elem = str(item.get("element", ""))
	if elem != "":
		parts.append("〔%s〕" % GameData.element_name(elem))
	if item.stats.atk > 0:
		parts.append("攻击 %d" % roundi(item.stats.atk * upm))
	if item.stats.def > 0:
		parts.append("防御 %d" % roundi(item.stats.def * upm))
	if item.stats.hp > 0:
		parts.append("生命 +%d" % roundi(item.stats.hp * upm))
	return " · ".join(parts)

## 强化后的属性增益预览（强化前 → 强化后）
static func format_upgrade_preview(item: Dictionary) -> String:
	if item.level >= GameData.COMBAT["max_upgrade_level"]:
		return ""
	var cur = get_stat_multiplier(item.level)
	var nxt = get_stat_multiplier(item.level + 1)
	var parts = []
	if item.stats.atk > 0:
		parts.append("攻击 %d→%d" % [roundi(item.stats.atk * cur), roundi(item.stats.atk * nxt)])
	if item.stats.def > 0:
		parts.append("防御 %d→%d" % [roundi(item.stats.def * cur), roundi(item.stats.def * nxt)])
	if item.stats.hp > 0:
		parts.append("生命 %d→%d" % [roundi(item.stats.hp * cur), roundi(item.stats.hp * nxt)])
	return " · ".join(parts)

## 武器职业说明（剑/斧/弓差异 + 先后手特性）
static func weapon_class_desc(key: String) -> String:
	match key:
		"axe": return "斧：伤害 ×1.7，命中附破甲（敌防御 -15%/层·叠2层·持续2回合），攻击后冷却 1 回合；盾击后手"
		"bow": return "弓：每回合 2 箭起步，每箭 ×0.4 独立触发特效；连击/贯连词条仅对弓生效（连击上限 5，总攻击数上限 10）；盾击后手"
		"sword": return "剑：标准攻击无冷却，盾击先手且护盾 +50%（剑专属）；护盾在身时普攻 +20%"
	return ""

## 装备说明行（信息结构：核心战斗信息在前，套装效果挪到最后）
## 顺序：职业 → 基底特性 → 元素 → 词条(含强化Lv) → +3被动 → +5独特 → 强化投入 → 套装
static func format_affixes(item: Dictionary) -> Array:
	var lines = []
	var wc = weapon_class_desc(str(item.get("key", "")))
	if wc != "":
		lines.append("◈ %s" % wc)
	var td = str(item.get("trait_desc", ""))
	if td != "":
		lines.append("◈ 基底特性 · %s" % td)
	var elem = str(item.get("element", ""))
	if elem != "":
		var ed = GameData.ELEMENTS.get(elem, {})
		lines.append("〔%s〕克制时伤害×1.3 · 触发「%s」: %s" % [GameData.element_name(elem), ed.get("proc_name", ""), ed.get("proc_desc", "")])

	for a in item.affixes:
		var data = GameData.AFFIXES.get(a, {})
		var lv = 1
		var lvs = item.get("affix_lv", {})
		if lvs is Dictionary:
			lv = maxi(1, int(lvs.get(a, 1)))
		var lv_tag = (" Lv.%d" % lv) if lv > 1 else ""
		lines.append("◆ %s%s · %s" % [data.get("name", a), lv_tag, GameData.affix_desc(str(a), lv)])

	if item.level >= 3:
		lines.append("★ 被动(已解锁): %s" % SLOT_PASSIVE_DESC.get(str(item.slot), ""))
	else:
		lines.append("★ +3 解锁被动: %s" % SLOT_PASSIVE_DESC.get(str(item.slot), ""))

	if item.level >= 5:
		lines.append("✦ 独特(已解锁): %s" % item.unique_5)
	else:
		lines.append("✦ +5 解锁: %s" % item.unique_5)

	var invested: int = int(item.get("invested", 0))
	if invested > 0:
		lines.append("◇ 已投入强化 %d 金 · 出售时返还 50%%（+%d 金）" % [invested, roundi(invested * GameData.COMBAT["sell_refund_pct"])])

	# 区域基准（精铸制度）：史诗+装备可精铸到当前最高区域基准
	if int(item.get("rarity", 0)) >= GameData.Rarity.EPIC and GameState:
		var te: int = int(item.get("tier_eff", 0))
		if te < GameState.best_eff:
			lines.append("◇ 区域基准 %d / 当前最高 %d —— 可在背包消耗 %d 精粹精铸提升基础数值" % [te + 1, GameState.best_eff + 1, int(GameData.COMBAT["refine_cost"])])
		else:
			lines.append("◇ 区域基准 %d（已是当前最高）" % (te + 1))

	# 套装信息放最后（不挡核心信息）
	var pfx = str(item.get("prefix", ""))
	if pfx != "" and GameData.SET_BONUSES.has(pfx):
		var sb = GameData.SET_BONUSES[pfx]
		lines.append("✪ 套装「%s·%s」 2件: %s / 3件: %s" % [pfx, sb.name, sb.two.desc, sb.three.desc])

	return lines
