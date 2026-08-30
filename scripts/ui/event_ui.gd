class_name EventUI
extends Control

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var desc_label: Label = $Panel/VBox/DescLabel
@onready var option_a: Button = $Panel/VBox/OptionA
@onready var option_b: Button = $Panel/VBox/OptionB

var _event_type: Enums.EventType

func _ready() -> void:
	_event_type = RunManager.current_event
	_setup_event(_event_type)

func _setup_event(event_type: Enums.EventType) -> void:
	match event_type:
		Enums.EventType.SLEEPING_MERCHANT:
			title_label.text = "沉睡的商人"
			desc_label.text = "你发现一名沉睡的商人，身旁散落着金币。\n你可以悄悄拿走他的金钱，但这可能扰乱他的梦境……"
			option_a.text = "偷走金币（+50金，下场战斗防御-10）"
			option_b.text = "叫醒商人（获得1张随机普通卡）"
		Enums.EventType.WARM_BED:
			title_label.text = "温暖的被窝"
			desc_label.text = "路边有一张舒适的床，柔软的被子散发着暖意。\n躺下休息会让你恢复精力，但敌人可能趁机先发制人。"
			option_a.text = "躺下休息（恢复30%最大HP，下场敌人先手）"
			option_b.text = "继续前行（无效果）"
		Enums.EventType.FOUNTAIN_OF_FORGETTING:
			title_label.text = "遗忘之泉"
			desc_label.text = "一眼神秘的泉水泛着柔和的光芒。\n据说喝下泉水能让人遗忘过去的重担，换来新的力量。"
			option_a.text = "饮下泉水（随机删除1张牌，最大HP+10）"
			option_b.text = "离开（无效果）"

func _on_option_b_pressed() -> void:
	match _event_type:
		Enums.EventType.SLEEPING_MERCHANT:
			var common_cards := CardDatabase.get_by_rarity(Enums.Rarity.COMMON)
			if not common_cards.is_empty():
				common_cards.shuffle()
				var card := common_cards[0]
				GameState.add_card(card)
				_show_card_obtained(card)
				return
		Enums.EventType.WARM_BED, Enums.EventType.FOUNTAIN_OF_FORGETTING:
			pass  # 无效果
	RunManager.advance_node()
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _show_card_obtained(card: CardData) -> void:
	var popup := AcceptDialog.new()
	popup.title = "获得卡牌"
	popup.dialog_text = "「%s」已加入牌组！\n%s" % [card.card_name, card.description]
	add_child(popup)
	popup.popup_centered()
	var go_map := func():
		RunManager.advance_node()
		get_tree().change_scene_to_file("res://scenes/map/map.tscn")
	popup.confirmed.connect(go_map)
	popup.canceled.connect(go_map)

func _on_option_a_pressed() -> void:
	match _event_type:
		Enums.EventType.SLEEPING_MERCHANT:
			GameState.gold += 50
			GameState.next_battle_def_penalty = 10
		Enums.EventType.WARM_BED:
			var heal := int(GameState.max_hp * 0.3)
			GameState.current_hp = min(GameState.current_hp + heal, GameState.max_hp)
			GameState.next_battle_enemy_first = true
		Enums.EventType.FOUNTAIN_OF_FORGETTING:
			if not GameState.deck.is_empty():
				var idx := randi() % GameState.deck.size()
				GameState.deck.remove_at(idx)
			GameState.max_hp += 10
			GameState.current_hp = min(GameState.current_hp + 10, GameState.max_hp)
	RunManager.advance_node()
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")
