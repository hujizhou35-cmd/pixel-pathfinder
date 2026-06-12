class_name MapGenerator
extends RefCounted

# ============================================================
# 地图生成器 - 有序路线地图（杀戮尖塔式 DAG）
# - 自下而上 5 排节点，相邻排之间以连线相接，顶部为首领
# - 小人(WASD)沿连线移动，可折返换路；进入节点与否由玩家选择
# - 已结束的战斗不可再进，但可作为通路经过；商店可重复进入
# - 战斗节点在生成时即掷出怪物构成(foes)，进场前可预览
# ============================================================

const CombatManagerScript = preload("res://scripts/combat/combat_manager.gd")

static func generate_map(region: int, cycle: int = 0) -> Dictionary:
	var rows = []
	var all_nodes = []
	var id = 0

	# 底部 → 顶部：起步战斗排 / 中段三排 / 首领
	var row_counts = [3, 4, 4, 3, 1]
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

	# 连线：相邻排之间按横向位置就近连接，保证上下双向连通
	_link_rows(rows)

	rows[rows.size() - 1][0].type = GameData.NodeType.BOSS

	# 分配特殊节点：底排保持战斗；中段三排洒入商店/精英/宝箱/事件
	var free_nodes = []
	for r in range(1, rows.size() - 1):
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

## 旧版(v4)存档的地图节点没有连线（next 全空）→ 读档后补织路线，
## 否则小人走上节点后无路可走会卡死
static func ensure_links(rows: Array) -> void:
	if rows.size() < 2:
		return
	for row in rows:
		for n in row:
			if not n.get("next", []).is_empty():
				return   # 已有连线（v5 地图），无需处理
	_link_rows(rows)

## 相邻排连线：每个节点按归一化横向位置连接上一排最近的 1-2 个节点，
## 再补边保证下排每个节点至少有 1 条向上路、上排每个节点至少有 1 条向下路
static func _link_rows(rows: Array) -> void:
	for r in range(rows.size() - 1):
		var lower: Array = rows[r]
		var upper: Array = rows[r + 1]
		for n in lower:
			var pos = _norm_pos(n.col, lower.size())
			# 距离最近的上排节点
			var order = []
			for u in upper:
				order.append({ "id": u.id, "d": absf(_norm_pos(u.col, upper.size()) - pos) })
			order.sort_custom(func(a, b): return a.d < b.d)
			n.next.append(order[0].id)
			# 40% 概率多接一条岔路（次近且距离不太远）
			if order.size() > 1 and order[1].d < 0.45 and randf() < 0.40:
				n.next.append(order[1].id)
		# 上排孤儿节点（没有任何下排连入）→ 从最近的下排节点补一条边
		for u in upper:
			var has_in = false
			for n in lower:
				if n.next.has(u.id):
					has_in = true
					break
			if not has_in:
				var upos = _norm_pos(u.col, upper.size())
				var best = lower[0]
				var best_d = 99.0
				for n in lower:
					var d = absf(_norm_pos(n.col, lower.size()) - upos)
					if d < best_d:
						best_d = d
						best = n
				best.next.append(u.id)

static func _norm_pos(col: int, count: int) -> float:
	if count <= 1:
		return 0.5
	return float(col) / float(count - 1)
