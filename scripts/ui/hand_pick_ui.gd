class_name HandPickUI
extends Control

## 全知遗物：每回合开始时从全部可用卡牌中自选手牌
signal picks_done(chosen: Array)

@onready var pool_container: HBoxContainer = $Panel/VBox/ScrollContainer/PoolContainer
@onready var confirm_button: Button = $Panel/VBox/ConfirmButton
@onready var title_label: Label = $Panel/VBox/TitleLabel

const CardViewScene = preload("res://scenes/ui/card_view.tscn")

var _pick_count: int = 5
var _selected: Array[CardData] = []
var _card_views: Dictionary = {}  # CardData -> VBoxContainer

func setup(pool: Array, count: int, title: String = "") -> void:
	_pick_count = count
	if title.is_empty():
		title_label.text = "从卡牌中选择 %d 张" % count
	else:
		title_label.text = title
	confirm_button.disabled = true
	for card_data in pool:
		var vbox := VBoxContainer.new()
		var card_view := CardViewScene.instantiate()
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var select_btn := Button.new()
		select_btn.text = "选"
		select_btn.pressed.connect(_on_card_toggled.bind(card_data, vbox, select_btn))
		vbox.add_child(card_view)
		vbox.add_child(select_btn)
		pool_container.add_child(vbox)
		card_view.setup(card_data)
		_card_views[card_data] = vbox

func _on_card_toggled(card_data: CardData, vbox: VBoxContainer, btn: Button) -> void:
	if card_data in _selected:
		_selected.erase(card_data)
		vbox.modulate = Color.WHITE
		btn.text = "选"
	else:
		if _selected.size() >= _pick_count:
			return
		_selected.append(card_data)
		vbox.modulate = Color(0.5, 1.0, 0.5)
		btn.text = "取消"
	confirm_button.disabled = _selected.size() < _pick_count

func _on_confirm_pressed() -> void:
	picks_done.emit(_selected.duplicate())
	queue_free()
