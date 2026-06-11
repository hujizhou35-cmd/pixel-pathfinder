extends Node

# ============================================================
# 游戏数据定义 - 从 HTML 原型迁移
# 所有平衡数据、敌人配置、装备模板、词条定义
# ============================================================

# ---- 稀有度定义 ----
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_DATA = {
	Rarity.COMMON:    { "name": "普通",    "color": Color("#b8bcc8"), "mult": 1.00, "max_affixes": 0, "base_value": 18 },
	Rarity.RARE:      { "name": "稀有",    "color": Color("#5aa7ff"), "mult": 1.25, "max_affixes": 1, "base_value": 42 },
	Rarity.EPIC:      { "name": "史诗",    "color": Color("#bd6fff"), "mult": 1.55, "max_affixes": 2, "base_value": 85 },
	Rarity.LEGENDARY: { "name": "传说",    "color": Color("#f4c454"), "mult": 1.90, "max_affixes": 2, "base_value": 170 },
}

# ---- 武器模板 ----
const WEAPON_TEMPLATES = {
	"sword": { "base_name": "长剑", "unique_5": "击杀敌人后获得 8 点护盾", "slot": "weapon" },
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

# ---- 词条定义 ----
const AFFIXES = {
	"crit":    { "name": "精准",     "desc": "暴击率 +10%",              "kind": "off" },
	"critdmg": { "name": "残忍",     "desc": "暴击伤害 +40%",            "kind": "off" },
	"swift":   { "name": "迅捷",     "desc": "15% 概率连击",            "kind": "off" },
	"pierce":  { "name": "穿透",     "desc": "攻击力 +12%",              "kind": "off" },
	"chain":   { "name": "连锁",     "desc": "攻击对其它敌人溅射 30%",  "kind": "off" },
	"block":   { "name": "守护",     "desc": "+10% 概率减半伤害",       "kind": "def" },
	"bulwark": { "name": "壁垒",     "desc": "战斗开始时获得 10 护盾",  "kind": "def" },
	"regen":   { "name": "再生",     "desc": "每回合恢复 2 生命",       "kind": "def" },
	"stone":   { "name": "石肤",     "desc": "受到的伤害减少 10%",      "kind": "def" },
	"greed":   { "name": "贪婪",     "desc": "战斗金币收益 +25%",       "kind": "exp" },
	"fortune": { "name": "幸运",     "desc": "装备掉落率 +15%",         "kind": "exp" },
	"haggle":  { "name": "议价",     "desc": "商店折扣 15%",            "kind": "exp" },
}

const AFFIX_KEYS = ["crit", "critdmg", "swift", "pierce", "chain", "block", "bulwark", "regen", "stone", "greed", "fortune", "haggle"]

# ---- 装备前缀 ----
const EQUIP_PREFIXES = ["破旧的", "坚固的", "锋利的", "淬火的", "符文的", "皇家", "远古的", "晨曦", "风暴", "灰烬", "霜冻", "镀金"]

# ---- 生物群系/区域定义 ----
const BIOMES = [
	{
		"name": "翠林密境",
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

# ---- 敌人类型定义 ----
const ENEMY_TYPES = {
	"slime":      { "name": "史莱姆",     "sprite": "slime",  "palette": { "p": "#5fbf4a", "d": "#2f6b24", "e": "#163612" },          "hp_mult": 0.90, "atk_mult": 0.85 },
	"wolf":       { "name": "灰狼",       "sprite": "beast",  "palette": { "p": "#8a8f9c", "d": "#4a4f5c", "e": "#ffd23a" },          "hp_mult": 1.00, "atk_mult": 1.10 },
	"bandit":     { "name": "强盗",       "sprite": "human",  "palette": { "p": "#7a5a3a", "d": "#4a3520", "e": "#e8e6dc", "a": "#9c2f2f" }, "hp_mult": 1.10, "atk_mult": 1.00 },
	"scorpion":   { "name": "蝎子",       "sprite": "scorp",  "palette": { "p": "#b3702e", "d": "#6e3f14", "e": "#1c0e04" },          "hp_mult": 0.95, "atk_mult": 1.15 },
	"mummy":      { "name": "木乃伊",     "sprite": "human",  "palette": { "p": "#cfc4a0", "d": "#8a7e56", "e": "#3ad0ff", "a": "#cfc4a0" }, "hp_mult": 1.25, "atk_mult": 0.90 },
	"bandit2":    { "name": "沙丘劫匪",   "sprite": "human",  "palette": { "p": "#c9a45e", "d": "#7a5e2c", "e": "#fff",    "a": "#2f6b8a" }, "hp_mult": 1.05, "atk_mult": 1.05 },
	"yeti":       { "name": "雪人",       "sprite": "golem",  "palette": { "p": "#e8eef8", "d": "#9cb0cc", "e": "#1c2b44" },          "hp_mult": 1.35, "atk_mult": 1.00 },
	"spirit":     { "name": "冰灵",       "sprite": "ghost",  "palette": { "p": "#9fd6ff", "d": "#4a8ac4", "e": "#0c2b44" },          "hp_mult": 0.80, "atk_mult": 1.20 },
	"wolf2":      { "name": "霜狼",       "sprite": "beast",  "palette": { "p": "#cfe2f4", "d": "#7e9cc7", "e": "#2bd7ff" },          "hp_mult": 1.00, "atk_mult": 1.15 },
	"lavablob":   { "name": "熔岩怪",     "sprite": "slime",  "palette": { "p": "#e85a1e", "d": "#8a2508", "e": "#ffe14a" },          "hp_mult": 1.10, "atk_mult": 1.10 },
	"elemental":  { "name": "火元素",     "sprite": "ghost",  "palette": { "p": "#ff9b3a", "d": "#c44a1e", "e": "#fff1a8" },          "hp_mult": 0.85, "atk_mult": 1.30 },
	"scorpion2":  { "name": "灰烬蝎",     "sprite": "scorp",  "palette": { "p": "#5a4848", "d": "#2e2222", "e": "#ff5a3a" },          "hp_mult": 1.00, "atk_mult": 1.20 },
	"construct":  { "name": "构造体",     "sprite": "golem",  "palette": { "p": "#8d93a8", "d": "#4e5468", "e": "#3aff9b" },          "hp_mult": 1.40, "atk_mult": 1.05 },
	"guardian":   { "name": "守护者",     "sprite": "human",  "palette": { "p": "#6f7d9c", "d": "#3c4860", "e": "#ff4a8a", "a": "#c4b6ff" }, "hp_mult": 1.20, "atk_mult": 1.20 },
	"spirit2":    { "name": "幽魂",       "sprite": "ghost",  "palette": { "p": "#b59cf4", "d": "#5e4aa0", "e": "#ff4a8a" },          "hp_mult": 0.90, "atk_mult": 1.30 },
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
	"bag_capacity": 6,
}

# ---- 战斗数值公式 ----
const COMBAT = {
	"potion_heal_pct": 0.40,
	"base_def_shield": 7,
	"def_shield_def_mult": 1.6,
	"base_skill_shield": 6,
	"skill_shield_def_mult": 1.2,
	"skill_dmg_mult": 1.35,
	"skill_cooldown": 3,
	"def_dmg_reduction": 0.8,
	"upgrade_stat_mult": 0.12,
	"upgrade_cost_base": 22,
	"max_upgrade_level": 5,
	"splash_mult": 0.30,
	"extra_hit_dmg_mult": 0.8,
	"enemy_count_normal": { "1": 0.40, "2": 0.45, "3": 0.15 },
}

# ---- 事件定义 ----
const EVENTS = {
	"merchant": {
		"title": "神秘商人",
		"desc": "一个披着斗篷的身影打开了一个装满闪亮装备的箱子。\"一次交易……大概。\"",
		"cost_mult": 45,
		"cost_region_mult": 20,
	},
	"shrine": {
		"title": "远古祭坛",
		"desc": "古老的能量在石中嗡鸣。以你的生命力为代价换取力量？",
		"hp_cost_pct": 0.20,
		"buff_amount": 0.15,
	},
	"cave": {
		"title": "藏宝洞穴",
		"desc": "两条通道：一条明亮而安静，一条黑暗而……有呼吸声。",
		"safe_gold_base": 30,
		"safe_gold_region": 12,
	},
}

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
