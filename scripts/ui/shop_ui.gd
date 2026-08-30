class_name ShopUI
extends Control

const DELETE_COST := 50
const CardViewScene = preload("res://scenes/ui/card_view.tscn")

@onready var gold_label: Label = $MainVBox/GoldLabel
@onready var common_row: HBoxContainer = $MainVBox/ScrollContainer/ContentVBox/CommonSection/ItemsRow
@onready var rare_row: HBoxContainer = $MainVBox/ScrollContainer/ContentVBox/RareSection/ItemsRow
@onready var relic_row: HBoxContainer = $MainVBox/ScrollContainer/ContentVBox/RelicSection/ItemsRow
@onready var ending_row: HBoxContainer = $MainVBox/ScrollContainer/ContentVBox/EndingSection/ItemsRow
@onready var delete_button: Button = $MainVBox/ScrollContainer/ContentVBox/DeleteSection/DeleteButton
@onready var leave_button: Button = $MainVBox/BottomBar/LeaveButton

var _delete_used: bool = false

func _ready() -> void:
	_update_gold()
	_populate_shop()
	delete_button.pressed.connect(_on_delete_pressed)
	leave_button.pressed.connect(_on_leave)

func _update_gold() -> void:
	gold_label.text = "金币: %d" % GameState.gold

func _populate_shop() -> void:
	var commons := CardDatabase.get_by_rarity(Enums.Rarity.COMMON)
	commons.shuffle()
	var rares := CardDatabase.get_by_rarity(Enums.Rarity.RARE)
	rares.shuffle()
	_add_shop_items(common_row, commons.slice(0, 3), 40, 60)
	_add_shop_items(rare_row, rares.slice(0, 3), 60, 80)
	# 结局卡大梦（固定20金）
	var big_dream := CardDatabase.get_card("big_dream")
	if big_dream != null:
		_add_shop_items(ending_row, [big_dream], 20, 20)
	# 遗物：随机2普通 + 1史诗
	var common_relics := RelicDatabase.get_all_by_rarity(Enums.RelicRarity.COMMON)
	common_relics.shuffle()
	var epic_relics := RelicDatabase.get_all_by_rarity(Enums.RelicRarity.EPIC)
	epic_relics.shuffle()
	_add_relic_items(relic_row, common_relics.slice(0, 2), 100, 150)
	_add_relic_items(relic_row, epic_relics.slice(0, 1), 200, 210)

func _add_shop_items(row: HBoxContainer, cards: Array, price_min: int, price_max: int) -> void:
	for card in cards:
		var price: int = randi_range(price_min, price_max)
		var container := VBoxContainer.new()
		var view := CardViewScene.instantiate()
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var price_label := Label.new()
		price_label.text = "%d 金" % price
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var buy_btn := Button.new()
		buy_btn.text = "购买"
		buy_btn.disabled = GameState.gold < price
		buy_btn.pressed.connect(_on_buy.bind(card, price, buy_btn))
		container.add_child(view)
		container.add_child(price_label)
		container.add_child(buy_btn)
		row.add_child(container)
		view.setup(card)

func _on_buy(card: CardData, price: int, btn: Button) -> void:
	if not GameState.spend_gold(price):
		return
	GameState.add_card(card)
	btn.disabled = true
	btn.text = "已购买"
	_update_gold()
	_show_obtained("获得卡牌", "「%s」已加入牌组！\n%s" % [card.card_name, card.description])

func _on_delete_pressed() -> void:
	if _delete_used or GameState.gold < DELETE_COST or GameState.deck.is_empty():
		return
	GameState.spend_gold(DELETE_COST)
	_update_gold()
	_delete_used = true
	delete_button.disabled = true
	delete_button.text = "已使用（本层限1次）"
	# 打开卡组删除模式让玩家选择要删除的牌
	DeckViewer.card_deleted.connect(_on_card_deleted, CONNECT_ONE_SHOT)
	DeckViewer.open_delete_mode()

func _on_card_deleted(_card: CardData) -> void:
	pass  # 删除已在 DeckViewer 内完成，无需额外处理

func _add_relic_items(row: HBoxContainer, relics: Array, price_min: int, price_max: int) -> void:
	for relic in relics:
		var price: int = randi_range(price_min, price_max)
		var container := VBoxContainer.new()
		var name_lbl := Label.new()
		name_lbl.text = relic.relic_name
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var desc_lbl := Label.new()
		desc_lbl.text = relic.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.custom_minimum_size = Vector2(120, 0)
		var price_lbl := Label.new()
		price_lbl.text = "%d 金" % price
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var buy_btn := Button.new()
		buy_btn.text = "购买"
		buy_btn.disabled = GameState.gold < price
		buy_btn.pressed.connect(_on_buy_relic.bind(relic, price, buy_btn))
		container.add_child(name_lbl)
		container.add_child(desc_lbl)
		container.add_child(price_lbl)
		container.add_child(buy_btn)
		row.add_child(container)

func _on_buy_relic(relic: RelicData, price: int, btn: Button) -> void:
	if not GameState.spend_gold(price):
		return
	RelicManager.add_relic(relic)
	btn.disabled = true
	btn.text = "已购买"
	_update_gold()
	_show_obtained("获得遗物", "「%s」\n%s" % [relic.relic_name, relic.description])

func _show_obtained(title: String, text: String) -> void:
	var popup := AcceptDialog.new()
	popup.title = title
	popup.dialog_text = text
	add_child(popup)
	popup.popup_centered()
	popup.confirmed.connect(popup.queue_free)
	popup.canceled.connect(popup.queue_free)

func _on_leave() -> void:
	RunManager.mark_current_done()
	get_tree().change_scene_to_file("res://scenes/map/map.tscn")
