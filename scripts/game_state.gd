extends Node

# ============================================================
# 游戏状态管理器 - Autoload Singleton
# 管理所有运行时状态：玩家、装备、地图、战斗
# ============================================================

const EquipmentFactory = preload("res://scripts/equipment/equipment_factory.gd")
const EquipmentModifier = preload("res://scripts/equipment/equipment_modifier.gd")
const MapGenerator = preload("res://scripts/map/map_generator.gd")
const CombatManager = preload("res://scripts/combat/combat_manager.gd")

# 游戏状态枚举
enum State { TITLE, MAP, COMBAT, TREASURE, SHOP, EVENT, REWARD, DEAD, VICTORY }

# 当前状态
var current_state: int = State.TITLE

# 玩家基础状态
var region: int = 0
var gold: int = 0
var potions: int = 0
var hp: int = 50
var max_hp: int = 50
var energy: int = 10
var max_energy: int = 10
var region_buff: float = 0.0

# 装备
var equipment = {
	"weapon": null,
	"armor": null,
	"accessory": null,
}

# 背包
var bag: Array = []

# 地图
var current_map: Dictionary = {}
var current_node_idx: int = -1

# 战斗
var combat_state: Dictionary = {}

# 本局统计
var run_stats: Dictionary = {}

const SAVE_PATH = "user://pixel_pathfinder_save.json"

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
	print("[GameState] 初始化完成")

# ============================================================
# 状态切换
# ============================================================
func change_state(new_state: int) -> void:
	current_state = new_state
	var state_name = _state_to_string(new_state)
	SignalBus.state_changed.emit(state_name)
	print("[GameState] 状态切换至: ", state_name)

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

func start_new_game() -> void:
	reset_run_stats()
	clear_save()
	region = 0
	gold = GameData.PLAYER_BASE["start_gold"]
	potions = GameData.PLAYER_BASE["start_potions"]
	region_buff = 0.0
	bag.clear()
	
	# 初始装备
	var sword = EquipmentFactory.create_starter_weapon()
	var armor = EquipmentFactory.create_starter_armor()
	equipment["weapon"] = sword
	equipment["armor"] = armor
	equipment["accessory"] = null
	
	# 计算最大生命
	_recalc_stats()
	hp = max_hp
	energy = max_energy
	
	SignalBus.gold_changed.emit(gold)
	SignalBus.potion_changed.emit(potions)
	SignalBus.equipment_changed.emit("weapon", sword)
	SignalBus.equipment_changed.emit("armor", armor)
	
	print("[GameState] 新游戏开始")
	start_region(0)

func start_region(r: int) -> void:
	region = r
	current_node_idx = -1
	current_map = MapGenerator.generate_map(r)
	change_state(State.MAP)
	_recalc_stats()
	hp = min(hp, max_hp)
	SignalBus.region_changed.emit(r)
	SignalBus.view_changed.emit("map")

# ============================================================
# 属性计算
# ============================================================
func _recalc_stats() -> void:
	var stats = EquipmentModifier.calculate_total_stats(equipment)
	max_hp = GameData.PLAYER_BASE["max_hp"] + stats.hp
	max_energy = GameData.PLAYER_BASE["max_energy"]
	# 区域祝福已在 EquipmentModifier.calculate_total_stats 中统一应用
	# 存储计算后的属性供战斗使用
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
	SignalBus.equipment_changed.emit(slot, item)
	SignalBus.bag_changed.emit(bag.duplicate())

func upgrade_equipped(slot: String) -> bool:
	var it = equipment[slot]
	if not it or it.level >= GameData.COMBAT["max_upgrade_level"]:
		return false
	var cost = EquipmentModifier.get_upgrade_cost(it, region)
	if gold < cost:
		return false
	
	gold -= cost
	it.level += 1
	
	if it.level == 3:
		SignalBus.show_toast.emit("★ 被动技能已解锁！")
	elif it.level == 5:
		SignalBus.show_toast.emit("✦ 独特效果已解锁！")
	
	_recalc_stats()
	SignalBus.gold_changed.emit(gold)
	SignalBus.equipment_changed.emit(slot, it)
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
	
	if it.level == 3:
		SignalBus.show_toast.emit("★ 被动技能已解锁！")
	elif it.level == 5:
		SignalBus.show_toast.emit("✦ 独特效果已解锁！")
	
	SignalBus.gold_changed.emit(gold)
	SignalBus.bag_changed.emit(bag.duplicate())
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

# ============================================================
# 背包操作
# ============================================================
func add_to_bag(item: Dictionary) -> bool:
	if bag.size() >= GameData.PLAYER_BASE["bag_capacity"]:
		return false
	bag.append(item)
	SignalBus.bag_changed.emit(bag.duplicate())
	return true

# ============================================================
# 药水操作
# ============================================================
func use_potion() -> bool:
	if potions <= 0:
		return false
	var heal_amount = roundi(max_hp * GameData.COMBAT["potion_heal_pct"])
	hp = min(hp + heal_amount, max_hp)
	potions -= 1
	SignalBus.hp_changed.emit(hp, max_hp)
	SignalBus.potion_changed.emit(potions)
	return true

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
# 战斗入口
# ============================================================
func enter_combat(elite: bool = false, boss: bool = false) -> void:
	change_state(State.COMBAT)
	var depth = 0
	if current_map.has("nodes"):
		for n in current_map.nodes:
			if n.id == current_node_idx:
				depth = n.row
				break
	
	combat_state = CombatManager.setup_combat(region, depth, elite, boss)
	SignalBus.combat_started.emit(combat_state.enemies)
	SignalBus.view_changed.emit("combat")

# ============================================================
# 节点进入
# ============================================================
func enter_node(node_data: Dictionary) -> void:
	current_node_idx = node_data.id
	node_data.visited = true
	run_stats.nodes_visited += 1
	
	match node_data.type:
		GameData.NodeType.BATTLE:
			enter_combat(false, false)
		GameData.NodeType.ELITE:
			enter_combat(true, false)
		GameData.NodeType.BOSS:
			enter_combat(false, true)
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
		var rarity_boost = 1 if randf() < 0.3 else 0
		var item = EquipmentFactory.generate_item(region, "", rarity_boost)
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
	for i in range(3):
		var rarity_boost = 1 if randf() < 0.5 else 0
		var it = EquipmentFactory.generate_item(region, "", rarity_boost)
		it["price"] = roundi(it.value * 1.6 * disc / 5.0) * 5
		shop_stock.append(it)
	potion_price = roundi(30 * (1 + region * 0.2) * disc / 5.0) * 5
	SignalBus.show_modal.emit("shop", { "stock": shop_stock, "potion_price": potion_price })

func open_event() -> void:
	change_state(State.EVENT)
	var keys = GameData.EVENTS.keys()
	var which = keys[randi() % keys.size()]
	var ev_data = GameData.EVENTS[which].duplicate(true)
	ev_data["key"] = which
	match which:
		"merchant":
			ev_data["cost"] = 45 + region * 20
		"shrine":
			ev_data["hp_cost"] = roundi(hp * 0.2)
		"cave":
			ev_data["safe_gold"] = 30 + region * 12
	SignalBus.show_modal.emit("event", ev_data)

# ============================================================
# 事件处理
# ============================================================
func handle_event_choice(event_key: String, choice: String) -> void:
	match event_key:
		"merchant":
			if choice == "pay":
				var cost = 45 + region * 20
				if gold >= cost:
					gold -= cost
					var item = EquipmentFactory.generate_item(region, "", 1)
					pending_drop = item
					SignalBus.gold_changed.emit(gold)
					SignalBus.show_modal.emit("reward", { "item": item, "source": "merchant" })
			else:
				back_to_map()
		"shrine":
			if choice == "offer":
				hp = max(1, hp - roundi(hp * 0.2))
				region_buff += 0.15
				SignalBus.hp_changed.emit(hp, max_hp)
				SignalBus.show_toast.emit("祭坛祝福：本区域攻击力 +15%")
			back_to_map()
		"cave":
			if choice == "safe":
				var g = 30 + region * 12
				gold += g
				SignalBus.gold_changed.emit(gold)
				SignalBus.show_toast.emit("获得 %d 金币" % g)
				back_to_map()
			elif choice == "risky":
				if randf() < 0.5:
					var item = EquipmentFactory.generate_item(region, "", 2)
					pending_drop = item
					SignalBus.show_modal.emit("reward", { "item": item, "source": "cave" })
				else:
					SignalBus.show_toast.emit("伏击！")
					enter_combat(true, false)

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
# 区域/游戏结算
# ============================================================
func region_clear() -> void:
	region_buff = 0.0
	if region >= GameData.BIOMES.size() - 1:
		change_state(State.VICTORY)
		clear_save()
		SignalBus.game_victory.emit()
		SignalBus.show_modal.emit("victory", { "gold": gold, "equipment": equipment.duplicate(true), "stats": run_stats.duplicate() })
	else:
		var bonus = 60 + region * 40
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
	save_game()

func player_defeated() -> void:
	change_state(State.DEAD)
	var lost = floori(gold / 2.0)
	gold -= lost
	SignalBus.gold_changed.emit(gold)
	save_game()
	SignalBus.show_modal.emit("defeat", { "region": region, "lost_gold": lost, "stats": run_stats.duplicate() })

func retry_region() -> void:
	_recalc_stats()
	hp = max_hp
	region_buff = 0.0
	start_region(region)
	save_game()

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
# 地图访问
# ============================================================
func get_reachable_nodes() -> Array:
	if current_state != State.MAP:
		return []
	if current_node_idx < 0:
		return current_map.get("rows", [[]])[0] if current_map.has("rows") else []
	for n in current_map.get("nodes", []):
		if n.id == current_node_idx:
			return n.next
	return []

# ============================================================
# 存档系统
# ============================================================
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func clear_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

func save_game() -> void:
	if current_state == State.VICTORY:
		return
	var data = {
		"version": 2,
		"region": region,
		"gold": gold,
		"potions": potions,
		"hp": hp,
		"region_buff": region_buff,
		"equipment": equipment,
		"bag": bag,
		"map_nodes": current_map.get("nodes", []),
		"current_node_idx": current_node_idx,
		"run_stats": run_stats,
	}
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()

func load_game() -> bool:
	if not has_save():
		return false
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return false
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return false

	region = int(parsed.get("region", 0))
	gold = int(parsed.get("gold", 0))
	potions = int(parsed.get("potions", 0))
	region_buff = float(parsed.get("region_buff", 0.0))
	current_node_idx = int(parsed.get("current_node_idx", -1))
	run_stats = _coerce_int_dict(parsed.get("run_stats", {}))
	if run_stats.is_empty():
		reset_run_stats()

	equipment = { "weapon": null, "armor": null, "accessory": null }
	var eq = parsed.get("equipment", {})
	for slot in ["weapon", "armor", "accessory"]:
		var it = eq.get(slot)
		if it is Dictionary:
			equipment[slot] = _restore_item(it)

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
			}
			for nx in n.get("next", []):
				node.next.append(int(nx))
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
	current_map = { "rows": rows, "nodes": nodes, "region": region }

	_recalc_stats()
	hp = clampi(int(parsed.get("hp", max_hp)), 1, max_hp)

	change_state(State.MAP)
	SignalBus.gold_changed.emit(gold)
	SignalBus.potion_changed.emit(potions)
	SignalBus.hp_changed.emit(hp, max_hp)
	SignalBus.equipment_changed.emit("weapon", equipment.weapon if equipment.weapon else {})
	SignalBus.region_changed.emit(region)
	return true

func _restore_item(it: Dictionary) -> Dictionary:
	var item = it.duplicate(true)
	item["rarity"] = int(item.get("rarity", 0))
	item["level"] = int(item.get("level", 0))
	item["value"] = int(item.get("value", 0))
	if item.has("price"):
		item["price"] = int(item["price"])
	var st = item.get("stats", {})
	item["stats"] = {
		"atk": int(st.get("atk", 0)),
		"def": int(st.get("def", 0)),
		"hp": int(st.get("hp", 0)),
	}
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
	var heal = roundi(max_hp * GameData.COMBAT["potion_heal_pct"])
	use_potion()
	Sfx.play("heal")
	SignalBus.show_toast.emit("恢复了 %d 点生命" % heal)
