class_name BattleUI
extends Control

@onready var enemy_area: HBoxContainer = $EnemyArea
@onready var hand_area: HBoxContainer = $HandArea
@onready var hp_label: Label = $PlayerArea/HPLabel
@onready var stats_label: Label = $PlayerArea/StatsLabel
@onready var player_status_label: Label = $PlayerArea/StatusLabel
@onready var energy_label: Label = $EnergyLabel
@onready var draw_label: Label = $DeckArea/DrawLabel
@onready var discard_label: Label = $DeckArea/DiscardLabel
@onready var layer_banner: Label = $LayerEffectBanner
@onready var end_turn_button: Button = $EndTurnButton

const CardViewScene = preload("res://scenes/ui/card_view.tscn")
const EnemyViewScene = preload("res://scenes/battle/enemy_view.tscn")

func _ready() -> void:
	_connect_signals()
	_setup_layer_banner()
	_setup_relic_bar()
	_setup_pile_buttons()
	BattleManager.start_battle(_get_enemies_for_node())
	_setup_enemies()
	# 同步初始 HP 显示（层效果可能已修改 max_hp）
	_on_player_hp_changed(GameState.current_hp)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_try_start_card_drag(event.global_position)
		else:
			_try_end_card_drag()

func _try_start_card_drag(gpos: Vector2) -> void:
	for card_view in hand_area.get_children():
		var cv := card_view as CardView
		if cv == null:
			continue
		if cv.get_global_rect().has_point(gpos):
			cv._start_drag()
			get_viewport().set_input_as_handled()
			return

func _try_end_card_drag() -> void:
	for child in get_tree().get_root().get_children():
		var cv := child as CardView
		if cv != null and cv.is_dragging:
			cv._end_drag()
			return
	for card_view in hand_area.get_children():
		var cv := card_view as CardView
		if cv != null and cv.is_dragging:
			cv._end_drag()
			return

const HandPickScene = preload("res://scenes/ui/hand_pick.tscn")

func _connect_signals() -> void:
	BattleManager.hand_updated.connect(_on_hand_updated)
	BattleManager.player_hp_changed.connect(_on_player_hp_changed)
	BattleManager.enemy_hp_changed.connect(_on_enemy_hp_changed)
	BattleManager.energy_changed.connect(_on_energy_changed)
	BattleManager.battle_ended.connect(_on_battle_ended)
	BattleManager.status_effects_changed.connect(_on_status_effects_changed)
	BattleManager.enemy_spawned.connect(_on_enemy_spawned)
	BattleManager.omniscience_draw_requested.connect(_on_omniscience_draw_requested)
	BattleManager.pick_from_draw_requested.connect(_on_pick_from_draw_requested)
	BattleManager.enemy_removed.connect(_on_enemy_removed)
	end_turn_button.pressed.connect(BattleManager.end_player_turn)

func _on_omniscience_draw_requested(pool: Array, count: int) -> void:
	var overlay := HandPickScene.instantiate()
	add_child(overlay)
	overlay.setup(pool, count, "全知：从全部卡牌中选择 %d 张作为手牌" % count)
	overlay.picks_done.connect(func(chosen): BattleManager.finish_omniscience_draw(chosen))

func _on_pick_from_draw_requested(pool: Array, count: int) -> void:
	var overlay := HandPickScene.instantiate()
	add_child(overlay)
	overlay.setup(pool, count, "先知：从抽牌堆中选择1张加入手牌")
	overlay.picks_done.connect(func(chosen): BattleManager.finish_pick_from_draw(chosen))

func _on_enemy_removed(instance: EnemyInstance) -> void:
	for child in enemy_area.get_children():
		var ev := child as EnemyView
		if ev != null and ev.enemy_instance == instance:
			ev.queue_free()
			break

func _setup_relic_bar() -> void:
	if GameState.relics.is_empty():
		return
	var bar := HBoxContainer.new()
	bar.anchor_left   = 0.0
	bar.anchor_right  = 1.0
	bar.anchor_top    = 0.0
	bar.anchor_bottom = 0.0
	bar.offset_top    = 40.0
	bar.offset_bottom = 64.0
	bar.offset_left   = 8.0
	bar.offset_right  = -8.0
	bar.add_theme_constant_override("separation", 12)
	add_child(bar)
	for relic in GameState.relics:
		var lbl := Label.new()
		lbl.text = "[%s]" % relic.relic_name
		lbl.tooltip_text = "%s\n%s" % [relic.relic_name, relic.description]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		bar.add_child(lbl)

## 将抽/弃牌 Label 替换为可点击 Button，点击后弹出牌堆面板
func _setup_pile_buttons() -> void:
	var deck_area: HBoxContainer = $DeckArea
	# 移除原 Label，添加 Button（同步完成，不需要 await）
	draw_label.get_parent().remove_child(draw_label)
	draw_label.queue_free()
	discard_label.get_parent().remove_child(discard_label)
	discard_label.queue_free()

	var draw_btn := Button.new()
	draw_btn.name = "DrawBtn"
	draw_btn.text = "抽: 0"
	draw_btn.flat = true
	draw_btn.pressed.connect(func(): _show_pile_panel(BattleManager.draw_pile, "抽牌堆", true))
	deck_area.add_child(draw_btn)

	var discard_btn := Button.new()
	discard_btn.name = "DiscardBtn"
	discard_btn.text = "弃: 0"
	discard_btn.flat = true
	discard_btn.pressed.connect(func(): _show_pile_panel(BattleManager.discard_pile, "弃牌堆", false))
	deck_area.add_child(discard_btn)

## 弹出牌堆查看面板（draw_pile 按稀有度排序，discard_pile 原序）
func _show_pile_panel(pile: Array, title: String, sort_by_rarity: bool) -> void:
	# 防重复打开
	var existing := get_node_or_null("PilePanel")
	if existing:
		existing.queue_free()

	var panel := Panel.new()
	panel.name = "PilePanel"
	panel.size = Vector2(700, 420)
	panel.position = Vector2(150, 80)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 8; vbox.offset_top = 8
	vbox.offset_right = -8; vbox.offset_bottom = -8
	panel.add_child(vbox)

	# 标题行
	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title_lbl := Label.new()
	title_lbl.text = "%s（%d张）" % [title, pile.size()]
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 16)
	header.add_child(title_lbl)
	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(panel.queue_free)
	header.add_child(close_btn)

	# 滚动区域
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	scroll.add_child(flow)

	# 排列卡牌
	var display_pile: Array = pile.duplicate()
	if sort_by_rarity:
		display_pile.sort_custom(func(a: CardData, b: CardData) -> bool:
			return int(b.rarity) < int(a.rarity))
	for card in display_pile:
		var card_lbl := Label.new()
		card_lbl.text = "[%s]\n%s" % [card.card_name, card.description]
		card_lbl.custom_minimum_size = Vector2(120, 60)
		card_lbl.add_theme_font_size_override("font_size", 10)
		card_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var bg := _rarity_color(card.rarity)
		card_lbl.modulate = bg
		flow.add_child(card_lbl)

func _rarity_color(r: Enums.Rarity) -> Color:
	match r:
		Enums.Rarity.RARE:      return Color(0.4, 0.7, 1.0)
		Enums.Rarity.EPIC:      return Color(0.8, 0.4, 1.0)
		Enums.Rarity.LEGENDARY: return Color(1.0, 0.8, 0.2)
		_: return Color.WHITE

func _setup_layer_banner() -> void:
	match GameState.layer_effect:
		Enums.LayerEffect.TOGETHER: layer_banner.text = "与我同去"
		Enums.LayerEffect.ECHO: layer_banner.text = "回响形态"
		Enums.LayerEffect.UNDYING: layer_banner.text = "至死不休"
		_: layer_banner.text = ""

func _setup_enemies() -> void:
	for enemy_inst in BattleManager.enemies:
		var view := EnemyViewScene.instantiate()
		enemy_area.add_child(view)
		view.setup(enemy_inst)

func _get_enemies_for_node() -> Array:
	var node_type := RunManager.get_current_node()
	match node_type:
		Enums.NodeType.ELITE:
			return [EnemyDatabase.create_instance(EnemyDatabase.get_random_elite_id())]
		Enums.NodeType.BOSS:
			var boss_id := "nightmare" if _has_big_dream() else "sleeping_lord"
			return [EnemyDatabase.create_instance(boss_id)]
		_:
			var group := EnemyDatabase.get_random_battle_group()
			var result: Array = []
			for id in group:
				result.append(EnemyDatabase.create_instance(id))
			return result

## 检查是否触发隐藏 BOSS（大梦已上交）
func _has_big_dream() -> bool:
	return RunManager.big_dream_submitted

func _on_enemy_spawned(instance: EnemyInstance) -> void:
	var view := EnemyViewScene.instantiate()
	enemy_area.add_child(view)
	view.setup(instance)

func _on_status_effects_changed() -> void:
	player_status_label.text = _format_statuses(GameState.status_effects)
	for child in enemy_area.get_children():
		var ev := child as EnemyView
		if ev != null:
			ev.update_statuses()
	# 噩梦状态：刷新手牌显示（显示"???"或恢复正常）
	for card_view in hand_area.get_children():
		var cv := card_view as CardView
		if cv != null:
			cv.refresh_nightmare_display()

func _format_statuses(effects: Array) -> String:
	var parts: PackedStringArray = []
	for s in effects:
		parts.append(_status_name(s.effect_type))
	return "  ".join(parts)

func _status_name(type: Enums.StatusEffectType) -> String:
	match type:
		Enums.StatusEffectType.CORRUPTION: return "腐化"
		Enums.StatusEffectType.WEAK:       return "虚弱"
		Enums.StatusEffectType.SLEEP:      return "沉睡"
		Enums.StatusEffectType.DROWSY:     return "困倦"
		Enums.StatusEffectType.NIGHTMARE:  return "噩梦"
	return ""

func _on_hand_updated(new_hand: Array) -> void:
	stats_label.text = "ATK:%d DEF:%d" % [GameState.attack, GameState.defense + BattleManager.current_round_block]
	for child in hand_area.get_children():
		child.queue_free()
	for card_data in new_hand:
		var view := CardViewScene.instantiate()
		hand_area.add_child(view)
		view.setup(card_data)
		view.card_released_on_target.connect(_on_card_released)

func _on_card_released(card_view: Control, target: Object) -> void:
	BattleManager.play_card(card_view.card_data, target)

func _on_player_hp_changed(new_hp: int) -> void:
	hp_label.text = "%d / %d" % [new_hp, GameState.max_hp]
	stats_label.text = "ATK:%d DEF:%d" % [GameState.attack, GameState.defense + BattleManager.current_round_block]

func _on_enemy_hp_changed(enemy: EnemyInstance, new_hp: int) -> void:
	for child in enemy_area.get_children():
		var ev := child as EnemyView
		if ev != null and ev.enemy_instance == enemy:
			ev.update_hp(new_hp)
			ev.update_stats()
			ev.update_intent()

func _on_energy_changed(current: int, maximum: int) -> void:
	energy_label.text = "⚡ %d/%d" % [current, maximum]
	# 更新抽/弃牌堆按钮文字
	var draw_btn := $DeckArea.get_node_or_null("DrawBtn")
	var discard_btn := $DeckArea.get_node_or_null("DiscardBtn")
	if draw_btn:
		draw_btn.text = "抽: %d" % BattleManager.draw_pile.size()
	if discard_btn:
		discard_btn.text = "弃: %d" % BattleManager.discard_pile.size()

func _on_battle_ended(player_won: bool) -> void:
	if player_won:
		_handle_victory()
	else:
		get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")

var _victory_node_type: Enums.NodeType = Enums.NodeType.BATTLE
var _old_level: int = 1

const CardRewardScene = preload("res://scenes/ui/card_reward.tscn")
const EpicCardChoiceScene = preload("res://scenes/ui/epic_card_choice.tscn")

func _handle_victory() -> void:
	_victory_node_type = RunManager.get_current_node()
	_old_level = GameState.level
	match _victory_node_type:
		Enums.NodeType.BATTLE, Enums.NodeType.QUESTION:
			GameState.add_experience(8)
			GameState.gold += randi_range(10, 20)
		Enums.NodeType.ELITE:
			GameState.add_experience(12)
			GameState.gold += randi_range(20, 40)
		Enums.NodeType.BOSS:
			GameState.add_experience(16)
			GameState.gold += 50
			get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
			return
	_show_card_reward()

func _show_card_reward() -> void:
	var overlay := CardRewardScene.instantiate()
	add_child(overlay)
	overlay.setup(_victory_node_type)
	overlay.reward_done.connect(_on_card_reward_done)

func _on_card_reward_done() -> void:
	if GameState.level >= 4 and _old_level < 4:
		_show_epic_card_choice()
		return
	RunManager.advance_node()
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _show_epic_card_choice() -> void:
	var overlay := EpicCardChoiceScene.instantiate()
	add_child(overlay)
	overlay.choice_made.connect(_on_epic_card_chosen)

func _on_epic_card_chosen() -> void:
	RunManager.advance_node()
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")
