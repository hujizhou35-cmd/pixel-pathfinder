class_name MapGenerator
extends RefCounted

# ============================================================
# 地图生成器 - 自由选关式地图（元气骑士式）
# - 所有未探索节点随时可进，打完首领即过区
#   → 可先收集完资源再挑战首领，也可以直奔首领
# - 战斗节点在生成时即掷出怪物构成(foes)，进场前可预览
# ============================================================

const CombatManagerScript = preload("res://scripts/combat/combat_manager.gd")

static func generate_map(region: int, cycle: int = 0) -> Dictionary:
	var rows = []
	var all_nodes = []
	var id = 0

	# 3 行 × 4 个自由节点 + 顶部首领
	var row_counts = [4, 4, 4, 1]
	for r in range(row_counts.size()):
		var row = []
		for c in range(row_counts[r]):
			var node = {
				"id": id,
				"row": r,
				"col": c,
				"type": GameData.NodeType.BATTLE,
				"next": [],
				"visited": false,
				"foes": [],
			}
			row.append(node)
			all_nodes.append(node)
			id += 1
		rows.append(row)

	rows[3][0].type = GameData.NodeType.BOSS

	# 分配特殊节点：1 商店 / 1-2 精英 / 2 宝箱 / 3 事件，其余战斗
	var free_nodes = []
	for r in range(3):
		for n in rows[r]:
			free_nodes.append(n)
	free_nodes.shuffle()

	var elite_count = 2 if (region >= 3 or cycle > 0) else 1
	var plan = []
	plan.append(GameData.NodeType.SHOP)
	for i in range(elite_count):
		plan.append(GameData.NodeType.ELITE)
	plan.append(GameData.NodeType.TREASURE)
	plan.append(GameData.NodeType.TREASURE)
	plan.append(GameData.NodeType.EVENT)
	plan.append(GameData.NodeType.EVENT)
	plan.append(GameData.NodeType.EVENT)
	for i in range(mini(plan.size(), free_nodes.size())):
		free_nodes[i].type = plan[i]

	# 掷出战斗节点的怪物构成（进场前可预览，预览即实战）
	for n in all_nodes:
		match n.type:
			GameData.NodeType.BATTLE:
				n.foes = CombatManagerScript.roll_foes(region, cycle, false, false)
			GameData.NodeType.ELITE:
				n.foes = CombatManagerScript.roll_foes(region, cycle, true, false)
			GameData.NodeType.BOSS:
				n.foes = CombatManagerScript.roll_foes(region, cycle, false, true)

	return {
		"rows": rows,
		"nodes": all_nodes,
		"region": region,
		"cycle": cycle,
	}
