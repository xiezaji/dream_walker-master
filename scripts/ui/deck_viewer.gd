extends CanvasLayer

## 卡组查看器 AutoLoad
## 在所有场景顶层显示右上角按钮，可随时打开/关闭卡组面板

const CardViewScene = preload("res://scenes/ui/card_view.tscn")

var _panel: Panel
var _scroll: ScrollContainer
var _grid: HFlowContainer
var _toggle_btn: Button
var _is_open: bool = false

## 删除模式：true 时点卡牌触发删除而非关闭
var delete_mode: bool = false
signal card_deleted(card: CardData)

func _ready() -> void:
	layer = 100  # 始终在最顶层

	# 右上角按钮
	_toggle_btn = Button.new()
	_toggle_btn.text = "卡组"
	_toggle_btn.size = Vector2(70, 32)
	_toggle_btn.position = Vector2(1200, 8)
	_toggle_btn.pressed.connect(_toggle_panel)
	add_child(_toggle_btn)

	# 卡组面板
	_panel = Panel.new()
	_panel.size = Vector2(900, 500)
	_panel.position = Vector2(190, 50)
	_panel.visible = false
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 10
	vbox.offset_top = 10
	vbox.offset_right = -10
	vbox.offset_bottom = -10
	_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "当前卡组"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.text = "✕"
	close_btn.pressed.connect(_toggle_panel)
	header.add_child(close_btn)

	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(_scroll)

	_grid = HFlowContainer.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll.add_child(_grid)


func _toggle_panel() -> void:
	_is_open = !_is_open
	_panel.visible = _is_open
	if _is_open:
		_refresh()

func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	await get_tree().process_frame  # 等待 queue_free 生效

	for card in GameState.deck:
		var card_view := CardViewScene.instantiate()
		card_view.mouse_filter = Control.MOUSE_FILTER_STOP
		_grid.add_child(card_view)
		card_view.setup(card)
		if delete_mode:
			var btn := Button.new()
			btn.text = "删除"
			btn.modulate = Color(1, 0.4, 0.4)
			btn.pressed.connect(_on_delete_card.bind(card, card_view.get_parent()))
			# 把卡牌和按钮放进一个小容器
			var card_wrap := VBoxContainer.new()
			_grid.remove_child(card_view)
			card_wrap.add_child(card_view)
			card_wrap.add_child(btn)
			_grid.add_child(card_wrap)

func _on_delete_card(card: CardData, _container: Node) -> void:
	GameState.remove_card(card)
	card_deleted.emit(card)
	delete_mode = false
	_toggle_panel()  # 关闭面板

## 外部调用：进入删除模式并打开面板
func open_delete_mode() -> void:
	delete_mode = true
	_is_open = false
	_toggle_panel()
