extends Node

# ============================================================
# 游戏状态管理器 - Autoload Singleton
# 管理所有运行时状态：玩家、装备、地图、战斗、多存档位
# 存档策略：进入节点前快照 + 地图态实时保存 + 关窗自动保存
# ============================================================

const EquipmentFactory = preload("res://scripts/equipment/equipment_factory.gd")
const EquipmentModifier = preload("res://scripts/equipment/equipment_modifier.gd")
const LoreDataScript = preload("res://scripts/data/lore_data.gd")
const MapGenerator = preload("res://scripts/map/map_generator.gd")
const CombatManager = preload("res://scripts/combat/combat_manager.gd")

# 游戏状态枚举
enum State { TITLE, MAP, COMBAT, TREASURE, SHOP, EVENT, REWARD, DEAD, VICTORY }

# 当前状态
var current_state: int = State.TITLE

# 玩家基础状态
var region: int = 0
var cycle: int = 0             # 无限周目：通关 5 区后 +1，怪物与装备数值同步增强
var gold: int = 0
var potions: int = 0
var hp: int = 50
var max_hp: int = 50
var energy: int = 10
var max_energy: int = 10
var region_buff: float = 0.0
var bonus_max_hp: int = 0      # 事件带来的永久生命加成（本局有效）

# 熔炼词条精华：[{affix, from}]，锻打可赋予其他装备
var essences: Array = []

# 角色：名字 + 开局天赋点（每档存档独立）
var hero_name: String = "冒险者"
var talents: Dictionary = { "vit": 0, "str": 0, "tough": 0, "agi": 0 }

# 天赋词条（击败区域首领后三选一，永久生效）
var perks: Array = []

# 已播放过的剧情 CG（每存档独立；终局 CG 每周目都播）
var seen_cgs: Array = []
var _cg_pending_node = null      # CG 播放后待进入的节点（区域 5 首领战前 CG）
var _cg_skip_once: bool = false  # 防止 CG 后再次触发同一 CG

# 装备（武器 / 铠甲 / 头盔 / 裤子 / 鞋 / 配饰）
var equipment = {
	"weapon": null,
	"armor": null,
	"helmet": null,
	"pants": null,
	"boots": null,
	"accessory": null,
}

# 背包
var bag: Array = []

# 地图
var current_map: Dictionary = {}
var current_node_idx: int = -1
var hero_pos: int = -1          # 小人当前所站节点 id；-1 = 起点（地图下方）

# 战斗
var combat_state: Dictionary = {}

# 本局统计
var run_stats: Dictionary = {}

# 事件去重（最近出现过的事件 key）
var recent_events: Array = []

# ---- 存档 ----
const SLOT_COUNT := 3
const LEGACY_SAVE_PATH := "user://pixel_pathfinder_save.json"
const SETTINGS_PATH := "user://settings.json"
var save_slot: int = 0

# 商店缓存
var shop_stock: Array = []
var potion_price: int = 30

# 掉落缓存
var pending_drop = null
var pending_boss: bool = false

# 当前视图
var current_view: String = "title"

# ============================================================
# 生命周期
# ============================================================
func _ready():
	randomize()
	_load_settings()
	_migrate_legacy_save()
	SignalBus.cg_finished.connect(_on_cg_finished)
	print("[GameState] 初始化完成，当前存档位: %d" % (save_slot + 1))

# ============================================================
# 剧情 CG 流程
# ============================================================
func _cg_seen(key: String) -> bool:
	return seen_cgs.has(key)

func _mark_cg(key: String) -> void:
	if not seen_cgs.has(key):
		seen_cgs.append(key)

func _on_cg_finished(tag: String) -> void:
	match tag:
		"region_clear":
			_region_clear_after_cg()
		"pre_boss":
			if _cg_pending_node != null:
				var node = _cg_pending_node
				_cg_pending_node = null
				_cg_skip_once = true
				enter_node(node)
		_:
			pass

## 关闭窗口时自动保存（地图状态下覆盖保存；其它状态保留进节点前的快照）
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if current_state == State.MAP:
			save_game()

# ============================================================
# 状态切换
# ============================================================
func change_state(new_state: int) -> void:
	current_state = new_state
	var state_name = _state_to_string(new_state)
	SignalBus.state_changed.emit(state_name)

func _state_to_string(s: int) -> String:
	match s:
		State.TITLE:    return "title"
		State.MAP:      return "map"
		State.COMBAT:   return "combat"
		State.TREASURE: return "treasure"
		State.SHOP:     return "shop"
		State.EVENT:    return "event"
		State.REWARD:   return "reward"
		State.DEAD:     return "dead"
		State.VICTORY:  return "victory"
		_:              return "unknown"

# ============================================================
# 游戏流程
# ============================================================
func reset_run_stats() -> void:
	run_stats = {
		"kills": 0, "elite_kills": 0, "boss_kills": 0,
		"dmg_dealt": 0, "dmg_taken": 0, "gold_earned": 0,
		"turns": 0, "nodes_visited": 0, "items_looted": 0,
	}

## 开始新远征。所有区域均已开放，可从任意区域出发（推荐 1→5）
## new_name: 角色名；new_talents: 开局天赋点分配 {vit/str/tough/agi}
func start_new_game(start_region: int = 0, new_name: String = "", new_talents: Dictionary = {}) -> void:
	reset_run_stats()
	clear_save()
	region = clampi(start_region, 0, GameData.BIOMES.size() - 1)
	cycle = 0
	gold = GameData.PLAYER_BASE["start_gold"]
	potions = GameData.PLAYER_BASE["start_potions"]
	region_buff = 0.0
	bonus_max_hp = 0
	recent_events.clear()
	essences.clear()
	perks.clear()
	seen_cgs.clear()
	bag.clear()

	# 角色名与天赋
	hero_name = new_name.strip_edges()
	if hero_name == "":
		hero_name = "冒险者"
	talents = { "vit": 0, "str": 0, "tough": 0, "agi": 0 }
	for k in GameData.TALENT_KEYS:
		talents[k] = maxi(0, int(new_talents.get(k, 0)))

	# 初始装备
	var sword = EquipmentFactory.create_starter_weapon()
	var armor = EquipmentFactory.create_starter_armor()
	for slot in GameData.EQUIP_SLOTS:
		equipment[slot] = null
	equipment["weapon"] = sword
	equipment["armor"] = armor

	# 计算最大生命
	_recalc_stats()
	hp = max_hp
	energy = max_energy

	SignalBus.gold_changed.emit(gold)
	SignalBus.potion_changed.emit(potions)
	SignalBus.equipment_changed.emit("weapon", sword)
	SignalBus.equipment_changed.emit("armor", armor)

	print("[GameState] 新游戏开始 (区域 %d)" % (region + 1))
	start_region(region)

func start_region(r: int) -> void:
	region = r
	current_node_idx = -1
	hero_pos = -1
	current_map = MapGenerator.generate_map(r, cycle)
	change_state(State.MAP)
	_recalc_stats()
	hp = min(hp, max_hp)
	SignalBus.region_changed.emit(r)
	SignalBus.view_changed.emit("map")
	save_game()
	# 区域进入 CG（每存档每区域一次，地图就绪后叠加播放）
	var cg_key = "enter_%d" % r
	if r < GameData.CG_REGION_ENTER.size() and not _cg_seen(cg_key):
		_mark_cg(cg_key)
		save_game()
		SignalBus.play_cg.emit([GameData.CG_REGION_ENTER[r]], "enter")

## 远征途中切换区域（全地图开放 · 测试模式）
func switch_region(r: int) -> void:
	if current_state != State.MAP:
		SignalBus.show_toast.emit("只能在地图界面切换区域")
		return
	if r == region:
		SignalBus.show_toast.emit("已在该区域")
		return
	region_buff = 0.0
	start_region(r)
	SignalBus.show_toast.emit("传送至 %s" % GameData.get_biome(r).name)

# ============================================================
# 属性计算
# ============================================================
func _recalc_stats() -> void:
	var stats = EquipmentModifier.calculate_total_stats(equipment)
	max_hp = GameData.PLAYER_BASE["max_hp"] + stats.hp + bonus_max_hp
	max_energy = GameData.PLAYER_BASE["max_energy"]
	_cached_stats = stats

var _cached_stats: Dictionary = {}

func get_player_stats() -> Dictionary:
	_recalc_stats()
	return _cached_stats.duplicate(true)

# ============================================================
# 装备操作
# ============================================================
func equip_item(item: Dictionary, from_drop: bool = false) -> void:
	var slot = item.get("slot", "weapon")
	var old = equipment[slot]
	equipment[slot] = item

	# 从背包移除
	var idx = bag.find(item)
	if idx >= 0:
		bag.remove_at(idx)

	# 旧装备处理
	if old:
		if bag.size() < GameData.PLAYER_BASE["bag_capacity"]:
			bag.append(old)
			SignalBus.show_toast.emit("旧装备已放入背包")
		else:
			var sell_val = EquipmentModifier.get_sell_value(old)
			gold += sell_val
			SignalBus.gold_changed.emit(gold)
			SignalBus.show_toast.emit("背包已满 — 旧装备已出售 (%d 金币)" % sell_val)

	_recalc_stats()
	hp = min(hp, max_hp)
	SignalBus.equipment_changed.emit(slot, item)
	SignalBus.bag_changed.emit(bag.duplicate())
	SignalBus.hp_changed.emit(hp, max_hp)
	save_game()

func upgrade_equipped(slot: String) -> bool:
	var it = equipment[slot]
	if not it or it.level >= GameData.COMBAT["max_upgrade_level"]:
		return false
	var cost = EquipmentModifier.get_upgrade_cost(it, region)
	if gold < cost:
		return false

	gold -= cost
	it.level += 1
	it["invested"] = int(it.get("invested", 0)) + cost

	if it.level == 3:
		SignalBus.show_toast.emit("★ 被动技能已解锁！")
	elif it.level == 5:
		SignalBus.show_toast.emit("✦ 独特效果已解锁！")

	_recalc_stats()
	SignalBus.gold_changed.emit(gold)
	SignalBus.equipment_changed.emit(slot, it)
	save_game()
	return true

func upgrade_bag_item(index: int) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var it = bag[index]
	if it.level >= GameData.COMBAT["max_upgrade_level"]:
		return false
	var cost = EquipmentModifier.get_upgrade_cost(it, region)
	if gold < cost:
		return false

	gold -= cost
	it.level += 1
	it["invested"] = int(it.get("invested", 0)) + cost

	if it.level == 3:
		SignalBus.show_toast.emit("★ 被动技能已解锁！")
	elif it.level == 5:
		SignalBus.show_toast.emit("✦ 独特效果已解锁！")

	SignalBus.gold_changed.emit(gold)
	SignalBus.bag_changed.emit(bag.duplicate())
	save_game()
	return true

func sell_bag_item(index: int) -> void:
	if index < 0 or index >= bag.size():
		return
	var it = bag[index]
	var val = EquipmentModifier.get_sell_value(it)
	gold += val
	bag.remove_at(index)
	SignalBus.gold_changed.emit(gold)
	SignalBus.bag_changed.emit(bag.duplicate())
	SignalBus.show_toast.emit("已出售，获得 %d 金币" % val)
	save_game()

# ============================================================
# 熔炼与锻打
# 熔炼：销毁背包中史诗+装备，自选萃取其一条词条为「词条精华」
# 锻打：花费金币把精华赋予任意装备（单件词条上限 4，不可重复）
# ============================================================
func get_forge_cost() -> int:
	return GameData.COMBAT["forge_cost_base"] + region * GameData.COMBAT["forge_cost_region"]

func can_smelt(item: Dictionary) -> bool:
	return int(item.get("rarity", 0)) >= GameData.Rarity.EPIC and item.get("affixes", []).size() > 0

func smelt_bag_item(index: int, affix_key: String) -> bool:
	if index < 0 or index >= bag.size():
		return false
	var it = bag[index]
	if not can_smelt(it) or not it.affixes.has(affix_key):
		return false
	if essences.size() >= GameData.COMBAT["essence_cap"]:
		SignalBus.show_toast.emit("精华袋已满（%d/%d）" % [essences.size(), GameData.COMBAT["essence_cap"]])
		return false
	essences.append({ "affix": affix_key, "from": str(it.get("name", it.base_name)) })
	bag.remove_at(index)
	var ad = GameData.AFFIXES.get(affix_key, {})
	SignalBus.bag_changed.emit(bag.duplicate())
	SignalBus.show_toast.emit("熔炼完成：萃取出「%s」词条精华" % ad.get("name", affix_key))
	Sfx.play("upgrade")
	save_game()
	return true

## 词条当前强化等级（默认 1）
static func affix_level_of(item: Dictionary, key: String) -> int:
	if not item.get("affixes", []).has(key):
		return 0
	var lvs = item.get("affix_lv", {})
	return maxi(1, int(lvs.get(key, 1))) if lvs is Dictionary else 1

## 该词条能否锻打到目标装备上：新词条需有空位；同词条可强化（开关型除外，上限 Lv.3）
## 返回 {"ok": bool, "why": String, "to_lv": int}
func can_forge_to(item: Dictionary, affix_key: String) -> Dictionary:
	if item.affixes.has(affix_key):
		if GameData.NON_STACK_AFFIXES.has(affix_key):
			return { "ok": false, "why": "开关型词条无法强化", "to_lv": 0 }
		var lv = affix_level_of(item, affix_key)
		if lv >= GameData.AFFIX_MAX_LEVEL:
			return { "ok": false, "why": "该词条已达最高 Lv.%d" % GameData.AFFIX_MAX_LEVEL, "to_lv": 0 }
		return { "ok": true, "why": "", "to_lv": lv + 1 }
	if item.affixes.size() >= GameData.COMBAT["max_affix_total"]:
		return { "ok": false, "why": "词条已达上限（%d 条）" % GameData.COMBAT["max_affix_total"], "to_lv": 0 }
	return { "ok": true, "why": "", "to_lv": 1 }

## target: {"kind":"equip","slot":...} 或 {"kind":"bag","index":...}
## 同词条锻打 → 词条强化（连击 Lv.2 = 连击数 +2，数值词条 ×等级）
func forge_essence(essence_idx: int, target: Dictionary) -> bool:
	if essence_idx < 0 or essence_idx >= essences.size():
		return false
	var es = essences[essence_idx]
	var it = null
	if target.get("kind", "") == "equip":
		it = equipment.get(str(target.get("slot", "")))
	elif target.get("kind", "") == "bag":
		var bi = int(target.get("index", -1))
		if bi >= 0 and bi < bag.size():
			it = bag[bi]
	if it == null:
		return false
	var chk = can_forge_to(it, str(es.affix))
	if not chk.ok:
		SignalBus.show_toast.emit(str(chk.why))
		return false
	var cost = get_forge_cost()
	if gold < cost:
		SignalBus.show_toast.emit("金币不足（需要 %d）" % cost)
		return false
	gold -= cost
	if not (it.get("affix_lv") is Dictionary):
		it["affix_lv"] = {}
	var ad = GameData.AFFIXES.get(es.affix, {})
	if it.affixes.has(es.affix):
		it.affix_lv[es.affix] = int(chk.to_lv)
		SignalBus.show_toast.emit("词条强化：「%s」提升至 Lv.%d — %s" % [ad.get("name", es.affix), int(chk.to_lv), GameData.affix_desc(str(es.affix), int(chk.to_lv))])
	else:
		it.affixes.append(es.affix)
		it.affix_lv[es.affix] = 1
		SignalBus.show_toast.emit("锻打成功：「%s」已附着到 %s" % [ad.get("name", es.affix), it.get("name", "装备")])
	essences.remove_at(essence_idx)
	_recalc_stats()
	SignalBus.gold_changed.emit(gold)
	SignalBus.bag_changed.emit(bag.duplicate())
	SignalBus.equipment_changed.emit(str(it.get("slot", "weapon")), it)
	Sfx.play("upgrade")
	save_game()
	return true

# ============================================================
# 背包操作
# ============================================================
func add_to_bag(item: Dictionary) -> bool:
	if bag.size() >= GameData.PLAYER_BASE["bag_capacity"]:
		return false
	bag.append(item)
	SignalBus.bag_changed.emit(bag.duplicate())
	return true

## 整理背包：按槽位 → 稀有度 → 品级 → 强化等级排序
func sort_bag() -> void:
	var slot_order = { "weapon": 0, "armor": 1, "helmet": 2, "pants": 3, "boots": 4, "accessory": 5 }
	bag.sort_custom(func(a, b):
		var sa: int = slot_order.get(str(a.get("slot", "")), 9)
		var sb: int = slot_order.get(str(b.get("slot", "")), 9)
		if sa != sb:
			return sa < sb
		if int(a.rarity) != int(b.rarity):
			return int(a.rarity) > int(b.rarity)
		if int(a.get("grade", 1)) != int(b.get("grade", 1)):
			return int(a.get("grade", 1)) > int(b.get("grade", 1))
		return int(a.level) > int(b.level)
	)
	SignalBus.bag_changed.emit(bag.duplicate())
	save_game()

# ============================================================
# 药水操作
# ============================================================
## 饮用药水；bonus_pct 为药理词条加成，返回实际恢复量
func use_potion(bonus_pct: float = 0.0) -> int:
	if potions <= 0:
		return 0
	var heal_amount = roundi(max_hp * GameData.COMBAT["potion_heal_pct"] * (1.0 + bonus_pct / 100.0))
	heal_amount = mini(heal_amount, max_hp - hp)
	hp = min(hp + heal_amount, max_hp)
	potions -= 1
	SignalBus.hp_changed.emit(hp, max_hp)
	SignalBus.potion_changed.emit(potions)
	return heal_amount

func buy_potion() -> bool:
	if gold < potion_price or potions >= GameData.PLAYER_BASE["max_potions"]:
		return false
	gold -= potion_price
	potions += 1
	SignalBus.gold_changed.emit(gold)
	SignalBus.potion_changed.emit(potions)
	return true

# ============================================================
# 金币操作
# ============================================================
func add_gold(amount: int) -> void:
	gold += amount
	SignalBus.gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	SignalBus.gold_changed.emit(gold)
	return true

# ============================================================
# 战斗入口（foes 为节点预掷的怪物构成 → 预览即实战）
# ============================================================
func enter_combat(elite: bool = false, boss: bool = false, foes: Array = []) -> void:
	change_state(State.COMBAT)
	combat_state = CombatManager.setup_combat(region, cycle, elite, boss, foes)
	SignalBus.combat_started.emit(combat_state.enemies)
	SignalBus.view_changed.emit("combat")

# ============================================================
# 节点进入
# 已结束的战斗/宝箱/事件不可再进（可作通路经过）；商店可重复进入
# ============================================================
func can_enter_node(node_data: Dictionary) -> bool:
	if node_data.type == GameData.NodeType.SHOP:
		return true
	return not bool(node_data.get("visited", false))

func enter_node(node_data: Dictionary) -> void:
	if not can_enter_node(node_data):
		SignalBus.show_toast.emit("这里已经探索过了")
		return
	# 区域 5 首领战前 CG（每存档一次），播完再进入战斗
	if node_data.type == GameData.NodeType.BOSS and region == GameData.BIOMES.size() - 1 \
			and not _cg_skip_once and not _cg_seen("pre_finalboss"):
		_mark_cg("pre_finalboss")
		_cg_pending_node = node_data
		save_game()
		SignalBus.play_cg.emit([GameData.CG_PRE_FINAL_BOSS], "pre_boss")
		return
	_cg_skip_once = false
	# 进入节点前快照存档：无论何时退出游戏，都能从此处继续
	hero_pos = node_data.id
	save_game()

	current_node_idx = node_data.id
	if not bool(node_data.get("visited", false)):
		run_stats.nodes_visited += 1
	node_data.visited = true

	var foes: Array = node_data.get("foes", [])
	match node_data.type:
		GameData.NodeType.BATTLE:
			enter_combat(false, false, foes)
		GameData.NodeType.ELITE:
			enter_combat(true, false, foes)
		GameData.NodeType.BOSS:
			enter_combat(false, true, foes)
		GameData.NodeType.TREASURE:
			open_treasure()
		GameData.NodeType.SHOP:
			open_shop()
		GameData.NodeType.EVENT:
			open_event()

func open_treasure() -> void:
	change_state(State.TREASURE)
	var result = {}
	if randf() < 0.6:
		var item = EquipmentFactory.generate_item(region, "", -1, "chest")
		result["type"] = "item"
		result["item"] = item
		pending_drop = item
	else:
		var g = randi_range(25, 45) + region * 15
		gold += g
		result["type"] = "gold"
		result["gold"] = g
		SignalBus.gold_changed.emit(gold)
		pending_drop = null
	SignalBus.show_modal.emit("treasure", result)

func open_shop() -> void:
	change_state(State.SHOP)
	var stats = get_player_stats()
	var disc = 1.0 - stats.discount / 100.0
	shop_stock.clear()
	# 9 件随机商品：六个槽位各 1，再补 3 件随机（商店可重复进入，每次进货）
	var slots = GameData.EQUIP_SLOTS.duplicate()
	slots.append_array(["", "", ""])
	for i in range(slots.size()):
		var it = EquipmentFactory.generate_item(region, slots[i], -1, "shop")
		it["price"] = roundi(it.value * 1.6 * disc / 5.0) * 5
		shop_stock.append(it)
	potion_price = roundi(30 * (1 + region * 0.2) * disc / 5.0) * 5
	SignalBus.show_modal.emit("shop", { "stock": shop_stock, "potion_price": potion_price })

# ============================================================
# 随机事件（从事件池抽取，避免与最近事件重复）
# ============================================================
func open_event() -> void:
	change_state(State.EVENT)
	var pool = []
	for ev in GameData.EVENT_POOL:
		if not recent_events.has(ev.key):
			pool.append(ev)
	if pool.is_empty():
		pool = GameData.EVENT_POOL.duplicate()

	var ev = pool[randi() % pool.size()]
	recent_events.append(ev.key)
	while recent_events.size() > 8:
		recent_events.pop_front()

	SignalBus.show_modal.emit("event", ev.duplicate(true))

## 解析选项花费：cost_gold = [基础, 区域加成]
func get_event_choice_cost(choice: Dictionary) -> int:
	if not choice.has("cost_gold"):
		return 0
	var cg = choice.cost_gold
	return int(cg[0]) + region * int(cg[1])

## 处理事件选择（通用效果引擎）
func handle_event_choice(event_key: String, choice_idx: int) -> void:
	var ev = GameData.get_event(event_key)
	if choice_idx < 0 or choice_idx >= ev.choices.size():
		back_to_map()
		return
	var choice = ev.choices[choice_idx]

	# 花费校验
	var cost = get_event_choice_cost(choice)
	if cost > 0:
		if gold < cost:
			SignalBus.show_toast.emit("金币不足")
			back_to_map()
			return
		gold -= cost
		SignalBus.gold_changed.emit(gold)
	if int(choice.get("require_potion", 0)) > potions:
		SignalBus.show_toast.emit("药水不足")
		back_to_map()
		return

	var terminal = _apply_event_effects(choice.get("effects", []))
	if not terminal:
		back_to_map()

## 应用效果数组；返回 true 表示已进入战斗/奖励等终态（无需回地图）
func _apply_event_effects(effects: Array) -> bool:
	var terminal = false
	for fx in effects:
		match fx.get("type", ""):
			"gold":
				var g = int(fx.get("base", 0)) + region * int(fx.get("region_mult", 0))
				add_gold(g)
				SignalBus.show_toast.emit("获得 %d 金币" % g)
			"gold_flat":
				var g2 = int(fx.get("amount", 0))
				add_gold(g2)
				SignalBus.show_toast.emit("获得 %d 金币" % g2)
			"hp_pct":
				var pct = float(fx.get("pct", 0.0))
				if pct >= 0:
					var heal = roundi(max_hp * pct)
					hp = mini(hp + heal, max_hp)
					SignalBus.show_toast.emit("恢复了 %d 点生命" % heal)
					Sfx.play("heal")
				else:
					var loss = roundi(max_hp * -pct)
					hp = maxi(1, hp - loss)
					SignalBus.show_toast.emit("失去了 %d 点生命" % loss)
					Sfx.play("hurt")
				SignalBus.hp_changed.emit(hp, max_hp)
			"full_heal":
				hp = max_hp
				SignalBus.hp_changed.emit(hp, max_hp)
				SignalBus.show_toast.emit("生命完全恢复！")
				Sfx.play("heal")
			"max_hp":
				bonus_max_hp += int(fx.get("amount", 0))
				_recalc_stats()
				hp = mini(hp + int(fx.get("amount", 0)), max_hp)
				SignalBus.hp_changed.emit(hp, max_hp)
				SignalBus.show_toast.emit("最大生命 +%d！" % int(fx.get("amount", 0)))
				Sfx.play("upgrade")
			"potion":
				var c = int(fx.get("count", 0))
				potions = clampi(potions + c, 0, GameData.PLAYER_BASE["max_potions"])
				SignalBus.potion_changed.emit(potions)
				if c > 0:
					SignalBus.show_toast.emit("获得 %d 瓶药水" % c)
					Sfx.play("heal")
			"item":
				var item = EquipmentFactory.generate_item(region, "", int(fx.get("boost", 0)))
				pending_drop = item
				SignalBus.show_modal.emit("reward", { "item": item, "source": "event" })
				terminal = true
			"atk_buff":
				region_buff += float(fx.get("pct", 0.0))
				_recalc_stats()
				SignalBus.show_toast.emit("本区域攻击力 +%d%%" % roundi(float(fx.get("pct", 0.0)) * 100))
				Sfx.play("skill")
			"upgrade_weapon":
				var w = equipment.get("weapon")
				if w and w.level < GameData.COMBAT["max_upgrade_level"]:
					w.level += 1
					_recalc_stats()
					SignalBus.equipment_changed.emit("weapon", w)
					SignalBus.show_toast.emit("武器免费强化至 +%d！" % w.level)
					Sfx.play("upgrade")
					if w.level == 3:
						SignalBus.show_toast.emit("★ 被动技能已解锁！")
					elif w.level == 5:
						SignalBus.show_toast.emit("✦ 独特效果已解锁！")
				else:
					SignalBus.show_toast.emit("武器已满级，铁匠耸了耸肩")
			"fight":
				SignalBus.show_toast.emit("战斗开始！")
				enter_combat(bool(fx.get("elite", false)), false)
				terminal = true
			"toast":
				SignalBus.show_toast.emit(str(fx.get("text", "")))
			"random":
				var opts: Array = fx.get("options", [])
				var total = 0.0
				for o in opts:
					total += float(o.get("weight", 1.0))
				var r = randf() * total
				var acc = 0.0
				for o in opts:
					acc += float(o.get("weight", 1.0))
					if r <= acc:
						if o.has("text"):
							SignalBus.show_toast.emit(str(o.text))
						if _apply_event_effects(o.get("effects", [])):
							terminal = true
						break
	return terminal

# ============================================================
# 掉落处理
# ============================================================
func handle_drop(choice: String) -> void:
	if not pending_drop:
		close_reward()
		return

	match choice:
		"equip":
			equip_item(pending_drop, true)
		"bag":
			if bag.size() < GameData.PLAYER_BASE["bag_capacity"]:
				bag.append(pending_drop)
				SignalBus.show_toast.emit("已放入背包")
				SignalBus.bag_changed.emit(bag.duplicate())
		"sell":
			var val = EquipmentModifier.get_sell_value(pending_drop)
			gold += val
			SignalBus.gold_changed.emit(gold)
			SignalBus.show_toast.emit("已出售，获得 %d 金币" % val)

	pending_drop = null
	if pending_boss:
		pending_boss = false
		region_clear()
	else:
		close_reward()

func close_reward() -> void:
	if pending_boss:
		pending_boss = false
		region_clear()
	else:
		back_to_map()

# ============================================================
# 区域/游戏结算（无限周目：通关 5 区进入强化周目，存档保留）
# 通关区域 2 / 区域 5（含周目循环）→ 三选一天赋词条 → 再进入区域结算
# 词条上限 5 条，超出需选择替换
# ============================================================
func roll_perk_offers(n: int = 3) -> Array:
	var pool = []
	for k in GameData.PERK_KEYS:
		if not perks.has(k):
			pool.append(k)
	pool.shuffle()
	return pool.slice(0, mini(n, pool.size()))

func choose_perk(key: String) -> void:
	if key == "" or not GameData.PERKS.has(key) or perks.has(key):
		_region_clear_continue()
		return
	# 已达上限 → 进入替换选择
	if perks.size() >= GameData.PERK_CAP:
		SignalBus.show_modal.emit("perk_replace", { "new": key })
		return
	perks.append(key)
	var pd = GameData.get_perk(key)
	_recalc_stats()
	SignalBus.show_toast.emit("获得天赋词条「%s」：%s" % [pd.name, pd.desc])
	Sfx.play("upgrade")
	_region_clear_continue()

## 用新词条替换一条已有词条（上限 5 时）
func replace_perk(old_key: String, new_key: String) -> void:
	if perks.has(old_key) and GameData.PERKS.has(new_key) and not perks.has(new_key):
		perks.erase(old_key)
		perks.append(new_key)
		_recalc_stats()
		hp = mini(hp, max_hp)
		SignalBus.hp_changed.emit(hp, max_hp)
		var od = GameData.get_perk(old_key)
		var nd = GameData.get_perk(new_key)
		SignalBus.show_toast.emit("「%s」替换为「%s」" % [od.name, nd.name])
		Sfx.play("upgrade")
	_region_clear_continue()

## 放弃本次天赋选择
func skip_perk() -> void:
	_region_clear_continue()

func region_clear() -> void:
	region_buff = 0.0
	# 首领战后 CG：区域 1-4 每存档各一次；最终区域播终局三连 CG（每周目轮回都播）
	var cgs: Array = []
	if region < GameData.CG_REGION_CLEAR.size():
		var key = "clear_%d" % region
		if not _cg_seen(key):
			_mark_cg(key)
			cgs = [GameData.CG_REGION_CLEAR[region]]
	elif region == GameData.BIOMES.size() - 1:
		cgs = GameData.CG_FINALE.duplicate()
	if cgs.size() > 0:
		SignalBus.play_cg.emit(cgs, "region_clear")
		return
	_region_clear_after_cg()

## CG 播完后的区域结算：里程碑区域（区域 2 / 区域 5）先天赋三选一
func _region_clear_after_cg() -> void:
	if not (region in GameData.PERK_MILESTONE_REGIONS):
		_region_clear_continue()
		return
	var offers = roll_perk_offers(3)
	if offers.is_empty():
		_region_clear_continue()
	else:
		SignalBus.show_modal.emit("perk_choice", { "offers": offers })

func _region_clear_continue() -> void:
	if region >= GameData.BIOMES.size() - 1:
		# 整轮通关 → 进入下一个强化周目
		var cleared_cycle = cycle
		var bonus = 200 + cycle * 120
		gold += bonus
		cycle += 1
		SignalBus.gold_changed.emit(gold)
		SignalBus.game_victory.emit()
		# 先把新周目第 1 区准备好并保存：此刻退出也不丢进度
		start_region(0)
		SignalBus.show_modal.emit("victory", {
			"gold": gold, "bonus": bonus, "cycle": cleared_cycle,
			"stats": run_stats.duplicate(),
		})
	else:
		var bonus = (60 + region * 40) * (1 + cycle)
		gold += bonus
		hp = max_hp
		SignalBus.gold_changed.emit(gold)
		SignalBus.hp_changed.emit(hp, max_hp)
		SignalBus.region_cleared.emit(region)
		SignalBus.show_modal.emit("region_clear", {
			"region": region,
			"bonus": bonus,
			"next_region": region + 1
		})

func next_region() -> void:
	start_region(region + 1)

func player_defeated() -> void:
	change_state(State.DEAD)
	var lost = floori(gold / 2.0)
	gold -= lost
	SignalBus.gold_changed.emit(gold)
	# 预写一份"重整旗鼓"状态的存档：此刻退出游戏也能从区域起点继续
	_recalc_stats()
	hp = max_hp
	region_buff = 0.0
	current_node_idx = -1
	hero_pos = -1
	current_map = MapGenerator.generate_map(region, cycle)
	save_game(true)
	SignalBus.show_modal.emit("defeat", { "region": region, "lost_gold": lost, "stats": run_stats.duplicate() })

func retry_region() -> void:
	_recalc_stats()
	hp = max_hp
	region_buff = 0.0
	start_region(region)

func back_to_map() -> void:
	change_state(State.MAP)
	save_game()
	SignalBus.view_changed.emit("map")

# ============================================================
# 购买
# ============================================================
func buy_shop_item(index: int) -> bool:
	if index < 0 or index >= shop_stock.size():
		return false
	var it = shop_stock[index]
	if gold < it.price or bag.size() >= GameData.PLAYER_BASE["bag_capacity"]:
		return false
	gold -= it.price
	bag.append(it)
	shop_stock.remove_at(index)
	SignalBus.gold_changed.emit(gold)
	SignalBus.bag_changed.emit(bag.duplicate())
	SignalBus.show_toast.emit("购买了 %s" % it.base_name)
	return true

# ============================================================
# 地图访问（路线制：小人沿连线移动，站上节点后选择是否进入）
# - 已结束的战斗可经过但不可再进；商店可重复进入
# ============================================================
func get_node_by_id(id: int):
	for n in current_map.get("nodes", []):
		if int(n.id) == id:
			return n
	return null

## 与小人当前位置相邻（有连线）的节点 id；起点(-1) → 最下排全部
func get_adjacent_ids(pos: int = -2) -> Array:
	if pos == -2:
		pos = hero_pos
	var nodes: Array = current_map.get("nodes", [])
	var out = []
	if pos < 0:
		for n in nodes:
			if int(n.row) == 0:
				out.append(int(n.id))
		return out
	var cur = get_node_by_id(pos)
	if cur == null:
		return out
	for nx in cur.next:
		out.append(int(nx))
	# 反向边：可折返去探索另一条路径
	for n in nodes:
		for nx in n.next:
			if int(nx) == pos and not out.has(int(n.id)):
				out.append(int(n.id))
	# 保险：节点意外没有任何连线（异常存档）→ 相邻排全部可走，绝不卡死
	if out.is_empty():
		for n in nodes:
			if absi(int(n.row) - int(cur.row)) == 1:
				out.append(int(n.id))
	return out

## 移动小人到相邻节点（只是站上去/经过，不触发节点内容）
func move_hero(node_id: int) -> bool:
	if current_state != State.MAP:
		return false
	if not get_adjacent_ids().has(node_id):
		return false
	hero_pos = node_id
	save_game()
	return true

## 兼容旧接口：当前可移动到的相邻节点
func get_reachable_nodes() -> Array:
	if current_state != State.MAP:
		return []
	var ids = get_adjacent_ids()
	var out = []
	for n in current_map.get("nodes", []):
		if ids.has(int(n.id)):
			out.append(n)
	return out

# ============================================================
# 设置（当前存档位等）
# ============================================================
func _load_settings() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not f:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		save_slot = clampi(int(parsed.get("save_slot", 0)), 0, SLOT_COUNT - 1)

func _save_settings() -> void:
	var f = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({ "save_slot": save_slot }))
		f.close()

func set_active_slot(i: int) -> void:
	save_slot = clampi(i, 0, SLOT_COUNT - 1)
	_save_settings()

## 旧版单存档迁移到存档位 1
func _migrate_legacy_save() -> void:
	if FileAccess.file_exists(LEGACY_SAVE_PATH) and not FileAccess.file_exists(_slot_path(0)):
		var f = FileAccess.open(LEGACY_SAVE_PATH, FileAccess.READ)
		if f:
			var txt = f.get_as_text()
			f.close()
			var out = FileAccess.open(_slot_path(0), FileAccess.WRITE)
			if out:
				out.store_string(txt)
				out.close()
		DirAccess.remove_absolute(LEGACY_SAVE_PATH)

# ============================================================
# 存档系统（多存档位）
# ============================================================
func _slot_path(i: int) -> String:
	return "user://save_slot_%d.json" % i

func has_save(slot: int = -1) -> bool:
	if slot < 0:
		slot = save_slot
	return FileAccess.file_exists(_slot_path(slot))

func clear_save(slot: int = -1) -> void:
	if slot < 0:
		slot = save_slot
	if FileAccess.file_exists(_slot_path(slot)):
		DirAccess.remove_absolute(_slot_path(slot))

## 读取存档位摘要（供存档界面显示）
func get_slot_info(slot: int) -> Dictionary:
	if not has_save(slot):
		return {}
	var f = FileAccess.open(_slot_path(slot), FileAccess.READ)
	if not f:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var stats = parsed.get("run_stats", {})
	return {
		"region": int(parsed.get("region", 0)),
		"cycle": int(parsed.get("cycle", 0)),
		"gold": int(parsed.get("gold", 0)),
		"hp": int(parsed.get("hp", 0)),
		"kills": int(stats.get("kills", 0)) if stats is Dictionary else 0,
		"hero_name": str(parsed.get("hero_name", "冒险者")),
		"timestamp": str(parsed.get("timestamp", "")),
	}

func save_game(force: bool = false) -> void:
	if current_state == State.VICTORY:
		return
	# 非地图状态只允许强制保存（避免覆盖"进节点前"的快照）
	if not force and not (current_state in [State.MAP, State.TITLE]):
		return
	var data = {
		"version": 5,
		"timestamp": Time.get_datetime_string_from_system(false, true),
		"region": region,
		"cycle": cycle,
		"gold": gold,
		"potions": potions,
		"hp": hp,
		"region_buff": region_buff,
		"bonus_max_hp": bonus_max_hp,
		"recent_events": recent_events,
		"essences": essences,
		"hero_name": hero_name,
		"talents": talents,
		"perks": perks,
		"seen_cgs": seen_cgs,
		"equipment": equipment,
		"bag": bag,
		"map_nodes": current_map.get("nodes", []),
		"current_node_idx": current_node_idx,
		"hero_pos": hero_pos,
		"run_stats": run_stats,
	}
	var f = FileAccess.open(_slot_path(save_slot), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game(slot: int = -1) -> bool:
	if slot >= 0:
		set_active_slot(slot)
	if not has_save():
		return false
	var f = FileAccess.open(_slot_path(save_slot), FileAccess.READ)
	if not f:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	region = int(parsed.get("region", 0))
	cycle = int(parsed.get("cycle", 0))
	gold = int(parsed.get("gold", 0))
	potions = int(parsed.get("potions", 0))
	region_buff = float(parsed.get("region_buff", 0.0))
	bonus_max_hp = int(parsed.get("bonus_max_hp", 0))
	current_node_idx = int(parsed.get("current_node_idx", -1))
	hero_pos = int(parsed.get("hero_pos", -1))
	run_stats = _coerce_int_dict(parsed.get("run_stats", {}))
	if run_stats.is_empty():
		reset_run_stats()
	recent_events.clear()
	for k in parsed.get("recent_events", []):
		recent_events.append(str(k))
	essences.clear()
	for es in parsed.get("essences", []):
		if es is Dictionary and es.has("affix"):
			essences.append({ "affix": str(es.affix), "from": str(es.get("from", "")) })

	# 角色名 / 天赋 / 天赋词条（v5；旧档默认值）
	hero_name = str(parsed.get("hero_name", "冒险者"))
	if hero_name.strip_edges() == "":
		hero_name = "冒险者"
	talents = { "vit": 0, "str": 0, "tough": 0, "agi": 0 }
	var tl = parsed.get("talents", {})
	if tl is Dictionary:
		for k in GameData.TALENT_KEYS:
			talents[k] = maxi(0, int(tl.get(k, 0)))
	perks.clear()
	for p in parsed.get("perks", []):
		if GameData.PERKS.has(str(p)) and not perks.has(str(p)):
			perks.append(str(p))
	seen_cgs.clear()
	for k in parsed.get("seen_cgs", []):
		seen_cgs.append(str(k))

	equipment = {}
	for slot_name in GameData.EQUIP_SLOTS:
		equipment[slot_name] = null
	var eq = parsed.get("equipment", {})
	for slot_name in GameData.EQUIP_SLOTS:
		var it = eq.get(slot_name)
		if it is Dictionary:
			equipment[slot_name] = _restore_item(it)

	bag.clear()
	for it in parsed.get("bag", []):
		if it is Dictionary:
			bag.append(_restore_item(it))

	# 重建地图（节点 + 行结构，共享引用）
	var nodes = []
	for n in parsed.get("map_nodes", []):
		if n is Dictionary:
			var node = {
				"id": int(n.get("id", 0)),
				"row": int(n.get("row", 0)),
				"col": int(n.get("col", 0)),
				"type": int(n.get("type", 0)),
				"visited": bool(n.get("visited", false)),
				"next": [],
				"foes": [],
			}
			for nx in n.get("next", []):
				node.next.append(int(nx))
			for foe in n.get("foes", []):
				if foe is Dictionary:
					var fa = []
					for af in foe.get("affixes", []):
						fa.append(str(af))
					node.foes.append({
						"key": str(foe.get("key", "slime")),
						"elite": bool(foe.get("elite", false)),
						"boss": bool(foe.get("boss", false)),
						"affixes": fa,
						"element": str(foe.get("element", "")),
					})
			# 旧版存档没有怪物构成 → 现场补掷
			if node.foes.is_empty():
				match node.type:
					GameData.NodeType.BATTLE:
						node.foes = CombatManager.roll_foes(region, cycle, false, false)
					GameData.NodeType.ELITE:
						node.foes = CombatManager.roll_foes(region, cycle, true, false)
					GameData.NodeType.BOSS:
						node.foes = CombatManager.roll_foes(region, cycle, false, true)
			nodes.append(node)
	if nodes.is_empty():
		return false
	var max_row = 0
	for n in nodes:
		max_row = maxi(max_row, n.row)
	var rows = []
	for r in range(max_row + 1):
		var row = []
		for n in nodes:
			if n.row == r:
				row.append(n)
		row.sort_custom(func(a, b): return a.col < b.col)
		rows.append(row)
	# 旧版存档地图没有节点连线 → 补织路线，避免小人无路可走卡死
	MapGenerator.ensure_links(rows)
	current_map = { "rows": rows, "nodes": nodes, "region": region, "cycle": cycle }

	_recalc_stats()
	hp = clampi(int(parsed.get("hp", max_hp)), 1, max_hp)

	change_state(State.MAP)
	SignalBus.gold_changed.emit(gold)
	SignalBus.potion_changed.emit(potions)
	SignalBus.hp_changed.emit(hp, max_hp)
	SignalBus.equipment_changed.emit("weapon", equipment.weapon if equipment.weapon else {})
	SignalBus.region_changed.emit(region)
	SignalBus.view_changed.emit("map")
	return true

func _restore_item(it: Dictionary) -> Dictionary:
	var item = it.duplicate(true)
	item["rarity"] = int(item.get("rarity", 0))
	item["level"] = int(item.get("level", 0))
	item["value"] = int(item.get("value", 0))
	item["invested"] = int(item.get("invested", 0))
	item["grade"] = int(item.get("grade", 1))
	if item.has("price"):
		item["price"] = int(item["price"])
	var st = item.get("stats", {})
	item["stats"] = {
		"atk": int(st.get("atk", 0)),
		"def": int(st.get("def", 0)),
		"hp": int(st.get("hp", 0)),
	}
	# 旧存档物品缺少图鉴/元素信息 → 按物品类型补默认基底
	if not item.has("catalog_id") or not item.has("element"):
		var entry = ItemCatalog.default_entry_for_key(str(item.get("key", "sword")))
		item["catalog_id"] = entry.id
		item["family"] = entry.base
		item["grade"] = entry.grade
		item["element"] = entry.element
		item["trait"] = entry.trait
		item["trait_desc"] = entry.trait_desc
		if not item.has("base_name"):
			item["base_name"] = entry.name
	if not item.has("prefix"):
		item["prefix"] = ""
		for p in GameData.EQUIP_PREFIXES:
			if str(item.get("name", "")).begins_with(p):
				item["prefix"] = p
				break
	var affixes = []
	for a in item.get("affixes", []):
		affixes.append(str(a))
	item["affixes"] = affixes
	# 词条强化等级（锻打同词条获得）
	var lvs = {}
	var raw_lv = item.get("affix_lv", {})
	if raw_lv is Dictionary:
		for k in raw_lv:
			lvs[str(k)] = clampi(int(raw_lv[k]), 1, GameData.AFFIX_MAX_LEVEL)
	item["affix_lv"] = lvs
	# 旧存档没有解说词条 → 现场补一份
	if not item.has("lore") or not (item["lore"] is Array) or item["lore"].is_empty():
		item["lore"] = LoreDataScript.compose_item_lore(item)
	return item

func _coerce_int_dict(d) -> Dictionary:
	var out = {}
	if d is Dictionary:
		for k in d:
			out[k] = int(d[k])
	return out

# ============================================================
# 地图外使用药水
# ============================================================
func use_potion_on_map() -> void:
	if current_state != State.MAP:
		SignalBus.show_toast.emit("现在无法使用药水")
		return
	if potions <= 0:
		SignalBus.show_toast.emit("没有药水了")
		return
	if hp >= max_hp:
		SignalBus.show_toast.emit("生命已满")
		return
	var stats = get_player_stats()
	var heal = use_potion(stats.get("potion_bonus_pct", 0))
	Sfx.play("heal")
	SignalBus.show_toast.emit("恢复了 %d 点生命" % heal)
	save_game()
