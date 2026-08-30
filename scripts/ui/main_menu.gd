class_name MainMenu
extends Control

func _ready() -> void:
	$Center/VBox/StartButton.pressed.connect(_on_start)
	$Center/VBox/QuitButton.pressed.connect(func(): get_tree().quit())

func _on_start() -> void:
	GameState.reset()
	_build_starter_deck()
	RunManager.start_run()
	get_tree().change_scene_to_file("res://scenes/layer/layer_effect.tscn")

func _build_starter_deck() -> void:
	var strike := CardDatabase.get_card("strike")
	var defend := CardDatabase.get_card("defend")
	var sleep  := CardDatabase.get_card("sleep")
	assert(strike != null, "CardDatabase 缺少 'strike' — 请先注册卡牌")
	assert(defend != null, "CardDatabase 缺少 'defend'")
	assert(sleep  != null, "CardDatabase 缺少 'sleep'")
	for _i in range(5):
		GameState.add_card(strike)
	for _i in range(5):
		GameState.add_card(defend)
	GameState.add_card(sleep)
