extends Node

# ============================================================
# 游戏数据定义
# 所有平衡数据、敌人配置、装备模板、词条定义、事件池
# ============================================================

# ---- 稀有度定义 ----
# 属性强度/词条数量/价值 严格按 传奇 > 史诗 > 稀有 > 普通 递增
enum Rarity { COMMON, RARE, EPIC, LEGENDARY }

const RARITY_DATA = {
	Rarity.COMMON:    { "name": "普通", "color": Color("#b8bcc8"), "mult": 1.00, "max_affixes": 0, "base_value": 18 },
	Rarity.RARE:      { "name": "稀有", "color": Color("#5aa7ff"), "mult": 1.30, "max_affixes": 1, "base_value": 45 },
	Rarity.EPIC:      { "name": "史诗", "color": Color("#bd6fff"), "mult": 1.65, "max_affixes": 2, "base_value": 95 },
	Rarity.LEGENDARY: { "name": "传说", "color": Color("#f4c454"), "mult": 2.05, "max_affixes": 3, "base_value": 190 },
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
	"sell_refund_pct": 0.50,
}

# ---- 掉落概率（按怪物级别区分）----
# 普通怪爆率低、精英/首领必掉且稀有度下限更高
const DROP_RULES = {
	"normal": { "chance": 30.0, "region_bonus": 4.0, "min_rarity": -1 },
	"elite":  { "chance": 100.0, "region_bonus": 0.0, "min_rarity": Rarity.RARE },
	"boss":   { "chance": 100.0, "region_bonus": 0.0, "min_rarity": Rarity.EPIC },
}

# 稀有度抽取权重（普通怪 / 精英 / 首领）
const RARITY_WEIGHTS = {
	"normal": [0.55, 0.30, 0.12, 0.03],
	"elite":  [0.00, 0.55, 0.33, 0.12],
	"boss":   [0.00, 0.00, 0.62, 0.38],
	"shop":   [0.30, 0.40, 0.24, 0.06],
	"chest":  [0.40, 0.36, 0.18, 0.06],
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
