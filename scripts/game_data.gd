extends Node

# ============================================================
# 游戏数据定义
# 所有平衡数据、敌人配置、装备模板、词条定义、事件池
# ============================================================

# ---- 稀有度定义 ----
# 属性强度/词条数量/价值 严格按 传奇 > 史诗 > 稀有 > 普通 递增
# max_affixes: 出厂自带词条数；affix_cap: 锻打后词条上限（稀有2/史诗3/传说4）
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_DATA = {
	Rarity.COMMON:    { "name": "普通", "color": Color("#b8bcc8"), "mult": 1.00, "max_affixes": 0, "affix_cap": 1, "base_value": 18 },
	Rarity.RARE:      { "name": "稀有", "color": Color("#5aa7ff"), "mult": 1.30, "max_affixes": 1, "affix_cap": 2, "base_value": 45 },
	Rarity.EPIC:      { "name": "史诗", "color": Color("#bd6fff"), "mult": 1.65, "max_affixes": 2, "affix_cap": 3, "base_value": 95 },
	Rarity.LEGENDARY: { "name": "传说", "color": Color("#f4c454"), "mult": 2.05, "max_affixes": 3, "affix_cap": 4, "base_value": 190 },
}

static func affix_cap(rarity: int) -> int:
	return int(RARITY_DATA.get(rarity, RARITY_DATA[Rarity.COMMON]).get("affix_cap", 1))

# ---- 武器模板 ----
const WEAPON_TEMPLATES = {
	"sword": { "base_name": "长剑", "unique_5": "击杀敌人后获得 5 点护盾", "slot": "weapon" },
	"bow":   { "base_name": "长弓", "unique_5": "每场战斗首次攻击造成双倍伤害", "slot": "weapon" },
	"axe":   { "base_name": "战斧", "unique_5": "对生命值高于 70% 的敌人伤害 +35%", "slot": "weapon" },
}

# ---- 防具模板 ----
const ARMOR_TEMPLATES = {
	"armor": { "base_name": "护甲", "unique_5": "25% 概率完全格挡一次攻击", "slot": "armor" },
}

# ---- 饰品模板 ----
const ACCESSORY_TEMPLATES = {
	"amulet": { "base_name": "护符", "unique_5": "每场战斗开始时恢复 15% 生命值", "slot": "accessory" },
}

# ---- 新增护具模板：头盔 / 裤子 / 鞋 ----
const HELMET_TEMPLATES = {
	"helmet": { "base_name": "头盔", "unique_5": "战斗开始时获得 8 点护盾", "slot": "helmet" },
}
const PANTS_TEMPLATES = {
	"pants": { "base_name": "裤子", "unique_5": "每回合恢复 3 生命", "slot": "pants" },
}
const BOOTS_TEMPLATES = {
	"boots": { "base_name": "鞋", "unique_5": "15% 概率完全闪避攻击", "slot": "boots" },
}

# ---- 装备槽位 ----
const EQUIP_SLOTS = ["weapon", "armor", "helmet", "pants", "boots", "accessory"]
const SLOT_NAMES = {
	"weapon": "武器", "armor": "铠甲", "helmet": "头盔",
	"pants": "裤子", "boots": "鞋", "accessory": "配饰",
}

# ---- 词条定义 ----
# kind: off 进攻 / def 防御 / exp 探索
# 可组流派：吸血流(吸血+弓双段+迅捷)、连击流(弓+迅捷+连环+震慑)、
# 一击流(斧+蓄势+处决+残忍)、反伤坦克(棘甲+荆棘套装+石肤)
const AFFIXES = {
	"crit":      { "name": "精准",  "desc": "暴击率 +10%",                                  "kind": "off" },
	"critdmg":   { "name": "残忍",  "desc": "暴击伤害 +40%",                                "kind": "off" },
	"multihit":  { "name": "连击",  "desc": "连击数 +1（仅弓生效：多射一箭；连击数上限 5）", "kind": "off" },
	"critcombo": { "name": "贯连",  "desc": "暴击后本场战斗连击数 +1（仅弓生效，上限 +2）",  "kind": "off" },
	"swift":     { "name": "迅捷",  "desc": "15% 概率追加连击",                             "kind": "off" },
	"pierce":    { "name": "穿透",  "desc": "攻击力 +12%",                                  "kind": "off" },
	"chain":     { "name": "连锁",  "desc": "攻击对其它敌人溅射 30%",                       "kind": "off" },
	"lifesteal": { "name": "吸血",  "desc": "每次命中回复造成伤害 12% 的生命",              "kind": "off" },
	"stun":      { "name": "震慑",  "desc": "每次命中 12% 概率眩晕敌人 1 回合",             "kind": "off" },
	"burn":      { "name": "燃焰",  "desc": "每次命中 20% 概率点燃敌人（灼烧 2 回合）",     "kind": "off" },
	"combo":     { "name": "连环",  "desc": "连击与多段攻击伤害 +25%",                      "kind": "off" },
	"focus":     { "name": "蓄势",  "desc": "防御时获得 1 层蓄势，下次攻击每层 +30%（最多 3 层）", "kind": "off" },
	"execute":   { "name": "处决",  "desc": "对生命低于 30% 的敌人伤害 +40%",               "kind": "off" },
	"block":     { "name": "守护",  "desc": "+10% 概率减半伤害",                            "kind": "def" },
	"bulwark":   { "name": "壁垒",  "desc": "战斗开始时获得 6 护盾",                        "kind": "def" },
	"regen":     { "name": "再生",  "desc": "每回合恢复 2 生命",                            "kind": "def" },
	"stone":     { "name": "石肤",  "desc": "受到的伤害减少 10%",                           "kind": "def" },
	"shieldm":   { "name": "盾魂",  "desc": "所有护盾获取 +20%",                            "kind": "def" },
	"thornsp":   { "name": "棘甲",  "desc": "受到攻击时反弹 20% 伤害",                      "kind": "def" },
	"greed":     { "name": "贪婪",  "desc": "战斗金币收益 +25%",                            "kind": "exp" },
	"fortune":   { "name": "幸运",  "desc": "装备掉落率 +15%",                              "kind": "exp" },
	"haggle":    { "name": "议价",  "desc": "商店折扣 15%",                                 "kind": "exp" },
	"alchemy":   { "name": "药理",  "desc": "药水恢复 +15%，战斗中药水冷却 -1",             "kind": "exp" },
	# 先后手机制相关词条（盾击默认后手，普攻先手）
	"swiftbash": { "name": "疾盾",  "desc": "盾击不再后手发动",                             "kind": "def" },
	"bashcd":    { "name": "盾势",  "desc": "盾击冷却 -1",                                  "kind": "def" },
	"shield2atk":{ "name": "盾转攻","desc": "盾击护盾减半，盾击伤害 +60%",                  "kind": "off" },
	"atk2shield":{ "name": "攻转盾","desc": "攻击伤害 -15%，每次攻击后获得伤害 15% 的护盾", "kind": "def" },
}

const AFFIX_KEYS = [
	"crit", "critdmg", "multihit", "critcombo", "swift", "pierce", "chain", "lifesteal", "stun", "burn",
	"combo", "focus", "execute", "block", "bulwark", "regen", "stone", "shieldm",
	"thornsp", "greed", "fortune", "haggle", "alchemy",
	"swiftbash", "bashcd", "shield2atk", "atk2shield",
]

# 锻打不可强化的开关型词条（数值型词条可锻打同词条升级，上限 Lv.3）
const NON_STACK_AFFIXES = ["focus", "swiftbash", "shield2atk", "atk2shield"]
const AFFIX_MAX_LEVEL = 3

# 连击体系词条：只能出现在弓或配饰上，且效果仅在使用弓时生效
const COMBO_AFFIXES = ["multihit", "critcombo"]

## 词条说明（带强化等级）：连击等数值词条显示按等级换算后的效果
static func affix_desc(key: String, lv: int = 1) -> String:
	var base = str(AFFIXES.get(key, {}).get("desc", ""))
	if lv <= 1:
		return base
	if key == "multihit":
		return "连击数 +%d（仅弓生效：多射 %d 箭；连击数上限 5）" % [lv, lv]
	if key == "critcombo":
		return "暴击后本场战斗连击数 +%d（仅弓生效，上限 +2）" % lv
	if key == "bashcd":
		return "盾击冷却 -%d" % lv
	return "%s（已强化 Lv.%d，数值 ×%d）" % [base, lv, lv]

# ============================================================
# 开局天赋点（新存档创建时分配，固定 10 点）
# ============================================================
const TALENTS = {
	"vit":   { "name": "生命", "desc": "每点 +8 最大生命" },
	"str":   { "name": "力量", "desc": "每点 +1 攻击" },
	"tough": { "name": "坚韧", "desc": "每点 +1 防御" },
	"agi":   { "name": "敏捷", "desc": "每点 +2% 暴击率" },
}
const TALENT_KEYS = ["vit", "str", "tough", "agi"]
const TALENT_POINTS = 10

# ============================================================
# 天赋词条（通关区域 2 与区域 5 后各三选一，周目循环同样）
# 上限 5 条；超出需选择替换。永久生效、可与装备词条叠加
# fx 键由 EquipmentModifier._apply_fx 解释
# ============================================================
const PERK_CAP = 5
const PERK_MILESTONE_REGIONS = [1, 4]   # 区域索引：通关区域 2 / 区域 5 后可选
const PERKS = {
	"berserker":  { "name": "狂战意志", "desc": "攻击 +10%",                        "fx": { "atk_pct": 10 } },
	"giant":      { "name": "巨人血脉", "desc": "最大生命 +15%",                    "fx": { "hp_pct": 15 } },
	"ironwall":   { "name": "钢铁之躯", "desc": "受到的伤害 -8%",                   "fx": { "dmg_reduction": 8 } },
	"sharpeye":   { "name": "鹰眼",     "desc": "暴击率 +8%",                       "fx": { "crit": 8 } },
	"brutal":     { "name": "残暴",     "desc": "暴击伤害 +30%",                    "fx": { "crit_dmg": 30 } },
	"windrunner": { "name": "疾风步",   "desc": "连击概率 +12%",                    "fx": { "extra_hit": 12 } },
	"elementalist":{ "name": "元素亲和","desc": "元素触发率 +12%",                  "fx": { "elem_proc": 12 } },
	"guardsoul":  { "name": "守护之魂", "desc": "护盾获取 +15%",                    "fx": { "shield_gain_pct": 15 } },
	"archmaster": { "name": "连击之道", "desc": "暴击后本场战斗连击数 +1（仅弓生效，上限 +2）", "fx": { "crit_combo": 1 } },
	"firstblood": { "name": "先发制人", "desc": "每场战斗第一回合伤害 +25%",        "fx": { "first_turn_pct": 25 } },
	"treasurer":  { "name": "寻宝直觉", "desc": "装备掉落率 +15%，战斗金币 +15%",   "fx": { "loot_pct": 15, "gold_pct": 15 } },
	"bashmaster": { "name": "盾击大师", "desc": "盾击冷却 -1 且盾击不再后手",       "fx": { "bash_cd_reduce": 1, "bash_fast": 1 } },
	"bloodpact":  { "name": "血之契约", "desc": "每次命中回复造成伤害 8% 的生命",   "fx": { "lifesteal": 8 } },
}
const PERK_KEYS = ["berserker", "giant", "ironwall", "sharpeye", "brutal", "windrunner",
	"elementalist", "guardsoul", "firstblood", "treasurer", "bashmaster", "bloodpact", "archmaster"]

# ---- 装备前缀 ----
const EQUIP_PREFIXES = ["破旧的", "坚固的", "锋利的", "淬火的", "符文的", "皇家", "远古的", "晨曦", "风暴", "灰烬", "霜冻", "镀金"]

# ---- 套装效果：身上 2/3 件装备同前缀即激活 ----
# fx 键由 EquipmentModifier._apply_set_fx 解释
const SET_BONUSES = {
	"破旧的": { "name": "拾荒者",  "two": { "desc": "战斗金币收益 +20%", "fx": { "gold_pct": 20 } },
				"three": { "desc": "装备掉落率 +15%", "fx": { "loot_pct": 15 } } },
	"坚固的": { "name": "磐石",    "two": { "desc": "防御 +20%", "fx": { "def_pct": 20 } },
				"three": { "desc": "受到的伤害 -10%", "fx": { "dmg_reduction": 10 } } },
	"锋利的": { "name": "利刃",    "two": { "desc": "攻击 +10%", "fx": { "atk_pct": 10 } },
				"three": { "desc": "暴击率 +10%", "fx": { "crit": 10 } } },
	"淬火的": { "name": "淬炼",    "two": { "desc": "最大生命 +15%", "fx": { "hp_pct": 15 } },
				"three": { "desc": "每回合恢复 4 生命", "fx": { "regen": 4 } } },
	"符文的": { "name": "符印",    "two": { "desc": "元素效果触发率 +15%", "fx": { "elem_proc": 15 } },
				"three": { "desc": "元素克制伤害加成翻倍", "fx": { "elem_counter_x2": 1 } } },
	"皇家":   { "name": "王廷",    "two": { "desc": "攻击与防御 +8%", "fx": { "atk_pct": 8, "def_pct": 8 } },
				"three": { "desc": "战斗金币收益 +50%", "fx": { "gold_pct": 50 } } },
	"远古的": { "name": "遗世",    "two": { "desc": "护盾获取 +15%", "fx": { "shield_gain_pct": 15 } },
				"three": { "desc": "战斗开始时获得 10 护盾", "fx": { "shield_start": 10 } } },
	"晨曦":   { "name": "黎明",    "two": { "desc": "每场战斗第一回合伤害 +30%", "fx": { "first_turn_pct": 30 } },
				"three": { "desc": "战斗开始时恢复 15% 生命", "fx": { "battle_heal": 15 } } },
	"风暴":   { "name": "雷霆",    "two": { "desc": "连击概率 +15%", "fx": { "extra_hit": 15 } },
				"three": { "desc": "连击与多段伤害 +40%", "fx": { "combo_dmg": 40 } } },
	"灰烬":   { "name": "余烬",    "two": { "desc": "点燃概率 +20%", "fx": { "burn_chance": 20 } },
				"three": { "desc": "灼烧伤害翻倍", "fx": { "burn_x2": 1 } } },
	"霜冻":   { "name": "寒霜",    "two": { "desc": "命中 20% 概率削弱敌人攻击", "fx": { "weaken_chance": 20 } },
				"three": { "desc": "受到的伤害 -12%", "fx": { "dmg_reduction": 12 } } },
	"镀金":   { "name": "鎏金",    "two": { "desc": "商店折扣 +15%", "fx": { "discount": 15 } },
				"three": { "desc": "出售价格 +30%", "fx": { "sell_pct": 30 } } },
}

# ============================================================
# 元素体系（西式）：闪电克森林 · 森林克大地 · 大地克寒冰 · 寒冰克焰火 · 焰火克闪电
# 武器元素对敌克制伤害 ×1.3，被克 ×0.8；护甲元素同理影响受击
# 每种元素附带独特的触发效果（默认 22% 概率，每次命中判定）
# 内部 key 保持不变以兼容旧存档，仅展示名称/词缀/触发名变更
# ============================================================
const ELEMENTS = {
	"metal": { "name": "闪电", "color": Color("#e8c95a"), "beats": "wood",
		"item_word": "雷光", "proc_name": "雷击", "proc_desc": "本次伤害无视护盾且 +15%" },
	"wood":  { "name": "森林", "color": Color("#6fce62"), "beats": "earth",
		"item_word": "翠叶", "proc_name": "回春", "proc_desc": "回复造成伤害 30% 的生命" },
	"water": { "name": "寒冰", "color": Color("#5aa7e8"), "beats": "fire",
		"item_word": "霜寒", "proc_name": "冰缚", "proc_desc": "敌人攻击 -30%，持续 2 回合" },
	"fire":  { "name": "焰火", "color": Color("#ff7a3a"), "beats": "metal",
		"item_word": "烈焰", "proc_name": "引燃", "proc_desc": "点燃敌人，灼烧 2 回合" },
	"earth": { "name": "大地", "color": Color("#c49a6a"), "beats": "water",
		"item_word": "岩铸", "proc_name": "岩盾", "proc_desc": "获得 6 + 防御 点护盾" },
}

const ELEMENT_KEYS = ["metal", "wood", "water", "fire", "earth"]

# ============================================================
# 怪物词条：基础怪物自带 innate 能力，再随机组合数个词条
# 区域/精英/首领/周目越高词条越多 → 大量变种怪物
# ============================================================
const MONSTER_AFFIXES = {
	"armored":  { "name": "坚甲", "desc": "受到的伤害 -25%",                 "color": Color("#9aa4bc") },
	"piercing": { "name": "穿甲", "desc": "攻击无视你的护盾",               "color": Color("#ff9b8a") },
	"vampiric": { "name": "嗜血", "desc": "吸取造成伤害的 40% 回复自身",     "color": Color("#d46a9c") },
	"swift":    { "name": "迅捷", "desc": "每回合行动两次（第二击 60%）",    "color": Color("#8aeb9a") },
	"thorns":   { "name": "荆棘", "desc": "反弹所受伤害的 20%",             "color": Color("#c49a6a") },
	"regen":    { "name": "再生", "desc": "每回合恢复 6% 最大生命",          "color": Color("#6fce62") },
	"berserk":  { "name": "狂暴", "desc": "生命低于一半后攻击 +40%",         "color": Color("#ff5a3a") },
	"tough":    { "name": "魁梧", "desc": "生命 +50%",                       "color": Color("#5aa7e8") },
	"mighty":   { "name": "巨力", "desc": "攻击 +30%",                       "color": Color("#f4c454") },
	"ethereal": { "name": "虚体", "desc": "25% 概率闪避攻击",                "color": Color("#b59cf4") },
	"shielded": { "name": "结界", "desc": "战斗开始时获得 25% 生命护盾",     "color": Color("#5ab4e8") },
}

const MONSTER_AFFIX_KEYS = ["armored", "piercing", "vampiric", "swift", "thorns", "regen", "berserk", "tough", "mighty", "ethereal", "shielded"]

# ---- 药水信息 ----
const POTION_INFO = {
	"name": "回春药水",
	"desc": "饮用后恢复 40% 最大生命值。地图与战斗中均可使用，最多携带 5 瓶。",
	"lore": "用翠林密境的晨露与三叶草根酿成，瓶身常年凝着一层薄薄的水汽。据说第一位调出它的草药师只肯收一个铜板——\"救命的东西，不该卖贵。\"",
}

# ---- 生物群系/区域定义 ----
const BIOMES = [
	{
		"name": "翠林密境",
		"element": "wood",
		"sky_top": Color("#16301f"), "sky_bottom": Color("#3f6b3a"),
		"far_color": Color("#274a2c"), "ground_color": Color("#2f5430"),
		"deco_type": "tree",
		"enemy_keys": ["slime", "wolf", "bandit"],
		"boss": {
			"name": "远古树精", "sprite": "golem",
			"palette": { "p": "#5a7d3c", "d": "#33491f", "e": "#ffe18a", "a": "#8a5a2b" },
			"traits": ["summon", "shield_phase", "rage"]
		}
	},
	{
		"name": "灼日荒漠",
		"element": "earth",
		"sky_top": Color("#5a3a1e"), "sky_bottom": Color("#c98e4a"),
		"far_color": Color("#8a5e2c"), "ground_color": Color("#b08246"),
		"deco_type": "dune",
		"enemy_keys": ["scorpion", "mummy", "bandit2"],
		"boss": {
			"name": "陵墓法老", "sprite": "human",
			"palette": { "p": "#d9c08a", "d": "#7a6230", "e": "#3ad0ff", "a": "#f4c454" },
			"traits": ["heavy", "heal", "summon"]
		}
	},
	{
		"name": "白雪山岭",
		"element": "water",
		"sky_top": Color("#23314d"), "sky_bottom": Color("#7e9cc7"),
		"far_color": Color("#46598a"), "ground_color": Color("#cfd8ea"),
		"deco_type": "peak",
		"enemy_keys": ["yeti", "spirit", "wolf2"],
		"boss": {
			"name": "冰霜巨像", "sprite": "golem",
			"palette": { "p": "#bcd4ec", "d": "#5f7aa6", "e": "#2bd7ff", "a": "#eef5ff" },
			"traits": ["shield_phase", "heavy", "rage"]
		}
	},
	{
		"name": "灰烬火山",
		"element": "fire",
		"sky_top": Color("#2a0d0d"), "sky_bottom": Color("#8a2f17"),
		"far_color": Color("#5a1c10"), "ground_color": Color("#3a1410"),
		"deco_type": "peak",
		"enemy_keys": ["lavablob", "elemental", "scorpion2"],
		"boss": {
			"name": "熔岩泰坦", "sprite": "golem",
			"palette": { "p": "#c44a1e", "d": "#6e1f0c", "e": "#ffe14a", "a": "#ff8a3a" },
			"traits": ["rage", "heavy", "summon"]
		}
	},
	{
		"name": "远古遗迹",
		"element": "metal",
		"sky_top": Color("#1a1430"), "sky_bottom": Color("#4b3a78"),
		"far_color": Color("#33285c"), "ground_color": Color("#2c2348"),
		"deco_type": "pillar",
		"enemy_keys": ["construct", "guardian", "spirit2"],
		"boss": {
			"name": "远古守护者", "sprite": "golem",
			"palette": { "p": "#7d6fb8", "d": "#473c74", "e": "#ff4a8a", "a": "#c4b6ff" },
			"traits": ["shield_phase", "summon", "rage", "heal"]
		}
	},
]

# ---- 怪物战斗风格（先后手机制）----
# normal: 普通出手 / feral: 必定先手攻击（先于玩家行动）
# guard: 周期性举盾防御（必先手防御，获得护盾，跳过攻击）
# bash:  盾击型（攻击同时获得护盾，攻击必后手）
const ENEMY_STYLES = {
	"normal": { "name": "",     "desc": "" },
	"feral":  { "name": "先手", "desc": "出手极快，每回合先于你行动" },
	"guard":  { "name": "坚守", "desc": "周期性举盾（先手防御获得护盾，该回合不攻击）" },
	"bash":   { "name": "盾击", "desc": "攻击必定后手，但攻击同时获得护盾" },
}

# ---- 敌人类型定义 ----
# innate: 出生自带的怪物词条（突出特色）；再随机叠加额外词条形成变种
# style: 战斗风格（先手/坚守/盾击）
const ENEMY_TYPES = {
	"slime":      { "name": "史莱姆",     "sprite": "slime",  "palette": { "p": "#5fbf4a", "d": "#2f6b24", "e": "#163612" },          "hp_mult": 0.90, "atk_mult": 0.85, "innate": "", "style": "normal" },
	"wolf":       { "name": "灰狼",       "sprite": "beast",  "palette": { "p": "#8a8f9c", "d": "#4a4f5c", "e": "#ffd23a" },          "hp_mult": 1.00, "atk_mult": 1.10, "innate": "", "style": "feral" },
	"bandit":     { "name": "强盗",       "sprite": "human",  "palette": { "p": "#7a5a3a", "d": "#4a3520", "e": "#e8e6dc", "a": "#9c2f2f" }, "hp_mult": 1.10, "atk_mult": 1.00, "innate": "", "style": "normal" },
	"scorpion":   { "name": "蝎子",       "sprite": "scorp",  "palette": { "p": "#b3702e", "d": "#6e3f14", "e": "#1c0e04" },          "hp_mult": 0.95, "atk_mult": 1.15, "innate": "vampiric", "style": "normal" },
	"mummy":      { "name": "木乃伊",     "sprite": "human",  "palette": { "p": "#cfc4a0", "d": "#8a7e56", "e": "#3ad0ff", "a": "#cfc4a0" }, "hp_mult": 1.25, "atk_mult": 0.90, "innate": "regen", "style": "guard" },
	"bandit2":    { "name": "沙丘劫匪",   "sprite": "human",  "palette": { "p": "#c9a45e", "d": "#7a5e2c", "e": "#fff",    "a": "#2f6b8a" }, "hp_mult": 1.05, "atk_mult": 1.05, "innate": "swift", "style": "bash" },
	"yeti":       { "name": "雪人",       "sprite": "golem",  "palette": { "p": "#e8eef8", "d": "#9cb0cc", "e": "#1c2b44" },          "hp_mult": 1.35, "atk_mult": 1.00, "innate": "tough", "style": "guard" },
	"spirit":     { "name": "冰灵",       "sprite": "ghost",  "palette": { "p": "#9fd6ff", "d": "#4a8ac4", "e": "#0c2b44" },          "hp_mult": 0.80, "atk_mult": 1.20, "innate": "ethereal", "style": "normal" },
	"wolf2":      { "name": "霜狼",       "sprite": "beast",  "palette": { "p": "#cfe2f4", "d": "#7e9cc7", "e": "#2bd7ff" },          "hp_mult": 1.00, "atk_mult": 1.15, "innate": "swift", "style": "feral" },
	"lavablob":   { "name": "熔岩怪",     "sprite": "slime",  "palette": { "p": "#e85a1e", "d": "#8a2508", "e": "#ffe14a" },          "hp_mult": 1.10, "atk_mult": 1.10, "innate": "thorns", "style": "normal" },
	"elemental":  { "name": "火元素",     "sprite": "ghost",  "palette": { "p": "#ff9b3a", "d": "#c44a1e", "e": "#fff1a8" },          "hp_mult": 0.85, "atk_mult": 1.30, "innate": "berserk", "style": "feral" },
	"scorpion2":  { "name": "灰烬蝎",     "sprite": "scorp",  "palette": { "p": "#5a4848", "d": "#2e2222", "e": "#ff5a3a" },          "hp_mult": 1.00, "atk_mult": 1.20, "innate": "vampiric", "style": "normal" },
	"construct":  { "name": "构造体",     "sprite": "golem",  "palette": { "p": "#8d93a8", "d": "#4e5468", "e": "#3aff9b" },          "hp_mult": 1.40, "atk_mult": 1.05, "innate": "armored", "style": "guard" },
	"guardian":   { "name": "守护者",     "sprite": "human",  "palette": { "p": "#6f7d9c", "d": "#3c4860", "e": "#ff4a8a", "a": "#c4b6ff" }, "hp_mult": 1.20, "atk_mult": 1.20, "innate": "shielded", "style": "bash" },
	"spirit2":    { "name": "幽魂",       "sprite": "ghost",  "palette": { "p": "#b59cf4", "d": "#5e4aa0", "e": "#ff4a8a" },          "hp_mult": 0.90, "atk_mult": 1.30, "innate": "piercing", "style": "feral" },
}

# ---- 节点类型 ----
enum NodeType { BATTLE, ELITE, TREASURE, SHOP, EVENT, BOSS }

const NODE_TYPE_NAMES = {
	NodeType.BATTLE:   "战斗",
	NodeType.ELITE:    "精英",
	NodeType.TREASURE: "宝箱",
	NodeType.SHOP:     "商店",
	NodeType.EVENT:    "事件",
	NodeType.BOSS:     "首领",
}

const NODE_TYPE_ICONS = {
	NodeType.BATTLE:   "⚔",
	NodeType.ELITE:    "💀",
	NodeType.TREASURE: "💰",
	NodeType.SHOP:     "🛒",
	NodeType.EVENT:    "?",
	NodeType.BOSS:     "👑",
}

# ---- 玩家基础属性 ----
const PLAYER_BASE = {
	"atk": 3,
	"def": 0,
	"max_hp": 50,
	"crit": 5,
	"crit_dmg": 150,
	"max_energy": 10,
	"start_potions": 2,
	"start_gold": 40,
	"max_potions": 5,
	"bag_capacity": 32,
}

# ---- 战斗数值公式 ----
# 护盾体系（大幅削弱版）：基础值与防御系数下调，且总护盾有上限
const COMBAT = {
	"potion_heal_pct": 0.40,
	"base_def_shield": 5,
	"def_shield_def_mult": 0.6,
	"base_skill_shield": 4,
	"skill_shield_def_mult": 0.5,
	"shield_cap_pct": 0.40,    # 玩家护盾上限 = 最大生命 × 40%
	"skill_dmg_mult": 1.35,
	"skill_cooldown": 3,
	"defend_cooldown": 2,      # 防御冷却：不能无脑堆护盾
	"potion_cooldown": 3,      # 战斗内药水冷却
	"def_dmg_reduction": 0.8,
	"upgrade_stat_mult": 0.12,
	"upgrade_cost_base": 22,
	"max_upgrade_level": 5,
	"splash_mult": 0.30,
	"extra_hit_dmg_mult": 0.8,
	"enemy_count_normal": { "1": 0.40, "2": 0.45, "3": 0.15 },
	"sell_refund_pct": 0.50,
	# 武器职业差异：斧高伤破甲有冷却 / 剑无冷却且盾击先手、有盾增伤 / 弓低伤多段
	"axe_dmg_mult": 1.7,
	"axe_cooldown": 1,
	"axe_sunder_pct": 0.15,    # 斧破甲：每层降低目标防御 15%
	"axe_sunder_stacks": 2,    # 破甲最多叠 2 层
	"axe_sunder_turns": 2,     # 破甲持续 2 回合
	"sword_bash_shield_mult": 1.5,   # 剑：盾击护盾量 ×1.5
	"sword_shield_atk_pct": 0.20,    # 剑：护盾在身时普攻伤害 +20%
	"bow_hits": 2,
	"bow_hit_mult": 0.4,
	"bow_combo_cap": 2,        # 贯连词条/连击之道天赋：暴击叠加的连击数上限（仅弓）
	"multihit_cap": 5,         # 连击数（连击词条+贯连累积）总上限
	"max_attacks_per_action": 10,    # 单次行动总攻击数上限（含迅捷追击）
	# 元素克制
	"elem_counter_mult": 1.30,
	"elem_resist_mult": 0.80,
	"elem_proc_chance": 22.0,
	"burn_turns": 2,
	"burn_atk_pct": 0.25,      # 灼烧每回合伤害 = 玩家攻击 × 25%
	"weaken_pct": 0.30,        # 冰缚/削弱：敌人攻击降低比例
	# 岩盾触发护盾 = 4 + 防御 × 0.3
	"earth_shield_base": 4.0,
	"earth_shield_def_mult": 0.3,
	# 无限周目：怪物数值按"有效区域 = 区域 + 周目×5"沿区域曲线成长；
	# 金币与护盾另有周目系数
	"cycle_gold_mult": 0.35,
	"cycle_enemy_shield_mult": 0.35,   # 周目越高，怪物护盾越厚
	# 熔炼与锻打
	"smelt_cost": 40,          # 熔炼（随机萃取一条词条）费用
	"purge_cost": 40,          # 锻打消除一条已有词条的费用
	"forge_cost_base": 60,
	"forge_cost_region": 30,
	"essence_cap": 6,
	# 精铸与分解（区域效能制度）
	"refine_cost": 5,          # 精铸一次消耗的精粹
}

# ---- 分解装备获得的精粹（按稀有度）----
const DUST_GAIN = {
	Rarity.COMMON: 1,
	Rarity.RARE: 3,
	Rarity.EPIC: 8,
	Rarity.LEGENDARY: 20,
}

static func dust_gain(rarity: int) -> int:
	return int(DUST_GAIN.get(rarity, 1))

# ---- 掉落概率（按怪物级别区分）----
# 普通怪爆率低、精英/首领必掉且稀有度下限更高
const DROP_RULES = {
	"normal": { "chance": 30.0, "region_bonus": 4.0, "min_rarity": -1 },
	"elite":  { "chance": 100.0, "region_bonus": 0.0, "min_rarity": Rarity.RARE },
	"boss":   { "chance": 100.0, "region_bonus": 0.0, "min_rarity": Rarity.EPIC },
	"cycleboss": { "chance": 100.0, "region_bonus": 0.0, "min_rarity": Rarity.EPIC },
}

# 稀有度抽取权重（普通怪 / 精英 / 首领）
# 精英 稀有:史诗 = 7:3（无传奇）；首领 史诗:传奇 = 7:3；
# 商店传奇大幅下调；普通怪与宝箱小幅收紧
const RARITY_WEIGHTS = {
	"normal": [0.58, 0.30, 0.105, 0.015],
	"elite":  [0.00, 0.70, 0.30, 0.00],
	"boss":   [0.00, 0.00, 0.70, 0.30],
	"cycleboss": [0.00, 0.00, 0.60, 0.40],   # 周目大 Boss：史诗:传说 = 6:4
	"shop":   [0.32, 0.44, 0.225, 0.015],
	"chest":  [0.42, 0.37, 0.18, 0.03],
}

# ============================================================
# 随机事件池
# 每个事件: key / title / desc / choices
# choice: label / 可选 cost_gold / effects: 效果数组
# 效果类型见 GameState._apply_event_effects
# ============================================================
const EVENT_POOL = [
	{
		"key": "merchant", "title": "神秘商人",
		"desc": "一个披着斗篷的身影打开了一个装满闪亮装备的箱子。\"一次交易……大概不亏。\"",
		"choices": [
			{ "label": "付钱购买（神秘装备）", "cost_gold": [45, 20], "effects": [{ "type": "item", "boost": 1 }] },
			{ "label": "婉拒离开", "effects": [] },
		],
	},
	{
		"key": "shrine", "title": "远古祭坛",
		"desc": "古老的能量在石中嗡鸣。以你的生命力为代价换取力量？",
		"choices": [
			{ "label": "献祭（失去 20% 生命，本区域攻击 +15%）", "effects": [{ "type": "hp_pct", "pct": -0.20 }, { "type": "atk_buff", "pct": 0.15 }] },
			{ "label": "敬而远之", "effects": [] },
		],
	},
	{
		"key": "cave", "title": "藏宝洞穴",
		"desc": "两条通道：一条明亮而安静，一条黑暗而……有呼吸声。",
		"choices": [
			{ "label": "明亮通道（稳拿金币）", "effects": [{ "type": "gold", "base": 30, "region_mult": 12 }] },
			{ "label": "黑暗通道（一搏）", "effects": [{ "type": "random", "options": [
				{ "weight": 0.5, "text": "黑暗深处竟藏着一件珍宝！", "effects": [{ "type": "item", "boost": 2 }] },
				{ "weight": 0.5, "text": "伏击！黑暗中跳出了敌人！", "effects": [{ "type": "fight", "elite": true }] },
			] }] },
		],
	},
	{
		"key": "traveler", "title": "受伤的旅人",
		"desc": "一位旅人倚着岩石，腿上缠着渗血的布条。\"行行好……我会报答你的。\"",
		"choices": [
			{ "label": "递上一瓶药水", "require_potion": 1, "effects": [{ "type": "potion", "count": -1 }, { "type": "random", "options": [
				{ "weight": 0.6, "text": "旅人感激地塞给你一袋金币。", "effects": [{ "type": "gold", "base": 55, "region_mult": 15 }] },
				{ "weight": 0.4, "text": "\"拿着吧，这东西我用不上了。\"旅人递来一件装备。", "effects": [{ "type": "item", "boost": 1 }] },
			] }] },
			{ "label": "抱歉，自身难保", "effects": [] },
		],
	},
	{
		"key": "camp", "title": "废弃营地",
		"desc": "篝火的余烬还散着微温，帐篷半塌着。主人似乎走得很匆忙。",
		"choices": [
			{ "label": "搜刮营地", "effects": [{ "type": "random", "options": [
				{ "weight": 0.55, "text": "你在睡袋下找到了一袋金币！", "effects": [{ "type": "gold", "base": 35, "region_mult": 10 }] },
				{ "weight": 0.25, "text": "帐篷里藏着一件装备！", "effects": [{ "type": "item", "boost": 0 }] },
				{ "weight": 0.20, "text": "营地的主人回来了——而且不太友好！", "effects": [{ "type": "fight", "elite": false }] },
			] }] },
			{ "label": "借篝火休息（恢复 25% 生命）", "effects": [{ "type": "hp_pct", "pct": 0.25 }] },
		],
	},
	{
		"key": "fortune", "title": "流浪占卜师",
		"desc": "水晶球里雾气翻涌。\"我能看见你的下一场战斗……想知道怎么赢吗？\"",
		"choices": [
			{ "label": "求他指点（本区域攻击 +10%）", "cost_gold": [30, 0], "effects": [{ "type": "atk_buff", "pct": 0.10 }] },
			{ "label": "命运要自己把握", "effects": [] },
		],
	},
	{
		"key": "spring", "title": "魔法泉水",
		"desc": "一汪泛着微光的泉水，水面映出的不是你的脸，而是一片星空。",
		"choices": [
			{ "label": "畅饮泉水", "effects": [{ "type": "random", "options": [
				{ "weight": 0.6, "text": "暖流涌遍全身——生命完全恢复！", "effects": [{ "type": "full_heal" }] },
				{ "weight": 0.4, "text": "泉水冰冷刺骨！你失去了一些生命。", "effects": [{ "type": "hp_pct", "pct": -0.15 }] },
			] }] },
			{ "label": "灌一瓶带走（+1 药水）", "effects": [{ "type": "potion", "count": 1 }] },
		],
	},
	{
		"key": "blacksmith", "title": "流浪铁匠",
		"desc": "炉火正旺，铁匠用独眼打量你的武器：\"这玩意儿，我能给你白敲两锤。\"",
		"choices": [
			{ "label": "请他强化武器（免费 +1）", "effects": [{ "type": "upgrade_weapon" }] },
			{ "label": "不劳烦了", "effects": [] },
		],
	},
	{
		"key": "gambler", "title": "路边赌徒",
		"desc": "一个咧嘴笑的家伙摇着骰盅：\"押 40 金币，赢了翻倍，输了归我。敢不敢？\"",
		"choices": [
			{ "label": "押下赌注（赢了翻倍）", "cost_gold": [40, 0], "effects": [{ "type": "random", "options": [
				{ "weight": 0.5, "text": "骰子开出三个六！赌徒咬牙付了 80 金币。", "effects": [{ "type": "gold_flat", "amount": 80 }] },
				{ "weight": 0.5, "text": "\"承让承让。\"赌徒收走了你的金币。", "effects": [] },
			] }] },
			{ "label": "不赌", "effects": [] },
		],
	},
	{
		"key": "monument", "title": "古老石碑",
		"desc": "石碑上的铭文早已模糊，但凑近时，一股苍劲的力量顺着指尖涌来。",
		"choices": [
			{ "label": "研读铭文（最大生命 +6）", "effects": [{ "type": "max_hp", "amount": 6 }] },
			{ "label": "不去惊扰", "effects": [] },
		],
	},
	{
		"key": "fairy", "title": "被困的精灵",
		"desc": "一只巴掌大的精灵被蛛网缠住，扑腾着发光的翅膀朝你呼救。",
		"choices": [
			{ "label": "撕开蛛网救它", "effects": [{ "type": "hp_pct", "pct": 0.30 }, { "type": "toast", "text": "精灵洒下一捧光尘：恢复 30% 生命！" }] },
			{ "label": "绕道走开", "effects": [] },
		],
	},
	{
		"key": "caravan", "title": "商队的悬赏",
		"desc": "商队首领拦住你：\"前面有伙强匪占了道。替我们清掉，重金酬谢！\"",
		"choices": [
			{ "label": "接下悬赏（精英战斗，先收 60 金定金）", "effects": [{ "type": "gold_flat", "amount": 60 }, { "type": "fight", "elite": true }] },
			{ "label": "绕路而行", "effects": [] },
		],
	},
	{
		"key": "mushroom", "title": "发光蘑菇圈",
		"desc": "一圈幽幽发光的蘑菇围成了完美的圆。传说蘑菇圈是精灵跳舞的地方。",
		"choices": [
			{ "label": "尝一朵蘑菇", "effects": [{ "type": "random", "options": [
				{ "weight": 0.5, "text": "味道像烤栗子！恢复 20% 生命。", "effects": [{ "type": "hp_pct", "pct": 0.20 }] },
				{ "weight": 0.5, "text": "苦得发麻！你失去 10% 生命。", "effects": [{ "type": "hp_pct", "pct": -0.10 }] },
			] }] },
			{ "label": "采一些备用（+1 药水）", "effects": [{ "type": "potion", "count": 1 }] },
		],
	},
	{
		"key": "battlefield", "title": "旧日战场",
		"desc": "锈蚀的刀剑半埋在土里，断裂的旗帜仍在风中摇晃。这里曾有一场恶战。",
		"choices": [
			{ "label": "翻找遗物", "effects": [{ "type": "random", "options": [
				{ "weight": 0.45, "text": "你从尸骸下抽出一件还能用的装备！", "effects": [{ "type": "item", "boost": 0 }] },
				{ "weight": 0.30, "text": "你搜出了一袋阵亡者的军饷。", "effects": [{ "type": "gold", "base": 40, "region_mult": 10 }] },
				{ "weight": 0.25, "text": "亡者的怨念缠上了你！失去 12% 生命。", "effects": [{ "type": "hp_pct", "pct": -0.12 }] },
			] }] },
			{ "label": "为亡者默哀（恢复 10% 生命）", "effects": [{ "type": "hp_pct", "pct": 0.10 }] },
		],
	},
	{
		"key": "mimic", "title": "孤零零的宝箱",
		"desc": "荒野正中摆着一只崭新的宝箱。太干净了，干净得不太对劲。",
		"choices": [
			{ "label": "打开它", "effects": [{ "type": "random", "options": [
				{ "weight": 0.6, "text": "真的是宝物！", "effects": [{ "type": "item", "boost": 1 }] },
				{ "weight": 0.4, "text": "宝箱长出了獠牙——是宝箱怪！", "effects": [{ "type": "fight", "elite": true }] },
			] }] },
			{ "label": "太可疑了，不碰", "effects": [] },
		],
	},
	{
		"key": "peddler", "title": "迷路的小贩",
		"desc": "小贩推着吱呀作响的独轮车：\"客官！药水半价！就当帮我清库存！\"",
		"choices": [
			{ "label": "买一瓶半价药水", "cost_gold": [15, 0], "effects": [{ "type": "potion", "count": 1 }] },
			{ "label": "不需要", "effects": [] },
		],
	},
	{
		"key": "wish", "title": "许愿星井",
		"desc": "井底沉着数不清的硬币，每一枚都映着一颗星星。投一枚，许个愿？",
		"choices": [
			{ "label": "投币许愿", "cost_gold": [25, 0], "effects": [{ "type": "random", "options": [
				{ "weight": 0.40, "text": "星光垂落——本区域攻击 +12%！", "effects": [{ "type": "atk_buff", "pct": 0.12 }] },
				{ "weight": 0.30, "text": "井水泛起涟漪——生命完全恢复！", "effects": [{ "type": "full_heal" }] },
				{ "weight": 0.30, "text": "井里只传来一声遥远的回响……什么也没发生。", "effects": [] },
			] }] },
			{ "label": "钱要花在刀刃上", "effects": [] },
		],
	},
	{
		"key": "echo", "title": "回声峡谷",
		"desc": "你的脚步声在岩壁间反复回荡，渐渐地，回声里混进了另一个声音……",
		"choices": [
			{ "label": "循声探查", "effects": [{ "type": "random", "options": [
				{ "weight": 0.5, "text": "声音来自一处藏宝的岩缝！", "effects": [{ "type": "gold", "base": 45, "region_mult": 12 }] },
				{ "weight": 0.5, "text": "那是猎食者的拟声诱饵！", "effects": [{ "type": "fight", "elite": false }] },
			] }] },
			{ "label": "加快脚步离开", "effects": [] },
		],
	},
]

# ============================================================
# 剧情 CG（assets/cg/N.png + 字幕浮现 + 下一步）
# 1-8：区域 1-4 进入前/首领战后成对；9：区域 5 进入前；
# 10：区域 5 首领战前；11-13：击败最终首领后（衔接下一周目轮回）
# 14-18：开场序章（开始征程后、区域进入 CG 之前，每存档一次）
# ============================================================
const CG_DATA = {
	14: { "title": "序章 · 五道封印",
		"text": "很久以前，五道封印曾将灾厄锁于世界深处。" },
	15: { "title": "序章 · 封印松动",
		"text": "当封印松动，最先失声的，是世界边缘的村镇。" },
	16: { "title": "序章 · 古印苏醒",
		"text": "古印苏醒，仿佛在回应命运未竟的召唤。" },
	17: { "title": "序章 · 踏出第一步",
		"text": "告别熟悉的土地，告别安宁的岁月，当第一步踏出之时，命运的齿轮便已开始转动。" },
	18: { "title": "序章 · 远征启程",
		"text": "前方没有答案，只有等待被揭开的真相。而这场跨越五大地域搜集古印碎片的远征，才刚刚开始。" },
	1: { "title": "翠林秘境 · 启程",
		"text": "雾起于古林，树影如同沉默的巨兽伏卧大地。探险者踏入这片被遗忘的秘境时，听见的不是风声，而是腐化根系在黑土下缓缓苏醒的低吟。传言中的庇护之森，已然沦为第一道裂开的封印之地。" },
	2: { "title": "翠林秘境 · 封印初现",
		"text": "当森林领主倒下，盘踞林间的诅咒随之崩散，古树重新挺起被压弯的枝干。探险者拾起第一枚古印碎片，方才明白，这片森林并非终点，而是灾厄蔓延的起始。真正的道路，正在更深处等待他的踏入。" },
	3: { "title": "大漠荒原 · 黄沙之祭",
		"text": "越过林海，天地骤然化作无垠黄沙。烈日灼空，风暴如刃，埋葬了古王朝的废墟在沙下静默千年。亡者的咒音在夜幕中回荡，仿佛这片荒原本身，便是献给死亡的祭坛。" },
	4: { "title": "大漠荒原 · 神庙重光",
		"text": "沙海死神在风暴中碎裂，黄沙裹挟着断刃与咒文沉入地底。被掩埋的神庙重见天光，仿佛沉睡已久的古老意志终于被唤醒。第二枚印记现世，五方封印的真相，也随之露出冰冷的一角。" },
	5: { "title": "凛冬雪原 · 冰封长路",
		"text": "离开炽热沙海，探险者踏入极北冻土。暴雪遮天，寒意侵骨，断旗与冰碑静立于死寂之中，见证着早已消逝的誓言。这里没有温度，没有回声，只有通往命运深处的冰冷长路。" },
	6: { "title": "凛冬雪原 · 击穿冰墙",
		"text": "霜冻泰坦崩裂之时，积雪深处传来远古战鼓般的回响。探险者自冰冠祭坛取回第三枚印记，也看见了被冻封千年的守誓之地。寒冬未曾终结，但挡在前路上的冰墙，已被他亲手击穿。" },
	7: { "title": "烈焰火山 · 火与钢的圣域",
		"text": "穿过雪原尽头，地脉的怒火自黑曜石裂缝间喷涌而出。熔岩翻腾，铁链低鸣，古代锻炉在深渊中仍未沉寂。这里是火与钢的圣域，也是五重封印中最为狂暴的一环。若要继续前行，便必须踏过这座燃烧的深渊。" },
	8: { "title": "烈焰火山 · 地火归寂",
		"text": "炎魔核心轰然破碎，烈焰如潮退去，地脉之火重归沉寂。探险者立于焦黑王座之前，第四枚印记在掌中发出微光，也照亮了深埋于火山之下的古代封印装置。至此，他终于明白，自己所面对的，正是一个正在失控的远古秩序。" },
	9: { "title": "远古遗迹 · 终局之门",
		"text": "当探险者抵达远古遗迹，眼前已不是人间景象，而是被时间遗忘的神话残章。石桥横亘虚空，神殿倒悬天穹，沉默的石像与圣灵守望着失落的誓约。这里是终局的门扉，也是古代文明最后的心脏。" },
	10: { "title": "神座之前",
		"text": "守护者尚未显现全貌，遗迹深处的封印却已开始轰鸣。探险者独自立于崩塌的石阶尽头，仰望那座悬于虚空中的古老神座——这不是终点，而是与旧世界意志正面相撞的开端。" },
	11: { "title": "决战 · 列阵",
		"text": "同伴们在封印之环前列阵，刀锋、法杖与圣器同时指向天空。守护者自黄金光幕中缓缓苏醒，整座遗迹随之震颤。远征者已踏入命运核心，最后的战斗，终于拉开帷幕。" },
	12: { "title": "决战 · 意志相撞",
		"text": "战斗在轰鸣中爆发。冒险者高举武器，踏着碎裂的石阶直冲而上；守护者则以无可匹敌的古代之力回应，符文、烈光与崩裂的岩石在半空交错。每一次碰撞，都像是在撼动整座遗迹的命脉。此刻已无退路，唯有以意志回应意志，以火焰击碎永恒。" },
	13: { "title": "远征的尽头",
		"text": "当最后一道封印归于沉寂，永恒守护者的身躯终于崩解。\n\n漂浮千年的遗迹开始缓缓回落，失控的古代力量也重新归于静默。\n\n探险者立于破碎祭坛之上，望着久违的天光穿透云层。\n\n这一刻，他以为远征已经结束。" },
	# ---- 周目大 Boss 终局 CG（final CG/0-9 → 资源 19-28）----
	19: { "title": "噩梦苏醒",
		"text": "然而在遗迹最深处，某些从未被记载于典籍中的存在，正循着封印消散后的余温缓缓苏醒。它们并非守护者，也并非这片世界应有之物，而是比轮回更加古老的噩梦。" },
	20: { "title": "八岐大蛇 · 苏醒",
		"text": "深渊之下，八首之影正在翻身。古老的蛇神循着封印的余温苏醒，八道目光同时锁定了前路。" },
	21: { "title": "八岐大蛇 · 退潮",
		"text": "当最后一颗蛇首坠落，深渊的咒潮随之退去。可世界并未因此安宁——它只是暂时合上了眼。" },
	22: { "title": "九尾狐 · 抬眸",
		"text": "月影之中，九尾狐自古咒中抬眸。它并非前来拦路，而是来审判踏入轮回之人。" },
	23: { "title": "九尾狐 · 星屑",
		"text": "九尾之火散作漫天星屑，幻影与真身一同崩解。可被击败的，只是这一夜的狐影。" },
	24: { "title": "巨大三头石像 · 睁眼",
		"text": "三首石神自沉眠中睁眼。古代王权最后的守门者，正以无声的重量碾向来者。" },
	25: { "title": "巨大三头石像 · 归尘",
		"text": "石躯尽碎，王座归尘。守门者倒下之处，新的通路也随之显现。" },
	26: { "title": "终末虚空兽 · 呼吸",
		"text": "黑暗深处传来不属于这个世界的呼吸。那并非野兽，而是被轮回喂养出来的终末之形。" },
	27: { "title": "终末虚空兽 · 回响",
		"text": "它的躯壳已碎，但虚空仍在回响。被击倒的不是结局，只是更深黑暗的前奏。" },
	28: { "title": "轮回不息",
		"text": "古老存在已经倒下，然而轮回并不会因此停滞。\n\n世界正在回应这场胜利。而回应的代价——是更加危险的未来。\n\n“寻路者，欢迎来到新周目——这里的敌人……已经记住了你的套路。”" },
}
const CG_INTRO = [14, 15, 16, 17, 18]      # 开场序章（新远征启程时，区域进入 CG 之前）
const CG_REGION_ENTER = [1, 3, 5, 7, 9]    # 各区域进入前
const CG_REGION_CLEAR = [2, 4, 6, 8]       # 区域 1-4 首领战后
const CG_PRE_FINAL_BOSS = 10               # 区域 5 首领战前
const CG_FINALE = [11, 12, 13]             # 最终首领战后（每周目轮回都播放）
const CG_CYCLE_INTRO = 19                  # 周目大 Boss 登场旁白（紧接 13 之后）
const CG_CYCLE_OUTRO = 28                  # 周目大 Boss 击败后 → 新周目欢迎

# ---- 周目大 Boss（区域 5 通关后、进入新周目前的压轴战）----
# 前四周目按顺序出现，第五周目起随机；明显强于区域 Boss
const CYCLE_BOSSES = [
	{ "key": "orochi",  "name": "八岐大蛇", "sprite": "orochi",
		"palette": { "p": "#3f9a5a", "d": "#1c5230", "e": "#ffe14a", "a": "#7a2f2f" },
		"traits": ["rage", "summon", "heavy"],
		"hp_mult": 1.55, "atk_mult": 1.45, "def_mult": 1.40,
		"encounter_cg": 20, "defeat_cg": 21 },
	{ "key": "kitsune", "name": "九尾狐", "sprite": "kitsune",
		"palette": { "p": "#e8763a", "d": "#8a3414", "e": "#fff0c4", "a": "#ffd86a" },
		"traits": ["heal", "rage", "summon"],
		"hp_mult": 1.45, "atk_mult": 1.55, "def_mult": 1.30,
		"encounter_cg": 22, "defeat_cg": 23 },
	{ "key": "colossus", "name": "巨大三头石像", "sprite": "colossus",
		"palette": { "p": "#9aa0ae", "d": "#4c505e", "e": "#ffcf5a", "a": "#c4cad8" },
		"traits": ["shield_phase", "heavy", "rage"],
		"hp_mult": 1.70, "atk_mult": 1.35, "def_mult": 1.60,
		"encounter_cg": 24, "defeat_cg": 25 },
	{ "key": "voidbeast", "name": "终末虚空兽", "sprite": "voidbeast",
		"palette": { "p": "#6a3fae", "d": "#2c184e", "e": "#48f0d0", "a": "#c46fff" },
		"traits": ["rage", "heal", "summon", "shield_phase"],
		"hp_mult": 1.60, "atk_mult": 1.55, "def_mult": 1.45,
		"encounter_cg": 26, "defeat_cg": 27 },
]

# cleared_cycle：已通关的周目数（0=第一周目通关）。0-3 按序，≥4 随机
static func pick_cycle_boss(cleared_cycle: int) -> Dictionary:
	if cleared_cycle < CYCLE_BOSSES.size():
		return CYCLE_BOSSES[cleared_cycle]
	return CYCLE_BOSSES[randi() % CYCLE_BOSSES.size()]

static func get_cg(id: int) -> Dictionary:
	return CG_DATA.get(id, { "title": "", "text": "" })

# ---- 辅助函数 ----
static func get_rarity_name(rarity: int) -> String:
	return RARITY_DATA[rarity]["name"]

static func get_rarity_color(rarity: int) -> Color:
	return RARITY_DATA[rarity]["color"]

static func get_enemy_type(key: String) -> Dictionary:
	return ENEMY_TYPES.get(key, ENEMY_TYPES["slime"])

static func get_biome(region: int) -> Dictionary:
	if region < 0 or region >= BIOMES.size():
		return BIOMES[0]
	return BIOMES[region]

static func get_event(key: String) -> Dictionary:
	for ev in EVENT_POOL:
		if ev.key == key:
			return ev
	return EVENT_POOL[0]

# ---- 元素辅助 ----
static func element_name(key: String) -> String:
	return ELEMENTS.get(key, {}).get("name", "?")

static func element_color(key: String) -> Color:
	return ELEMENTS.get(key, {}).get("color", Color.WHITE)

## 攻方元素对守方元素的伤害系数
static func element_mult(attacker: String, defender: String) -> float:
	if attacker == "" or defender == "":
		return 1.0
	var a = ELEMENTS.get(attacker, {})
	if a.get("beats", "") == defender:
		return COMBAT["elem_counter_mult"]
	var d = ELEMENTS.get(defender, {})
	if d.get("beats", "") == attacker:
		return COMBAT["elem_resist_mult"]
	return 1.0

static func get_enemy_style(key: String) -> Dictionary:
	var t = get_enemy_type(key)
	return ENEMY_STYLES.get(str(t.get("style", "normal")), ENEMY_STYLES["normal"])

static func get_perk(key: String) -> Dictionary:
	return PERKS.get(key, { "name": key, "desc": "", "fx": {} })

static func slot_name(slot: String) -> String:
	return SLOT_NAMES.get(slot, slot)

static func get_monster_affix(key: String) -> Dictionary:
	return MONSTER_AFFIXES.get(key, { "name": key, "desc": "", "color": Color.WHITE })

static func monster_affix_names(affixes: Array) -> String:
	var parts = []
	for a in affixes:
		parts.append(get_monster_affix(a).name)
	return "·".join(parts)
