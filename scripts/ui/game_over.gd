class_name GameOver
extends Control

func _ready() -> void:
	var won := GameState.current_hp > 0
	$ResultLabel.text = "胜利！" if won else "失败..."
	$StatsLabel.text = "剩余 HP: %d" % GameState.current_hp
	$RestartButton.pressed.connect(_on_restart)

func _on_restart() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
