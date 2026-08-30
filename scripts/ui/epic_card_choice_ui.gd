class_name EpicCardChoiceUI
extends Control

signal choice_made

@onready var cards_container: HBoxContainer = $Overlay/Panel/VBox/CardsContainer
@onready var title_label: Label = $Overlay/Panel/VBox/TitleLabel

const CardViewScene = preload("res://scenes/ui/card_view.tscn")

func _ready() -> void:
	title_label.text = "升至4级！选择奖励："
	# 选项1：生命值上限+20
	var hp_vbox := VBoxContainer.new()
	var hp_label := Label.new()
	hp_label.text = "最大生命值\n+20"
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_label.custom_minimum_size = Vector2(120, 100)
	var hp_btn := Button.new()
	hp_btn.text = "选择"
	hp_btn.pressed.connect(_on_hp_selected)
	hp_vbox.add_child(hp_label)
	hp_vbox.add_child(hp_btn)
	cards_container.add_child(hp_vbox)

	# 选项2-4：3张史诗卡
	var epic_cards := CardDatabase.get_by_rarity(Enums.Rarity.EPIC)
	epic_cards.shuffle()
	var shown := epic_cards.slice(0, min(3, epic_cards.size()))
	for card_data in shown:
		var vbox := VBoxContainer.new()
		var card_view := CardViewScene.instantiate()
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var btn := Button.new()
		btn.text = "选择"
		btn.pressed.connect(_on_card_selected.bind(card_data))
		vbox.add_child(card_view)
		vbox.add_child(btn)
		cards_container.add_child(vbox)
		card_view.setup(card_data)

func _on_hp_selected() -> void:
	GameState.max_hp += 20
	GameState.current_hp = min(GameState.current_hp + 20, GameState.max_hp)
	choice_made.emit()
	queue_free()

func _on_card_selected(card_data: CardData) -> void:
	GameState.add_card(card_data)
	choice_made.emit()
	queue_free()
