class_name CardRewardUI
extends Control

signal reward_done

@onready var cards_container: HBoxContainer = $Panel/VBox/CardsContainer
@onready var skip_button: Button = $Panel/VBox/SkipButton

const CardViewScene = preload("res://scenes/ui/card_view.tscn")

func setup(node_type: Enums.NodeType) -> void:
	var reward_cards := _generate_reward(node_type)
	_display_cards(reward_cards, true)

## 赐福稀有卡选择：显示固定牌池，不显示跳过按钮
func setup_fixed_pool(pool: Array) -> void:
	skip_button.visible = false
	_display_cards(pool, false)

func _display_cards(cards: Array, show_skip: bool) -> void:
	skip_button.visible = show_skip
	for card_data in cards:
		var vbox := VBoxContainer.new()
		var card_view := CardViewScene.instantiate()
		card_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var btn := Button.new()
		btn.text = "选择"
		btn.pressed.connect(_on_card_selected.bind(card_data))
		vbox.add_child(card_view)
		vbox.add_child(btn)
		cards_container.add_child(vbox)
		card_view.setup(card_data)  # 必须在加入场景树后调用，否则 @onready 未初始化

## 小怪：每张80%普通/20%稀有；精英：每张80%稀有/20%史诗
func _generate_reward(node_type: Enums.NodeType) -> Array[CardData]:
	var pool_main: Array[CardData]
	var pool_alt: Array[CardData]
	if node_type == Enums.NodeType.ELITE:
		pool_main = CardDatabase.get_by_rarity(Enums.Rarity.RARE)
		pool_alt  = CardDatabase.get_by_rarity(Enums.Rarity.EPIC)
	else:
		pool_main = CardDatabase.get_by_rarity(Enums.Rarity.COMMON)
		pool_alt  = CardDatabase.get_by_rarity(Enums.Rarity.RARE)

	var result: Array[CardData] = []
	var used_ids: Array[String] = []
	for _i in range(3):
		var pool := pool_alt if randf() < 0.2 else pool_main
		pool = pool.filter(func(c): return c.id not in used_ids)
		if pool.is_empty():
			pool = pool_main.filter(func(c): return c.id not in used_ids)
		if pool.is_empty():
			break
		pool.shuffle()
		result.append(pool[0])
		used_ids.append(pool[0].id)
	return result

func _on_card_selected(card_data: CardData) -> void:
	GameState.add_card(card_data)
	reward_done.emit()
	queue_free()

func _on_skip_pressed() -> void:
	reward_done.emit()
	queue_free()
