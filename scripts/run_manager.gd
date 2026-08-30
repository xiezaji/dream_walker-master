extends Node

## 分支地图：columns[col] = Array[Enums.NodeType]
var columns: Array = []
## 连接：connections[col][from_row] = Array[int]（指向下一列的 row 索引）
var connections: Array = []

var current_col: int = 0
var current_row: int = 0
var current_node_completed: bool = false
var current_event: Enums.EventType = Enums.EventType.SLEEPING_MERCHANT
## 大梦已上交，下次 BOSS 战替换为梦魇
var big_dream_submitted: bool = false

func start_run() -> void:
	current_col = -1  # -1 表示尚未选择起始节点
	current_row = 0
	current_node_completed = true  # 允许玩家在地图上选择列0的节点
	big_dream_submitted = false
	_generate_map()

func _generate_map() -> void:
	columns = []
	connections = []

	# 列0：2个赐福节点
	columns.append([Enums.NodeType.BOON, Enums.NodeType.BOON])

	# 列1-3：随机 2 或 3 个 QUESTION 节点
	for _i in range(3):
		var count := 2 + (randi() % 2)  # 2 或 3
		var col: Array = []
		for _j in range(count):
			col.append(Enums.NodeType.QUESTION)
		columns.append(col)

	# 列4：商店
	columns.append([Enums.NodeType.SHOP])
	# 列5：精英
	columns.append([Enums.NodeType.ELITE])
	# 列6：赐福
	columns.append([Enums.NodeType.BOON])
	# 列7：BOSS
	columns.append([Enums.NodeType.BOSS])

	# 生成不交叉的连接
	for col_idx in range(columns.size() - 1):
		var n_from: int = columns[col_idx].size()
		var n_to: int = columns[col_idx + 1].size()
		connections.append(_generate_non_crossing_connections(n_from, n_to))

## 生成不交叉的列间连接
## 不交叉约束：若 from_row_a < from_row_b，则 max(conns[a]) <= min(conns[b])
func _generate_non_crossing_connections(n_from: int, n_to: int) -> Array:
	var col_conns: Array = []
	for _r in range(n_from):
		col_conns.append([])

	# Step 1：按比例分配基础连接（保证不交叉）
	for i in range(n_from):
		var base_to: int
		if n_from == 1:
			base_to = 0
		else:
			base_to = int(round(float(i) * (n_to - 1) / float(n_from - 1)))
		col_conns[i].append(base_to)

	# Step 2：确保 to_col 每个节点都有入边
	var covered: Array = []
	for t in range(n_to):
		covered.append(false)
	for i in range(n_from):
		for t in col_conns[i]:
			covered[t] = true
	for t in range(n_to):
		if not covered[t]:
			# 找最近的 from_row（按基础 to_row 距离）
			var best_from: int = 0
			var best_dist: int = 9999
			for i in range(n_from):
				var dist: int = abs(col_conns[i][0] - t)
				if dist < best_dist:
					best_dist = dist
					best_from = i
			if t not in col_conns[best_from]:
				col_conns[best_from].append(t)

	# Step 3：随机添加第二条连接（约40%概率，严格不交叉）
	if n_to > 1:
		for i in range(n_from):
			if randf() >= 0.4:
				continue
			var cur_max: int = col_conns[i].max()
			var cur_min: int = col_conns[i].min()
			# 上界：不超过下一行的最小连接（若存在）
			var upper: int = n_to - 1 if i == n_from - 1 else col_conns[i + 1].min()
			# 下界：不低于上一行的最大连接（若存在）
			var lower: int = 0 if i == 0 else col_conns[i - 1].max()
			# 尝试向上扩展
			if cur_max + 1 < upper:
				col_conns[i].append(cur_max + 1)
			# 否则尝试向下扩展
			elif cur_min - 1 > lower:
				col_conns[i].append(cur_min - 1)

	return col_conns

func get_current_node() -> Enums.NodeType:
	if current_col < 0 or current_col >= columns.size():
		return Enums.NodeType.BOON
	return columns[current_col][current_row]

## 返回下一列中当前节点可到达的 row 索引列表
func get_available_next_rows() -> Array[int]:
	var result: Array[int] = []
	# 游戏刚开始：返回列0的所有节点供玩家选择
	if current_col == -1:
		if columns.size() > 0:
			for i in range(columns[0].size()):
				result.append(i)
		return result
	if current_col >= connections.size() or current_row >= connections[current_col].size():
		return result
	for r in connections[current_col][current_row]:
		result.append(r as int)
	return result

## 玩家选择下一个节点
func move_to(col: int, row: int) -> void:
	current_col = col
	current_row = row
	current_node_completed = false

## 当前节点完成（跳回地图时调用）
func mark_current_done() -> void:
	current_node_completed = true

## 兼容旧接口（事件/战斗完成后调用）
func advance_node() -> void:
	mark_current_done()

func is_run_complete() -> bool:
	return current_node_completed and current_col >= columns.size() - 1

## 当前列（显示用，-1 时返回 -1）
func get_current_col() -> int:
	return current_col

func get_scene_for_current_node() -> String:
	var node_type := get_current_node()
	match node_type:
		Enums.NodeType.BOON:     return "res://scenes/boon/boon_select.tscn"
		Enums.NodeType.BATTLE:   return "res://scenes/battle/battle.tscn"
		Enums.NodeType.ELITE:    return "res://scenes/battle/battle.tscn"
		Enums.NodeType.BOSS:     return "res://scenes/battle/battle.tscn"
		Enums.NodeType.SHOP:     return "res://scenes/shop/shop.tscn"
		Enums.NodeType.QUESTION:
			if randf() < 0.6:
				return "res://scenes/battle/battle.tscn"
			_roll_event()
			return "res://scenes/event/event.tscn"
		_: return "res://scenes/battle/battle.tscn"

func _roll_event() -> void:
	var event_pool: Array = [
		Enums.EventType.SLEEPING_MERCHANT,
		Enums.EventType.WARM_BED,
		Enums.EventType.FOUNTAIN_OF_FORGETTING
	]
	current_event = event_pool[randi() % event_pool.size()]
