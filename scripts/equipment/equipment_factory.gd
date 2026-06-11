class_name EquipmentFactory
extends RefCounted

# ============================================================
# 装备工厂 - 生成装备实例
# ============================================================

static func generate_item(region: int, slot: String = "", min_rarity: int = -1) -> Dictionary:
	# 决定槽位
	if slot == "":
		var roll = randf()
		slot = "weapon" if roll < 0.5 else "armor" if roll < 0.75 else "accessory"

	# 决定稀有度
	var rar = _roll_rarity()
	if min_rarity >= 0:
		rar = max(rar, min_rarity)

	# 获取模板
	var template = _get_template(slot)
	var rarity_data = GameData.RARITY_DATA[rar]
	var stat_mult = rarity_data.mult

	var item = {
		"slot": slot,
		"key": template.key,
		"base_name": template.base_name,
		"unique_5": template.unique_5,
		"rarity": rar,
		"level": 0,
		"stats": { "atk": 0, "def": 0, "hp": 0 },
		"affixes": [],
		"value": roundi(rarity_data.base_value * (1.0 + region * 0.4)),
	}

	# 生成属性
	_generate_stats(item, slot, region, stat_mult)

	# 生成词条
	_generate_affixes(item, rar)

	# 生成名称
	_generate_name(item, template)

	return item

static func create_starter_weapon() -> Dictionary:
	return {
		"slot": "weapon",
		"key": "sword",
		"base_name": "长剑",
		"unique_5": "击杀敌人后获得 8 点护盾",
		"rarity": GameData.Rarity.COMMON,
		"level": 0,
		"stats": { "atk": 5, "def": 0, "hp": 0 },
		"affixes": [],
		"value": 18,
		"name": "见习骑士的长剑",
	}

static func create_starter_armor() -> Dictionary:
	return {
		"slot": "armor",
		"key": "armor",
		"base_name": "护甲",
		"unique_5": "25% 概率完全格挡一次攻击",
		"rarity": GameData.Rarity.COMMON,
		"level": 0,
		"stats": { "atk": 0, "def": 2, "hp": 10 },
		"affixes": [],
		"value": 18,
		"name": "见习骑士的护甲",
	}

static func _roll_rarity() -> int:
	var r = randf()
	if r < 0.50: return GameData.Rarity.COMMON
	elif r < 0.80: return GameData.Rarity.RARE
	elif r < 0.95: return GameData.Rarity.EPIC
	else: return GameData.Rarity.LEGENDARY

static func _get_template(slot: String):
	var templates
	match slot:
		"weapon": templates = GameData.WEAPON_TEMPLATES
		"armor": templates = GameData.ARMOR_TEMPLATES
		_: templates = GameData.ACCESSORY_TEMPLATES

	var keys = templates.keys()
	var key = keys[randi() % keys.size()]
	var t = templates[key]
	return {
		"key": key,
		"base_name": t.base_name,
		"unique_5": t.unique_5,
		"slot": t.slot,
	}

static func _generate_stats(item: Dictionary, slot: String, region: int, mult: float) -> void:
	match slot:
		"weapon":
			item.stats.atk = roundi((5.0 + region * 3.2) * mult * randf_range(0.9, 1.1))
		"armor":
			item.stats.def = roundi((2.0 + region * 1.6) * mult * randf_range(0.9, 1.1))
			item.stats.hp = roundi((8.0 + region * 7.0) * mult)
		"accessory":
			item.stats.atk = roundi((1.0 + region * 1.2) * mult)
			item.stats.def = roundi((1.0 + region * 0.8) * mult)
			item.stats.hp = roundi((4.0 + region * 4.0) * mult)

static func _generate_affixes(item: Dictionary, rarity: int) -> void:
	var n = GameData.RARITY_DATA[rarity].max_affixes
	if n <= 0:
		return
	var pool = GameData.AFFIX_KEYS.duplicate()
	pool.shuffle()
	for i in range(min(n, pool.size())):
		item.affixes.append(pool[i])

static func _generate_name(item: Dictionary, template) -> void:
	var prefix = GameData.EQUIP_PREFIXES[randi() % GameData.EQUIP_PREFIXES.size()]
	var affix_name = ""
	if item.affixes.size() > 0:
		affix_name = " [%s]" % GameData.AFFIXES[item.affixes[0]].name
	item.name = "%s%s%s" % [prefix, template.base_name, affix_name]
