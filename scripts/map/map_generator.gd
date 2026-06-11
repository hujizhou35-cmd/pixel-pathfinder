class_name MapGenerator
extends RefCounted

# ============================================================
# 地图生成器 - 生成节点式地图
# ============================================================

static func generate_map(region: int) -> Dictionary:
	var row_counts = [2, 3, 2, 2, 1]
	var rows = []
	var all_nodes = []
	var id = 0

	# 创建节点
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
			}
			row.append(node)
			all_nodes.append(node)
			id += 1
		rows.append(row)

	# 设置特殊节点
	rows[4][0].type = GameData.NodeType.BOSS

	# 随机设置精英和商店
	var mid_nodes = []
	for r in range(1, 4):
		for n in rows[r]:
			mid_nodes.append(n)

	mid_nodes.shuffle()
	var elite_set = false
	var shop_set = false
	for n in mid_nodes:
		if n.type == GameData.NodeType.BATTLE:
			if not elite_set:
				n.type = GameData.NodeType.ELITE
				elite_set = true
			elif not shop_set:
				n.type = GameData.NodeType.SHOP
				shop_set = true
			else:
				break

	# 随机设置其余节点类型
	for n in mid_nodes:
		if n.type != GameData.NodeType.BATTLE:
			continue
		var r = randf()
		if r < 0.50:
			n.type = GameData.NodeType.BATTLE
		elif r < 0.72:
			n.type = GameData.NodeType.EVENT
		else:
			n.type = GameData.NodeType.TREASURE

	# 第一行也随机化
	for n in rows[0]:
		if randf() < 0.3:
			n.type = GameData.NodeType.EVENT if randf() < 0.5 else GameData.NodeType.TREASURE

	# 创建连接
	for r in range(rows.size() - 1):
		var A = rows[r]
		var B = rows[r + 1]
		for a in A:
			var ax = (a.col + 0.5) / A.size()
			var sorted_b = B.duplicate()
			sorted_b.sort_custom(func(u, v):
				var ux = (u.col + 0.5) / B.size()
				var vx = (v.col + 0.5) / B.size()
				return abs(ux - ax) < abs(vx - ax)
			)
			a.next.append(sorted_b[0].id)
			if B.size() > 1 and randf() < 0.55:
				a.next.append(sorted_b[1].id)

		# 保证覆盖
		for b in B:
			var connected = false
			for aa in A:
				if aa.next.has(b.id):
					connected = true
					break
			if not connected:
				var bx = (b.col + 0.5) / B.size()
				var near = A.duplicate()
				near.sort_custom(func(u, v):
					var ux = (u.col + 0.5) / A.size()
					var vx = (v.col + 0.5) / A.size()
					return abs(ux - bx) < abs(vx - bx)
				)
				near[0].next.append(b.id)

	return {
		"rows": rows,
		"nodes": all_nodes,
		"region": region,
	}
