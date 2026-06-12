class_name ItemCatalog
extends RefCounted

# ============================================================
# 装备图鉴库：35 个基底 × 5 种元素 = 175 件命名装备
# - 基底决定槽位/武器职业/品级/小特性（短剑轻巧、刺剑暴击、巨斧蛮力…）
# - 元素决定名称词缀、配色与元素克制/触发效果
# - 品级随有效区域（区域 + 周目×5）解锁，数值随品级提升
# - 槽位：武器 / 铠甲 / 头盔 / 裤子 / 鞋 / 配饰
# ============================================================

# ---- 基底定义 ----
# key: 武器职业(sword/axe/bow) 或 armor/helmet/pants/boots/amulet
# grade: 品级 1-5；trait: 基底自带的小特性（叠加在词条之上）
const BASES = [
	# 武器 · 剑（无冷却，均衡）
	{ "base": "短剑",   "slot": "weapon",    "key": "sword", "grade": 1, "kind": "武器·剑",
	  "trait": { "extra_hit": 8 }, "trait_desc": "轻巧：连击概率 +8%",
	  "lore": "佣兵的入门兵刃，刃短而轻，出手比眨眼还快。" },
	{ "base": "长剑",   "slot": "weapon",    "key": "sword", "grade": 2, "kind": "武器·剑",
	  "trait": {}, "trait_desc": "",
	  "lore": "边境骑士团的制式佩剑，攻守均衡，从不挑剔主人。" },
	{ "base": "刺剑",   "slot": "weapon",    "key": "sword", "grade": 3, "kind": "武器·剑",
	  "trait": { "crit": 10 }, "trait_desc": "锋芒：暴击率 +10%",
	  "lore": "决斗家的尖刃，专挑甲缝与要害，一击致命是它的美学。" },
	{ "base": "巨剑",   "slot": "weapon",    "key": "sword", "grade": 5, "kind": "武器·剑",
	  "trait": { "atk_pct": 15 }, "trait_desc": "沉重：攻击 +15%",
	  "lore": "需要双手才能挥动的巨刃，传说它的上一任主人单手用它。" },
	# 武器 · 斧（伤害 ×1.55，攻击后冷却 1 回合 → 一击流）
	{ "base": "手斧",   "slot": "weapon",    "key": "axe",   "grade": 1, "kind": "武器·斧",
	  "trait": {}, "trait_desc": "",
	  "lore": "伐木人的随身工具，劈柴劈得开，劈人也一样。" },
	{ "base": "战斧",   "slot": "weapon",    "key": "axe",   "grade": 3, "kind": "武器·斧",
	  "trait": { "atk_pct": 8 }, "trait_desc": "凶悍：攻击 +8%",
	  "lore": "矮人行会的量产战斧，斧刃后錾着山形印记。" },
	{ "base": "巨斧",   "slot": "weapon",    "key": "axe",   "grade": 5, "kind": "武器·斧",
	  "trait": { "atk_pct": 18 }, "trait_desc": "蛮力：攻击 +18%",
	  "lore": "双刃如月，挥落如山崩。盾墙在它面前只是稍微结实的木板。" },
	# 武器 · 弓（每击 ×0.62 但攻击两段，每段都触发命中特效 → 连击/吸血流）
	{ "base": "猎弓",   "slot": "weapon",    "key": "bow",   "grade": 1, "kind": "武器·弓",
	  "trait": {}, "trait_desc": "",
	  "lore": "猎户人手一把的短弓，养活了山脚下整个村子。" },
	{ "base": "长弓",   "slot": "weapon",    "key": "bow",   "grade": 3, "kind": "武器·弓",
	  "trait": { "crit": 6 }, "trait_desc": "精准：暴击率 +6%",
	  "lore": "取百年紫杉向阳面制成，拉满时会发出近似鸟鸣的轻响。" },
	{ "base": "劲弩",   "slot": "weapon",    "key": "bow",   "grade": 5, "kind": "武器·弓",
	  "trait": { "atk_pct": 12 }, "trait_desc": "强劲：攻击 +12%",
	  "lore": "军械署的攻城利器缩小版，弩匠说它能把城门钉在墙上。" },
	# 防具
	{ "base": "布甲",   "slot": "armor",     "key": "armor", "grade": 1, "kind": "防具",
	  "trait": {}, "trait_desc": "",
	  "lore": "多层亚麻压制的轻甲，挡不住刀剑，挡得住风寒与擦伤。" },
	{ "base": "皮甲",   "slot": "armor",     "key": "armor", "grade": 2, "kind": "防具",
	  "trait": {}, "trait_desc": "",
	  "lore": "鞣制兽皮裁成，贴身轻便，是游侠们的第二层皮肤。" },
	{ "base": "锁子甲", "slot": "armor",     "key": "armor", "grade": 3, "kind": "防具",
	  "trait": { "block_chance": 5 }, "trait_desc": "环锁：格挡率 +5%",
	  "lore": "上万枚铁环手工编织，刀锋滑过时会发出潮水般的声响。" },
	{ "base": "板甲",   "slot": "armor",     "key": "armor", "grade": 4, "kind": "防具",
	  "trait": { "dmg_reduction": 5 }, "trait_desc": "钢壁：受到伤害 -5%",
	  "lore": "整块钢板锻压成型，穿上它就像把一座堡垒穿在身上。" },
	{ "base": "龙鳞甲", "slot": "armor",     "key": "armor", "grade": 5, "kind": "防具",
	  "trait": { "dmg_reduction": 8 }, "trait_desc": "龙鳞：受到伤害 -8%",
	  "lore": "鳞片层叠如龙背，没人说得清材料来自锻造还是真正的龙。" },
	# 头盔
	{ "base": "皮帽",     "slot": "helmet",    "key": "helmet", "grade": 1, "kind": "护具·头盔",
	  "trait": {}, "trait_desc": "",
	  "lore": "鞣皮缝制的软帽，挡不住重锤，但挡得住树枝、碎石和坏天气。" },
	{ "base": "铁盔",     "slot": "helmet",    "key": "helmet", "grade": 2, "kind": "护具·头盔",
	  "trait": {}, "trait_desc": "",
	  "lore": "民兵营的制式半盔，内衬麻布，戴久了会留下一圈压痕。" },
	{ "base": "战盔",     "slot": "helmet",    "key": "helmet", "grade": 3, "kind": "护具·头盔",
	  "trait": { "dmg_reduction": 3 }, "trait_desc": "护面：受到伤害 -3%",
	  "lore": "带护颊的战场头盔，盔顶的凹痕证明它救过前主人一命。" },
	{ "base": "骑士盔",   "slot": "helmet",    "key": "helmet", "grade": 4, "kind": "护具·头盔",
	  "trait": { "block_chance": 6 }, "trait_desc": "面甲：格挡率 +6%",
	  "lore": "全覆面的骑士头盔，放下面甲的瞬间，世界只剩下敌人。" },
	{ "base": "龙首盔",   "slot": "helmet",    "key": "helmet", "grade": 5, "kind": "护具·头盔",
	  "trait": { "dmg_reduction": 5, "crit": 4 }, "trait_desc": "龙威：受到伤害 -5%，暴击率 +4%",
	  "lore": "铸成龙首形状的传说头盔，据说戴上它时能听见远古巨龙的低吼。" },
	# 裤子
	{ "base": "布裤",     "slot": "pants",     "key": "pants",  "grade": 1, "kind": "护具·裤子",
	  "trait": {}, "trait_desc": "",
	  "lore": "粗麻布裤，膝盖处打着补丁——每个冒险者都是从这条裤子开始的。" },
	{ "base": "皮裤",     "slot": "pants",     "key": "pants",  "grade": 2, "kind": "护具·裤子",
	  "trait": {}, "trait_desc": "",
	  "lore": "猎户的耐磨皮裤，荆棘丛里穿行一天也不会刮破。" },
	{ "base": "链甲裤",   "slot": "pants",     "key": "pants",  "grade": 3, "kind": "护具·裤子",
	  "trait": { "hp_pct": 4 }, "trait_desc": "护腿：最大生命 +4%",
	  "lore": "铁环编织的腿甲，走起路来沙沙作响，像一场小雨。" },
	{ "base": "板甲腿铠", "slot": "pants",     "key": "pants",  "grade": 4, "kind": "护具·裤子",
	  "trait": { "def_pct": 8 }, "trait_desc": "钢膝：防御 +8%",
	  "lore": "整片钢板冲压的腿铠，跪地祈祷时会在石板上磕出火星。" },
	{ "base": "龙鳞腿甲", "slot": "pants",     "key": "pants",  "grade": 5, "kind": "护具·裤子",
	  "trait": { "hp_pct": 6, "def_pct": 6 }, "trait_desc": "龙鳞：最大生命 +6%，防御 +6%",
	  "lore": "鳞片自踝至腰层层相叠，行走时泛起一道流动的微光。" },
	# 鞋
	{ "base": "草编鞋",   "slot": "boots",     "key": "boots",  "grade": 1, "kind": "护具·鞋",
	  "trait": {}, "trait_desc": "",
	  "lore": "村口老人编的草鞋，轻得像没穿——也确实跟没穿差不多。" },
	{ "base": "皮靴",     "slot": "boots",     "key": "boots",  "grade": 2, "kind": "护具·鞋",
	  "trait": {}, "trait_desc": "",
	  "lore": "高帮牛皮靴，鞋底钉着防滑的铜钉，雨天山路也走得稳。" },
	{ "base": "铁头靴",   "slot": "boots",     "key": "boots",  "grade": 3, "kind": "护具·鞋",
	  "trait": { "extra_hit": 6 }, "trait_desc": "踏步：连击概率 +6%",
	  "lore": "靴尖包着铁皮的军靴，踹门、踹箱子、踹敌人都很顺脚。" },
	{ "base": "疾风靴",   "slot": "boots",     "key": "boots",  "grade": 4, "kind": "护具·鞋",
	  "trait": { "extra_hit": 10 }, "trait_desc": "疾风：连击概率 +10%",
	  "lore": "鞋帮绣着风之纹章，穿上后脚步轻快得连影子都要追不上。" },
	{ "base": "龙行靴",   "slot": "boots",     "key": "boots",  "grade": 5, "kind": "护具·鞋",
	  "trait": { "extra_hit": 8, "dodge_chance": 5 }, "trait_desc": "龙行：连击 +8%，闪避 +5%",
	  "lore": "传说穿上它的人步伐如龙，敌人的攻击只能落在残影上。" },
	# 饰品
	{ "base": "木刻护符", "slot": "accessory", "key": "amulet", "grade": 1, "kind": "饰品",
	  "trait": { "regen": 1 }, "trait_desc": "祈愿：每回合恢复 1 生命",
	  "lore": "村中长者亲手雕刻的护符，木纹里浸着一句最朴素的祝福。" },
	{ "base": "铜纹戒指", "slot": "accessory", "key": "amulet", "grade": 2, "kind": "饰品",
	  "trait": { "gold_pct": 10 }, "trait_desc": "铜运：战斗金币 +10%",
	  "lore": "商队护卫间流传的幸运戒指，据说戴上它讨价还价都顺利些。" },
	{ "base": "银辉徽章", "slot": "accessory", "key": "amulet", "grade": 3, "kind": "饰品",
	  "trait": { "crit": 5 }, "trait_desc": "银辉：暴击率 +5%",
	  "lore": "授予立功斥候的徽章，磨亮的银面映得出持有者的胆识。" },
	{ "base": "秘语契珠", "slot": "accessory", "key": "amulet", "grade": 4, "kind": "饰品",
	  "trait": { "elem_proc": 10 }, "trait_desc": "秘语：元素触发率 +10%",
	  "lore": "珠内封着一句听不懂的古语，靠近耳边能听见它在轻声重复。" },
	{ "base": "圣辉遗物", "slot": "accessory", "key": "amulet", "grade": 5, "kind": "饰品",
	  "trait": { "hp_pct": 10 }, "trait_desc": "圣辉：最大生命 +10%",
	  "lore": "圣堂地宫出土的遗物，触碰它的人都说感到了一瞬间的安宁。" },
]

# ---- 元素风味文案 ----
const ELEMENT_FLAVOR = {
	"metal": "雷光在表面游走噼啪作响——出手时挟着雷霆之势，护盾在它面前形同虚设。",
	"wood":  "森林的生命力在其中流淌不息——伤敌之时，亦能反哺持有者。",
	"water": "寒冰之纹在表面凝结流转——被它触及的敌人会像冻僵般使不上力。",
	"fire":  "焰火之心在内部燃烧不熄——命中之处会留下久久不灭的火种。",
	"earth": "大地之髓灌注其中，厚重沉稳——大地会回应它的主人，凝土成盾。",
}

# 缓存
static var _entries: Array = []
static var _by_id: Dictionary = {}

# ============================================================
# 生成与查询
# ============================================================
static func all_entries() -> Array:
	if _entries.is_empty():
		_build()
	return _entries

static func get_entry(id: String) -> Dictionary:
	if _entries.is_empty():
		_build()
	return _by_id.get(id, _by_id.get("metal_长剑", _entries[0]))

static func _build() -> void:
	_entries.clear()
	_by_id.clear()
	for b in BASES:
		for ek in GameData.ELEMENT_KEYS:
			var word: String = GameData.ELEMENTS[ek]["item_word"]
			var entry = {
				"id": "%s_%s" % [ek, b.base],
				"slot": b.slot,
				"key": b.key,
				"base": b.base,
				"grade": b.grade,
				"kind": b.kind,
				"element": ek,
				"name": "%s%s" % [word, b.base],
				"trait": b.trait,
				"trait_desc": b.trait_desc,
				"lore": [ELEMENT_FLAVOR[ek], b.lore],
			}
			_entries.append(entry)
			_by_id[entry.id] = entry

## 按槽位与有效区域随机抽取一个基底+元素（品级越高权重越大，但不超过解锁上限）
static func roll_entry(slot: String, eff_region: int) -> Dictionary:
	if _entries.is_empty():
		_build()
	var max_grade = clampi(eff_region + 1, 1, 5)
	var pool = []
	for b in BASES:
		if b.slot == slot and b.grade <= max_grade:
			pool.append(b)
	if pool.is_empty():
		for b in BASES:
			if b.slot == slot and b.grade == 1:
				pool.append(b)
	# 品级加权：高品级更常见于高区域
	var total = 0.0
	for b in pool:
		total += float(b.grade)
	var r = randf() * total
	var acc = 0.0
	var chosen = pool[0]
	for b in pool:
		acc += float(b.grade)
		if r <= acc:
			chosen = b
			break
	var ek = GameData.ELEMENT_KEYS[randi() % GameData.ELEMENT_KEYS.size()]
	return get_entry("%s_%s" % [ek, chosen.base])

## 品级数值系数
static func grade_mult(grade: int) -> float:
	return 1.0 + 0.10 * (grade - 1)

## 旧存档物品缺少图鉴信息时的默认基底
static func default_entry_for_key(key: String) -> Dictionary:
	if _entries.is_empty():
		_build()
	var base_by_key = {
		"sword": "长剑", "axe": "战斧", "bow": "长弓", "armor": "锁子甲",
		"helmet": "战盔", "pants": "链甲裤", "boots": "铁头靴", "amulet": "银辉徽章",
	}
	var b = base_by_key.get(key, "长剑")
	var ek = GameData.ELEMENT_KEYS[randi() % GameData.ELEMENT_KEYS.size()]
	return get_entry("%s_%s" % [ek, b])
