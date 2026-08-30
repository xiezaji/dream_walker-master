class_name BoonSelectUI
extends Control

const ALL_BOONS := [
	{
		"type": Enums.BoonType.DELETE_CARD,
		"name": "删除卡牌",
		"desc": "从牌组中永久删除一张卡牌"
	},
	{
		"type": Enums.BoonType.RARE_CARD,
		"name": "稀有卡牌",
		"desc": "从三张稀有卡牌中选择一张加入牌组"
	},
	{
		"type": Enums.BoonType.RANDOM_RELIC,
		"name": "随机遗物",
		"desc": "获得一件随机遗物"
	},
	{
		"type": Enums.BoonType.CHOOSE_LAYER,
		"name": "自选层效果",
		"desc": "重新选择本层效果"
	},
	{
		"type": Enums.BoonType.MAX_HP,
		"name": "提升生命",
		"desc": "最大生命值+20"
	}
]

@onready var options_container: HBoxContainer = $OptionsContainer
var _big_dream_btn: Button = null

func _ready() -> void:
	var pool := ALL_BOONS.duplicate()
	pool.shuffle()
	var shown := pool.slice(0, 3)
	var cards := options_container.get_children()
	for i in range(cards.size()):
		var boon: Dictionary = shown[i]
		cards[i].get_node("BoonName").text = boon.name
		cards[i].get_node("BoonDesc").text = boon.desc
		cards[i].get_node("SelectButton").pressed.connect(_on_boon_selected.bind(boon.type))
	# 第二次赐福节点（列6）且持有大梦：显示上交选项
	if RunManager.current_col == 6 and _has_big_dream():
		_add_big_dream_option()

func _has_big_dream() -> bool:
	for card in GameState.deck:
		if card.id == "big_dream":
			return true
	return false

func _add_big_dream_option() -> void:
	var btn := Button.new()
	btn.text = "✦ 上交「大梦」→ 将BOSS替换为隐藏BOSS「梦魇」"
	btn.add_theme_font_size_override("font_size", 18)
	# 锚定到屏幕底部居中
	btn.anchor_left   = 0.1
	btn.anchor_right  = 0.9
	btn.anchor_top    = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_top    = -60.0
	btn.offset_bottom = -10.0
	btn.pressed.connect(_on_big_dream_submitted)
	add_child(btn)
	_big_dream_btn = btn

func _show_card_obtained(card: CardData) -> void:
	var popup := AcceptDialog.new()
	popup.title = "获得卡牌"
	popup.dialog_text = "「%s」已加入你的牌组！\n%s" % [card.card_name, card.description]
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(func():
		RunManager.advance_node()
		get_tree().change_scene_to_file("res://scenes/map/map.tscn"))
	popup.canceled.connect(func():
		RunManager.advance_node()
		get_tree().change_scene_to_file("res://scenes/map/map.tscn"))

func _on_boon_selected(boon_type: Enums.BoonType) -> void:
	if boon_type == Enums.BoonType.CHOOSE_LAYER:
		get_tree().change_scene_to_file("res://scenes/layer/layer_effect.tscn")
		return
	if boon_type == Enums.BoonType.RARE_CARD:
		_apply_rare_card()
		return
	if boon_type == Enums.BoonType.DELETE_CARD:
		DeckViewer.card_deleted.connect(_on_boon_delete_done, CONNECT_ONE_SHOT)
		DeckViewer.open_delete_mode()
		return
	if boon_type == Enums.BoonType.RANDOM_RELIC:
		_apply_boon(boon_type)
		return  # 由 _show_relic_obtained 弹窗回调跳图
	_apply_boon(boon_type)
	RunManager.advance_node()
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _on_boon_delete_done(_card: CardData) -> void:
	RunManager.advance_node()
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")

func _on_big_dream_submitted() -> void:
	# 从牌组移除大梦，标记已上交
	for card in GameState.deck:
		if card.id == "big_dream":
			GameState.deck.erase(card)
			break
	RunManager.big_dream_submitted = true
	# 不跳图，禁用按钮让玩家继续选赐福
	if _big_dream_btn:
		_big_dream_btn.disabled = true
		_big_dream_btn.text = "✓ 大梦已上交（BOSS将替换为梦魇）"

const CardRewardScene = preload("res://scenes/ui/card_reward.tscn")

func _apply_rare_card() -> void:
	var rare_cards := CardDatabase.get_by_rarity(Enums.Rarity.RARE)
	rare_cards.shuffle()
	var pool: Array = rare_cards.slice(0, min(3, rare_cards.size()))
	if pool.is_empty():
		RunManager.mark_current_done()
		get_tree().change_scene_to_file("res://scenes/map/map.tscn")
		return
	var overlay := CardRewardScene.instantiate()
	add_child(overlay)
	overlay.setup_fixed_pool(pool)
	overlay.reward_done.connect(func():
		RunManager.mark_current_done()
		get_tree().change_scene_to_file("res://scenes/map/map.tscn"))

func _apply_boon(boon_type: Enums.BoonType) -> void:
	match boon_type:
		Enums.BoonType.DELETE_CARD:
			pass  # 由 _on_boon_selected 单独处理
		Enums.BoonType.RANDOM_RELIC:
			var rarity := Enums.RelicRarity.EPIC if randf() < 0.2 else Enums.RelicRarity.COMMON
			var relic := RelicDatabase.get_random(rarity)
			RelicManager.add_relic(relic)
			_show_relic_obtained(relic)
			return  # 由弹窗回调跳图
		Enums.BoonType.MAX_HP:
			GameState.max_hp += 20
			GameState.current_hp = min(GameState.current_hp + 20, GameState.max_hp)

func _show_relic_obtained(relic: RelicData) -> void:
	var popup := AcceptDialog.new()
	popup.title = "获得遗物"
	popup.dialog_text = "「%s」\n%s" % [relic.relic_name, relic.description]
	add_child(popup)
	popup.popup_centered()
	var go_map := func():
		RunManager.advance_node()
		get_tree().change_scene_to_file("res://scenes/map/map.tscn")
	popup.confirmed.connect(go_map)
	popup.canceled.connect(go_map)
