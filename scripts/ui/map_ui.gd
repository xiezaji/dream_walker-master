class_name MapUI
extends Control

const NODE_LABELS: Dictionary = {
	Enums.NodeType.BOON:     "赐福",
	Enums.NodeType.BATTLE:   "小怪",
	Enums.NodeType.ELITE:    "精英",
	Enums.NodeType.BOSS:     "BOSS",
	Enums.NodeType.SHOP:     "商店",
	Enums.NodeType.QUESTION: "?"
}

const COL_WIDTH: int   = 130
const ROW_SPACING: int = 90
const NODE_W: int      = 80
const NODE_H: int      = 40

@onready var hp_label: Label   = $PlayerInfo/HPLabel
@onready var gold_label: Label = $PlayerInfo/GoldLabel
@onready var deck_label: Label = $PlayerInfo/DeckLabel
@onready var map_root: Control = $ScrollContainer/MapRoot
var _level_label: Label = null
var _relic_labels: Array = []

## [col][row] = Button
var _buttons: Array = []
## [col][row] = Vector2（按钮中心，用于绘线）
var _centers: Array = []

func _ready() -> void:
	_add_extra_info()
	_update_player_info()
	_build_map()

func _add_extra_info() -> void:
	var info_bar: HBoxContainer = $PlayerInfo
	# 等级/经验标签
	_level_label = Label.new()
	info_bar.add_child(_level_label)
	# 遗物标签（每件遗物一个 Label）
	_relic_labels.clear()
	for relic in GameState.relics:
		var lbl := Label.new()
		lbl.tooltip_text = "%s\n%s" % [relic.relic_name, relic.description]
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		info_bar.add_child(lbl)
		_relic_labels.append(lbl)

func _update_player_info() -> void:
	hp_label.text   = "HP: %d/%d" % [GameState.current_hp, GameState.max_hp]
	gold_label.text = "金: %d" % GameState.gold
	deck_label.text = "牌组: %d张" % GameState.deck.size()
	if _level_label:
		if GameState.level >= 4:
			_level_label.text = "Lv4 (满级)"
		else:
			# 每级阈值10：Lv1需总经验10，Lv2需20，Lv3需30
			_level_label.text = "Lv%d (%d/%d经验)" % [
				GameState.level, GameState.experience, GameState.level * 10]
	for i in range(_relic_labels.size()):
		if i < GameState.relics.size():
			_relic_labels[i].text = "[%s]" % GameState.relics[i].relic_name

func _build_map() -> void:
	# 清理旧节点
	for child in map_root.get_children():
		child.queue_free()
	_buttons.clear()
	_centers.clear()

	var num_cols: int = RunManager.columns.size()
	var max_rows: int = 1
	for col in RunManager.columns:
		if col.size() > max_rows:
			max_rows = col.size()

	var total_h: float = max_rows * ROW_SPACING
	map_root.custom_minimum_size = Vector2(num_cols * COL_WIDTH + 40, total_h + 60)

	for col_idx in range(num_cols):
		var col_nodes: Array = RunManager.columns[col_idx]
		var btn_col: Array = []
		var ctr_col: Array = []
		for row_idx in range(col_nodes.size()):
			var node_type: Enums.NodeType = col_nodes[row_idx]
			var btn := Button.new()
			btn.text = NODE_LABELS.get(node_type, "?")
			btn.custom_minimum_size = Vector2(NODE_W, NODE_H)
			# 垂直居中排列：多行时均匀分布
			var col_h: float = col_nodes.size() * ROW_SPACING
			var y_start: float = (total_h - col_h) / 2.0 + 20.0
			var cx: float = col_idx * COL_WIDTH + 20.0 + NODE_W / 2.0
			var cy: float = y_start + row_idx * ROW_SPACING + NODE_H / 2.0
			btn.position = Vector2(cx - NODE_W / 2.0, cy - NODE_H / 2.0)
			btn.pressed.connect(_on_node_pressed.bind(col_idx, row_idx))
			map_root.add_child(btn)
			btn_col.append(btn)
			ctr_col.append(Vector2(cx, cy))
		_buttons.append(btn_col)
		_centers.append(ctr_col)

	_draw_connections()
	_refresh_buttons()

func _draw_connections() -> void:
	for col_idx in range(RunManager.connections.size()):
		var col_conns: Array = RunManager.connections[col_idx]
		for from_row in range(col_conns.size()):
			if col_idx >= _centers.size() or from_row >= _centers[col_idx].size():
				continue
			for to_row in col_conns[from_row]:
				if col_idx + 1 >= _centers.size() or to_row >= _centers[col_idx + 1].size():
					continue
				var p1: Vector2 = _centers[col_idx][from_row]
				var p2: Vector2 = _centers[col_idx + 1][to_row]
				var line := Line2D.new()
				line.width = 2.0
				line.default_color = Color(0.5, 0.5, 0.5, 0.8)
				line.add_point(p1)
				line.add_point(p2)
				map_root.add_child(line)

func _refresh_buttons() -> void:
	var cur_col: int = RunManager.current_col
	var cur_row: int = RunManager.current_row
	var done: bool   = RunManager.current_node_completed
	var available: Array[int] = RunManager.get_available_next_rows()
	# 初始状态 cur_col=-1：available 是列0所有节点
	var next_col: int = cur_col + 1

	for col_idx in range(_buttons.size()):
		for row_idx in range(_buttons[col_idx].size()):
			var btn: Button = _buttons[col_idx][row_idx]
			var is_current: bool = (col_idx == cur_col and row_idx == cur_row)
			var is_selectable: bool = (col_idx == next_col and row_idx in available) if done else is_current
			var is_past: bool = col_idx < cur_col and cur_col >= 0

			btn.disabled = not is_selectable

			if is_current:
				btn.modulate = Color.YELLOW
			elif is_past:
				btn.modulate = Color(0.4, 0.4, 0.4)
			elif is_selectable:
				btn.modulate = Color.WHITE
			else:
				btn.modulate = Color(0.65, 0.65, 0.65)

func _on_node_pressed(col: int, row: int) -> void:
	if RunManager.current_node_completed:
		# 选择下一个节点并进入场景
		RunManager.move_to(col, row)
	# 进入当前节点场景
	var scene := RunManager.get_scene_for_current_node()
	get_tree().change_scene_to_file(scene)
