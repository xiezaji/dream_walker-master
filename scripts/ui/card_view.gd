class_name CardView
extends Control

const DRAG_SCALE := Vector2(1.1, 1.1)
const DRAG_Z_INDEX := 100

signal card_released_on_target(card_view: Control, target: Object)

var card_data: CardData = null
var is_dragging: bool = false
var _drag_offset: Vector2 = Vector2.ZERO
var _original_global_pos: Vector2 = Vector2.ZERO
var _original_parent: Node = null
var _original_index: int = 0

@onready var cost_label: Label = $CostLabel
@onready var name_label: Label = $NameLabel
@onready var type_label: Label = $TypeLabel
@onready var desc_label: RichTextLabel = $DescLabel
@onready var highlight: ColorRect = $HighlightBorder

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

func setup(data: CardData) -> void:
	card_data = data
	cost_label.text = str(data.cost) if data.cost >= 0 else "X"
	type_label.text = _type_text(data.card_type)
	_set_rarity_color(data.rarity)
	refresh_nightmare_display()

## 根据噩梦状态决定是否隐藏卡牌信息
func refresh_nightmare_display() -> void:
	if card_data == null:
		return
	if GameState.has_status(Enums.StatusEffectType.NIGHTMARE):
		name_label.text = "???"
		desc_label.text = "???"
	else:
		name_label.text = card_data.card_name
		desc_label.text = card_data.description

func _type_text(t: Enums.CardType) -> String:
	match t:
		Enums.CardType.ATTACK: return "攻击"
		Enums.CardType.SKILL: return "技能"
		Enums.CardType.POWER: return "能力"
		Enums.CardType.CURSE: return "诅咒"
	return ""

func _set_rarity_color(r: Enums.Rarity) -> void:
	var colors := {
		Enums.Rarity.STARTER: Color(0.7, 0.7, 0.7),
		Enums.Rarity.COMMON: Color(1, 1, 1),
		Enums.Rarity.RARE: Color(0.4, 0.7, 1.0),
		Enums.Rarity.EPIC: Color(0.8, 0.4, 1.0),
		Enums.Rarity.LEGENDARY: Color(1.0, 0.8, 0.2)
	}
	$CardBG.modulate = colors.get(r, Color.WHITE)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			_start_drag()

func _process(_delta: float) -> void:
	if is_dragging:
		global_position = get_global_mouse_position() - _drag_offset

func _input(event: InputEvent) -> void:
	if not is_dragging:
		return
	if not is_inside_tree():
		is_dragging = false
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_end_drag()
			if get_viewport():
				get_viewport().set_input_as_handled()

func _start_drag() -> void:
	if BattleManager.current_phase != Enums.BattlePhase.PLAYER_TURN:
		return
	if card_data == null:
		return
	if card_data.cannot_play:
		return
	var effective_cost: int = BattleManager.card_cost_overrides.get(card_data.id, card_data.cost)
	if effective_cost != -1 and BattleManager.current_energy < effective_cost:
		return
	is_dragging = true
	_original_global_pos = global_position
	_original_parent = get_parent()
	_original_index = get_index()
	_drag_offset = get_global_mouse_position() - global_position
	# 移出 HBoxContainer，否则容器每帧会重置子节点位置
	var root := get_tree().get_root()
	_original_parent.remove_child(self)
	root.add_child(self)
	global_position = _original_global_pos
	scale = DRAG_SCALE
	z_index = DRAG_Z_INDEX

func _end_drag() -> void:
	if not is_dragging:
		return
	is_dragging = false
	scale = Vector2.ONE
	z_index = 0
	# 先拿到释放位置，再移回手牌区
	var gpos := get_global_mouse_position()
	var target := _find_enemy_at(gpos)
	get_tree().get_root().remove_child(self)
	_original_parent.add_child(self)
	_original_parent.move_child(self, _original_index)
	global_position = _original_global_pos
	if card_data == null:
		return
	# 只有含 ONE_ENEMY 效果的卡牌才需要指定目标；其余（SELF/ALL_ENEMIES/RANDOM_ENEMY）无需目标
	var needs_target := card_data.effects.any(func(e): return e.target == Enums.TargetType.ONE_ENEMY)
	if target != null or not needs_target:
		card_released_on_target.emit(self, target)

func _find_enemy_at(gpos: Vector2) -> Object:
	var scene := get_tree().current_scene
	var enemy_area := scene.get_node_or_null("EnemyArea")
	if enemy_area == null:
		return null
	for enemy_view in enemy_area.get_children():
		if enemy_view.get_global_rect().has_point(gpos):
			return enemy_view.enemy_instance
	return null

func set_highlighted(on: bool) -> void:
	highlight.visible = on
