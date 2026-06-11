class_name EquipmentFactory
extends RefCounted

# ============================================================
# 装备工厂 - 从 100 件图鉴库生成装备实例
# - 基底(品级/职业小特性) × 五行元素 × 前缀(套装) × 稀有度 × 词条
# - 数值随有效区域(区域 + 周目×5)与品级成长
# - 武器职业差异在战斗中体现：剑无冷却 / 斧高伤有冷却 / 弓双段
# ============================================================

const LoreDataScript = preload("res://scripts/data/lore_data.gd")
const ItemCatalogScript = preload("res://scripts/data/item_catalog.gd")

## 各武器职业的听装攻击系数（战斗中：斧每击×1.55但冷却1回合，弓两段×0.62）
const CLASS_ATK_ADJUST = { "sword": 1.0, "axe": 1.15, "bow": 0.8 }

static func effective_region(region: int) -> int:
	var cycle = GameState.cycle if GameState else 0
	return region + cycle * 5

static func generate_item(region: int, slot: String = "", min_rarity: int = -1, tier: String = "") -> Dictionary:
	# 决定槽位
	if slot == "":
		var roll = randf()
		slot = "weapon" if roll < 0.5 else "armor" if roll < 0.75 else "accessory"

	# 决定稀有度
	var rar: int
	if tier != "" and GameData.RARITY_WEIGHTS.has(tier):
		rar = _roll_rarity_weighted(GameData.RARITY_WEIGHTS[tier])
	else:
		rar = _roll_rarity()
	if min_rarity >= 0:
		rar = max(rar, min_rarity)
	rar = clampi(rar, GameData.Rarity.COMMON, GameData.Rarity.LEGENDARY)

	# 从图鉴库抽取基底+元素
	var eff = effective_region(region)
	var entry = ItemCatalogScript.roll_entry(slot, eff)
	return build_from_entry(entry, eff, rar)

## 按图鉴条目构建实例（商店/掉落/测试通用）
static func build_from_entry(entry: Dictionary, eff: int, rar: int) -> Dictionary:
	var rarity_data = GameData.RARITY_DATA[rar]
	var stat_mult: float = rarity_data.mult * ItemCatalogScript.grade_mult(entry.grade)

	var item = {
		"slot": entry.slot,
		"key": entry.key,
		"catalog_id": entry.id,
		"family": entry.base,
		"grade": entry.grade,
		"element": entry.element,
		"base_name": entry.name,
		"trait": entry.trait,
		"trait_desc": entry.trait_desc,
		"unique_5": _unique_for(entry.key),
		"rarity": rar,
		"level": 0,
		"invested": 0,
		"stats": { "atk": 0, "def": 0, "hp": 0 },
		"affixes": [],
		"value": roundi(rarity_data.base_value * (1.0 + eff * 0.4) * (0.9 + entry.grade * 0.1)),
	}

	_generate_stats(item, entry.slot, eff, stat_mult)
	_generate_affixes(item, rar)
	_generate_name(item)
	item["lore"] = LoreDataScript.compose_item_lore(item)
	return item

static func _unique_for(key: String) -> String:
	if GameData.WEAPON_TEMPLATES.has(key):
		return GameData.WEAPON_TEMPLATES[key].unique_5
	if key == "armor":
		return GameData.ARMOR_TEMPLATES["armor"].unique_5
	return GameData.ACCESSORY_TEMPLATES["amulet"].unique_5

static func create_starter_weapon() -> Dictionary:
	var entry = ItemCatalogScript.get_entry("metal_短剑")
	var item = build_from_entry(entry, 0, GameData.Rarity.COMMON)
	item["affixes"] = []
	item["prefix"] = ""
	item["name"] = "见习骑士的短剑"
	item["stats"] = { "atk": 5, "def": 0, "hp": 0 }
	item["value"] = 18
	item["lore"] = ["从见习时代就陪着你的剑。剑柄被掌心磨得发亮，每一道缺口都是一段记忆。"]
	return item

static func create_starter_armor() -> Dictionary:
	var entry = ItemCatalogScript.get_entry("earth_布甲")
	var item = build_from_entry(entry, 0, GameData.Rarity.COMMON)
	item["affixes"] = []
	item["prefix"] = ""
	item["name"] = "见习骑士的布甲"
	item["stats"] = { "atk": 0, "def": 2, "hp": 10 }
	item["value"] = 18
	item["lore"] = ["骑士团发给每位见习生的第一套护甲。内衬里还缝着出征前家人塞进去的平安符。"]
	return item

static func _roll_rarity() -> int:
	return _roll_rarity_weighted(GameData.RARITY_WEIGHTS["normal"])

static func _roll_rarity_weighted(weights: Array) -> int:
	var total = 0.0
	for w in weights:
		total += w
	var r = randf() * total
	var acc = 0.0
	for i in range(weights.size()):
		acc += weights[i]
		if r <= acc:
			return i
	return weights.size() - 1

# 浮动收窄到 ±5%，保证稀有度之间的属性档位不会互相越级
static func _generate_stats(item: Dictionary, slot: String, eff: int, mult: float) -> void:
	match slot:
		"weapon":
			var adj: float = CLASS_ATK_ADJUST.get(item.key, 1.0)
			item.stats.atk = maxi(1, roundi((5.0 + eff * 3.2) * mult * adj * randf_range(0.95, 1.05)))
		"armor":
			item.stats.def = maxi(1, roundi((2.0 + eff * 1.6) * mult * randf_range(0.95, 1.05)))
			item.stats.hp = roundi((8.0 + eff * 7.0) * mult)
		"accessory":
			item.stats.atk = roundi((1.0 + eff * 1.2) * mult)
			item.stats.def = roundi((1.0 + eff * 0.8) * mult)
			item.stats.hp = roundi((4.0 + eff * 4.0) * mult)

static func _generate_affixes(item: Dictionary, rarity: int) -> void:
	var n = GameData.RARITY_DATA[rarity].max_affixes
	if n <= 0:
		return
	var pool = GameData.AFFIX_KEYS.duplicate()
	pool.shuffle()
	for i in range(min(n, pool.size())):
		item.affixes.append(pool[i])

static func _generate_name(item: Dictionary) -> void:
	var prefix = GameData.EQUIP_PREFIXES[randi() % GameData.EQUIP_PREFIXES.size()]
	item["prefix"] = prefix
	var affix_name = ""
	if item.affixes.size() > 0:
		affix_name = " [%s]" % GameData.AFFIXES[item.affixes[0]].name
	item["name"] = "%s%s%s" % [prefix, item.base_name, affix_name]
