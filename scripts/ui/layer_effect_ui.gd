class_name LayerEffectUI
extends Control

const EFFECTS := [
	{
		"effect": Enums.LayerEffect.TOGETHER,
		"name": "与我同去",
		"desc": "玩家和敌怪的血量变为50%"
	},
	{
		"effect": Enums.LayerEffect.ECHO,
		"name": "回响形态",
		"desc": "敌怪每回合行动两次"
	},
	{
		"effect": Enums.LayerEffect.UNDYING,
		"name": "至死不休",
		"desc": "玩家生命上限翻倍，但敌怪死亡时失去10点生命"
	}
]

@onready var options: VBoxContainer = $OptionsContainer

func _ready() -> void:
	var is_new_game: bool = RunManager.columns.is_empty()
	if is_new_game:
		# 新游戏：随机分配层效果，不显示选择界面
		var random_data: Dictionary = EFFECTS[randi() % EFFECTS.size()]
		_on_option_selected.call_deferred(random_data.effect)
		return
	# 赐福"自选层效果"：显示三选一界面
	var buttons := options.get_children()
	for i in range(buttons.size()):
		var data: Dictionary = EFFECTS[i]
		buttons[i].text = "%s\n%s" % [data.name, data.desc]
		buttons[i].pressed.connect(_on_option_selected.bind(data.effect))

func _on_option_selected(effect: Enums.LayerEffect) -> void:
	# 若地图还未生成（columns为空），则是首次开局；否则是赐福"自选层效果"
	var is_new_game: bool = RunManager.columns.is_empty()
	# 还原旧层效果对属性的影响
	if not is_new_game:
		match GameState.layer_effect:
			Enums.LayerEffect.TOGETHER:
				GameState.max_hp = min(GameState.max_hp * 2, 999)
				GameState.current_hp = min(GameState.current_hp * 2, GameState.max_hp)
			Enums.LayerEffect.UNDYING:
				GameState.max_hp = max(1, int(GameState.max_hp * 0.5))
				GameState.current_hp = max(1, int(GameState.current_hp * 0.5))

	GameState.layer_effect = effect
	# 应用新层效果
	match effect:
		Enums.LayerEffect.TOGETHER:
			GameState.max_hp = max(1, int(GameState.max_hp * 0.5))
			GameState.current_hp = max(1, int(GameState.current_hp * 0.5))
		Enums.LayerEffect.UNDYING:
			GameState.max_hp *= 2
			GameState.current_hp *= 2

	if is_new_game:
		RunManager.start_run()
	else:
		RunManager.mark_current_done()
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")
