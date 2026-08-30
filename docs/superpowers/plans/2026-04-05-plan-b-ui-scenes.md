# 子计划 B：UI + 场景流程

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现所有游戏场景和 UI 组件，使玩家能够从主菜单开始完整体验一局 Demo（选层效果→地图→战斗→商店→Boss→胜负结算）。

**Architecture:** 每个游戏状态对应一个独立场景，通过 `get_tree().change_scene_to_file()` 切换；CardView 作为可复用组件支持拖拽出牌；所有 UI 通过 BattleManager/GameState/RunManager 的信号更新，不直接持有逻辑引用。

**Tech Stack:** Godot 4.x GDScript，场景用编辑器搭建（本计划描述节点树结构，具体布局由美术调整）

**前置条件：** 子计划 A 全部完成（数据结构、AutoLoad、BattleManager、CardEffectExecutor 均可用）

---

## 文件清单

| 路径 | 职责 |
|---|---|
| `scenes/ui/card_view.tscn` + `scripts/ui/card_view.gd` | 单张卡牌可交互组件 |
| `scenes/battle/battle.tscn` + `scripts/ui/battle_ui.gd` | 战斗主场景 |
| `scenes/layer/layer_effect.tscn` + `scripts/ui/layer_effect_ui.gd` | 层效果选择 |
| `scenes/boon/boon_select.tscn` + `scripts/ui/boon_select_ui.gd` | 赐福选择 |
| `scenes/map/map.tscn` + `scripts/ui/map_ui.gd` | 地图导航 |
| `scenes/shop/shop.tscn` + `scripts/ui/shop_ui.gd` | 商店 |
| `scenes/main_menu.tscn` + `scripts/ui/main_menu.gd` | 主菜单 |
| `scenes/ui/game_over.tscn` + `scripts/ui/game_over.gd` | 胜负结算 |

---

## Task 1：CardView 可复用组件

**Files:**
- Create: `scenes/ui/card_view.tscn`
- Create: `scripts/ui/card_view.gd`

- [ ] **Step 1：在编辑器中创建 scenes/ui/card_view.tscn**

  节点树：
  ```
  CardView (Control, 自定义最小尺寸 120×180)
  ├── CardBG (Panel)
  ├── CostLabel (Label)        # 左上角费用
  ├── NameLabel (Label)        # 卡牌名称
  ├── TypeLabel (Label)        # 类型（攻击/技能/能力）
  ├── DescLabel (RichTextLabel) # 效果描述，支持 BBCode 高亮
  └── HighlightBorder (ColorRect) # 悬停/选中高亮，默认隐藏
  ```
  CardBG 覆盖整个 Control，HighlightBorder modulate.a = 0.3，默认 visible = false。

- [ ] **Step 2：创建 scripts/ui/card_view.gd 并附加到 CardView 根节点**

  ```gdscript
  extends Control

  signal card_clicked(card_view: Control)
  signal card_released_on_target(card_view: Control, target: Object)

  var card_data: CardData = null
  var is_dragging: bool = false
  var _drag_offset: Vector2 = Vector2.ZERO
  var _original_position: Vector2 = Vector2.ZERO
  var _original_parent: Node = null
  var _original_index: int = 0

  @onready var cost_label: Label = $CostLabel
  @onready var name_label: Label = $NameLabel
  @onready var type_label: Label = $TypeLabel
  @onready var desc_label: RichTextLabel = $DescLabel
  @onready var highlight: ColorRect = $HighlightBorder

  func setup(data: CardData) -> void:
      card_data = data
      cost_label.text = str(data.cost) if data.cost >= 0 else "X"
      name_label.text = data.card_name
      type_label.text = _type_text(data.card_type)
      desc_label.text = data.description
      _set_rarity_color(data.rarity)

  func _type_text(t: Enums.CardType) -> String:
      match t:
          Enums.CardType.ATTACK: return "攻击"
          Enums.CardType.SKILL: return "技能"
          Enums.CardType.POWER: return "能力"
          Enums.CardType.CURSE: return "诅咒"
      return ""

  func _set_rarity_color(r: Enums.Rarity) -> void:
      var colors := {
          Enums.Rarity.STARTER: Color(0.7, 0.7, 0.7),
          Enums.Rarity.COMMON: Color(1, 1, 1),
          Enums.Rarity.RARE: Color(0.4, 0.7, 1.0),
          Enums.Rarity.EPIC: Color(0.8, 0.4, 1.0),
          Enums.Rarity.LEGENDARY: Color(1.0, 0.8, 0.2)
      }
      $CardBG.modulate = colors.get(r, Color.WHITE)

  func _gui_input(event: InputEvent) -> void:
      if event is InputEventMouseButton:
          if event.button_index == MOUSE_BUTTON_LEFT:
              if event.pressed:
                  _start_drag(event.global_position)
              else:
                  _end_drag(event.global_position)
      elif event is InputEventMouseMotion and is_dragging:
          global_position = event.global_position - _drag_offset

  func _start_drag(gpos: Vector2) -> void:
      if BattleManager.current_phase != Enums.BattlePhase.PLAYER_TURN:
          return
      if card_data == null or BattleManager.current_energy < card_data.cost:
          return
      is_dragging = true
      _original_position = global_position
      _original_parent = get_parent()
      _original_index = get_index()
      _drag_offset = gpos - global_position
      scale = Vector2(1.1, 1.1)
      get_viewport().get_root().add_child(self)  # 移到顶层避免被裁切
      z_index = 100

  func _end_drag(gpos: Vector2) -> void:
      if not is_dragging:
          return
      is_dragging = false
      scale = Vector2.ONE
      z_index = 0

      # 检测落点是否在敌人身上
      var target := _find_enemy_at(gpos)
      if target != null or card_data.effects.any(func(e): return e.target == Enums.TargetType.ALL_ENEMIES):
          card_released_on_target.emit(self, target)
      else:
          _return_to_hand()

  func _return_to_hand() -> void:
      if _original_parent:
          _original_parent.add_child(self)
          _original_parent.move_child(self, _original_index)
      global_position = _original_position

  func _find_enemy_at(gpos: Vector2) -> Object:
      # 遍历场景中所有 EnemyView 节点，检查点是否在其 Rect 内
      var root := get_tree().current_scene
      for enemy_view in root.get_node("EnemyArea").get_children():
          if enemy_view.get_global_rect().has_point(gpos):
              return enemy_view.enemy_instance
      return null

  func set_highlighted(on: bool) -> void:
      highlight.visible = on
  ```

- [ ] **Step 3：验证**

  在 Godot 编辑器中运行 `scenes/ui/card_view.tscn` 作为当前场景，应看到空白卡牌框。

---

## Task 2：战斗场景（battle.tscn）

**Files:**
- Create: `scenes/battle/battle.tscn`
- Create: `scripts/ui/battle_ui.gd`
- Create: `scenes/battle/enemy_view.tscn`（敌人 UI 组件）

- [ ] **Step 1：在编辑器中创建 scenes/battle/enemy_view.tscn**

  ```
  EnemyView (Control, 最小尺寸 100×200)
  ├── EnemySprite (TextureRect)
  ├── HPBar (TextureProgressBar)
  ├── HPLabel (Label)           # "当前HP/最大HP"
  ├── IntentLabel (Label)       # 显示意图："⚔40" 或 "↓防御"
  └── StatsLabel (Label)        # DEF 值
  ```

  附加脚本 `scripts/ui/enemy_view.gd`：

  ```gdscript
  extends Control

  var enemy_instance: EnemyInstance = null

  @onready var hp_bar: TextureProgressBar = $HPBar
  @onready var hp_label: Label = $HPLabel
  @onready var intent_label: Label = $IntentLabel

  func setup(instance: EnemyInstance) -> void:
      enemy_instance = instance
      hp_bar.max_value = instance.data.max_hp
      update_hp(instance.current_hp)
      update_intent()

  func update_hp(new_hp: int) -> void:
      hp_bar.value = new_hp
      hp_label.text = "%d / %d" % [new_hp, enemy_instance.data.max_hp]

  func update_intent() -> void:
      var intent := enemy_instance.get_current_intent()
      if intent == null:
          intent_label.text = "?"
          return
      match intent.intent_type:
          Enums.IntentType.ATTACK:
              intent_label.text = "⚔ %d" % intent.value
          Enums.IntentType.DEBUFF:
              intent_label.text = "↓ 减益"
  ```

- [ ] **Step 2：在编辑器中创建 scenes/battle/battle.tscn**

  ```
  Battle (Node2D)
  ├── Background (ColorRect)           # 占位背景，颜色 #1a1a2e
  ├── EnemyArea (HBoxContainer)        # 顶部居中
  ├── PlayerArea (Control)             # 左下
  │   ├── PlayerSprite (ColorRect)     # 占位，60×80 绿色矩形
  │   ├── HPBar (TextureProgressBar)
  │   ├── HPLabel (Label)
  │   └── StatsLabel (Label)           # "ATK:60 DEF:50"
  ├── HandArea (HBoxContainer)         # 底部居中，separation=8
  ├── DeckArea (HBoxContainer)         # 右下角
  │   ├── DrawLabel (Label)            # "抽: N"
  │   └── DiscardLabel (Label)         # "弃: N"
  ├── EnergyLabel (Label)              # 左下，"⚡ 3/3"
  ├── EndTurnButton (Button)           # 右下，"结束回合"
  └── LayerEffectBanner (Label)        # 顶部，显示当前层效果名
  ```

- [ ] **Step 3：创建 scripts/ui/battle_ui.gd 并附加到 Battle 根节点**

  ```gdscript
  extends Node2D

  @onready var enemy_area: HBoxContainer = $EnemyArea
  @onready var hand_area: HBoxContainer = $HandArea
  @onready var hp_label: Label = $PlayerArea/HPLabel
  @onready var stats_label: Label = $PlayerArea/StatsLabel
  @onready var energy_label: Label = $EnergyLabel
  @onready var draw_label: Label = $DeckArea/DrawLabel
  @onready var discard_label: Label = $DeckArea/DiscardLabel
  @onready var layer_banner: Label = $LayerEffectBanner

  const CardViewScene = preload("res://scenes/ui/card_view.tscn")
  const EnemyViewScene = preload("res://scenes/battle/enemy_view.tscn")

  func _ready() -> void:
      _connect_signals()
      _setup_layer_banner()
      _setup_enemies()
      BattleManager.start_battle(_get_enemies_for_node())

  func _connect_signals() -> void:
      BattleManager.hand_updated.connect(_on_hand_updated)
      BattleManager.player_hp_changed.connect(_on_player_hp_changed)
      BattleManager.enemy_hp_changed.connect(_on_enemy_hp_changed)
      BattleManager.energy_changed.connect(_on_energy_changed)
      BattleManager.battle_ended.connect(_on_battle_ended)
      $EndTurnButton.pressed.connect(BattleManager.end_player_turn)

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
      # RunManager 决定当前节点类型，加载对应敌人数据
      var node_type := RunManager.get_current_node()
      match node_type:
          Enums.NodeType.ELITE:
              return [_make_enemy("elite")]
          Enums.NodeType.BOSS:
              return [_make_enemy("boss")]
          _:
              return [_make_enemy("slime")]

  func _make_enemy(id: String) -> EnemyInstance:
      var data := CardDatabase.get_card(id)  # 此处实际应从 EnemyDatabase 获取
      # 临时方案：直接 load .tres 文件
      var enemy_res := load("res://resources/enemies/%s.tres" % id) as EnemyData
      var inst := EnemyInstance.new()
      inst.setup(enemy_res)
      return inst

  func _on_hand_updated(new_hand: Array) -> void:
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
      stats_label.text = "ATK:%d DEF:%d" % [GameState.attack, GameState.defense]

  func _on_enemy_hp_changed(enemy_id: String, new_hp: int) -> void:
      for child in enemy_area.get_children():
          if child.enemy_instance.data.id == enemy_id:
              child.update_hp(new_hp)
              child.update_intent()

  func _on_energy_changed(current: int, maximum: int) -> void:
      energy_label.text = "⚡ %d/%d" % [current, maximum]
      draw_label.text = "抽: %d" % BattleManager.draw_pile.size()
      discard_label.text = "弃: %d" % BattleManager.discard_pile.size()

  func _on_battle_ended(player_won: bool) -> void:
      if player_won:
          _handle_victory()
      else:
          get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")

  func _handle_victory() -> void:
      var node_type := RunManager.get_current_node()
      match node_type:
          Enums.NodeType.BATTLE:
              GameState.add_experience(8)
              GameState.gold += 10
          Enums.NodeType.ELITE:
              GameState.add_experience(12)
              GameState.gold += 25
          Enums.NodeType.BOSS:
              GameState.add_experience(16)
              # 胜利：进入结算
              get_tree().change_scene_to_file("res://scenes/ui/game_over.tscn")
              return
      RunManager.advance_node()
      get_tree().change_scene_to_file("res://scenes/map/map.tscn")
  ```

- [ ] **Step 4：提交**

  ```bash
  git add scenes/battle/ scripts/ui/battle_ui.gd scripts/ui/enemy_view.gd scenes/ui/card_view.tscn scripts/ui/card_view.gd
  git commit -m "feat: CardView 拖拽组件和战斗场景 UI"
  ```

---

## Task 3：本层效果选择场景

**Files:**
- Create: `scenes/layer/layer_effect.tscn`
- Create: `scripts/ui/layer_effect_ui.gd`

- [ ] **Step 1：创建 scenes/layer/layer_effect.tscn**

  ```
  LayerEffect (Control)
  ├── Title (Label)              # "选择本层效果"
  └── OptionsContainer (VBoxContainer)
      ├── Option0 (Button)       # 动态设置文字
      ├── Option1 (Button)
      └── Option2 (Button)
  ```

- [ ] **Step 2：创建 scripts/ui/layer_effect_ui.gd 并附加到根节点**

  ```gdscript
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
          "desc": "玩家每张卡牌释放两次，敌怪每回合行动两次"
      },
      {
          "effect": Enums.LayerEffect.UNDYING,
          "name": "至死不休",
          "desc": "玩家生命上限翻倍，但敌怪死亡时失去10点生命"
      }
  ]

  @onready var options: VBoxContainer = $OptionsContainer

  func _ready() -> void:
      var buttons := options.get_children()
      for i in range(buttons.size()):
          var data := EFFECTS[i]
          buttons[i].text = "%s\n%s" % [data.name, data.desc]
          buttons[i].pressed.connect(_on_option_selected.bind(data.effect))

  func _on_option_selected(effect: Enums.LayerEffect) -> void:
      GameState.layer_effect = effect
      RunManager.start_run()
      get_tree().change_scene_to_file("res://scenes/map/map.tscn")
  ```

- [ ] **Step 3：提交**

  ```bash
  git add scenes/layer/ scripts/ui/layer_effect_ui.gd
  git commit -m "feat: 本层效果选择场景"
  ```

---

## Task 4：赐福选择场景

**Files:**
- Create: `scenes/boon/boon_select.tscn`
- Create: `scripts/ui/boon_select_ui.gd`

- [ ] **Step 1：创建 scenes/boon/boon_select.tscn**

  ```
  BoonSelect (Control)
  ├── Title (Label)              # "选择赐福"
  └── OptionsContainer (HBoxContainer)
      ├── BoonCard0 (Panel)
      │   ├── BoonName (Label)
      │   ├── BoonDesc (Label)
      │   └── SelectButton (Button)  # "选择"
      ├── BoonCard1 (Panel)
      │   └── ...（同上）
      └── BoonCard2 (Panel)
          └── ...（同上）
  ```

- [ ] **Step 2：创建 scripts/ui/boon_select_ui.gd 并附加到根节点**

  ```gdscript
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
          "desc": "从三张稀有卡中选择一张加入牌组"
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

  func _ready() -> void:
      var pool := ALL_BOONS.duplicate()
      pool.shuffle()
      var shown := pool.slice(0, 3)
      var cards := options_container.get_children()
      for i in range(cards.size()):
          var boon := shown[i]
          cards[i].get_node("BoonName").text = boon.name
          cards[i].get_node("BoonDesc").text = boon.desc
          cards[i].get_node("SelectButton").pressed.connect(_on_boon_selected.bind(boon.type))

  func _on_boon_selected(boon_type: Enums.BoonType) -> void:
      _apply_boon(boon_type)
      RunManager.advance_node()
      get_tree().change_scene_to_file("res://scenes/map/map.tscn")

  func _apply_boon(boon_type: Enums.BoonType) -> void:
      match boon_type:
          Enums.BoonType.DELETE_CARD:
              # 打开删牌 UI（简化版：显示牌组列表，点击删除）
              # Demo 阶段暂时跳过，直接前进
              pass
          Enums.BoonType.RARE_CARD:
              var rare_cards := CardDatabase.get_by_rarity(Enums.Rarity.RARE)
              rare_cards.shuffle()
              var chosen := rare_cards[0] if not rare_cards.is_empty() else null
              if chosen:
                  GameState.add_card(chosen)
          Enums.BoonType.RANDOM_RELIC:
              pass  # 遗物系统 Demo 阶段留空
          Enums.BoonType.CHOOSE_LAYER:
              get_tree().change_scene_to_file("res://scenes/layer/layer_effect.tscn")
              return
          Enums.BoonType.MAX_HP:
              GameState.max_hp += 20
              GameState.current_hp = min(GameState.current_hp + 20, GameState.max_hp)
  ```

- [ ] **Step 3：提交**

  ```bash
  git add scenes/boon/ scripts/ui/boon_select_ui.gd
  git commit -m "feat: 赐福选择场景（5选3）"
  ```

---

## Task 5：地图场景

**Files:**
- Create: `scenes/map/map.tscn`
- Create: `scripts/ui/map_ui.gd`

- [ ] **Step 1：创建 scenes/map/map.tscn**

  ```
  Map (Control)
  ├── Title (Label)              # "梦境行者 — 第一层"
  ├── PlayerInfo (HBoxContainer)
  │   ├── HPLabel (Label)
  │   ├── GoldLabel (Label)
  │   └── DeckLabel (Label)      # "牌组: N 张"
  ├── NodesContainer (HBoxContainer)  # 水平排列地图节点
  └── NextButton (Button)        # "前往下一节点"（显示节点类型名称）
  ```

- [ ] **Step 2：创建 scripts/ui/map_ui.gd 并附加到根节点**

  ```gdscript
  extends Control

  @onready var hp_label: Label = $PlayerInfo/HPLabel
  @onready var gold_label: Label = $PlayerInfo/GoldLabel
  @onready var deck_label: Label = $PlayerInfo/DeckLabel
  @onready var nodes_container: HBoxContainer = $NodesContainer
  @onready var next_button: Button = $NextButton

  const NODE_NAMES := {
      Enums.NodeType.BOON: "赐福",
      Enums.NodeType.BATTLE: "小怪",
      Enums.NodeType.ELITE: "精英",
      Enums.NodeType.BOSS: "BOSS",
      Enums.NodeType.SHOP: "商店",
      Enums.NodeType.QUESTION: "?"
  }

  func _ready() -> void:
      _update_player_info()
      _build_map_nodes()
      _update_next_button()
      next_button.pressed.connect(_on_next_pressed)

  func _update_player_info() -> void:
      hp_label.text = "HP: %d/%d" % [GameState.current_hp, GameState.max_hp]
      gold_label.text = "金: %d" % GameState.gold
      deck_label.text = "牌组: %d张" % GameState.deck.size()

  func _build_map_nodes() -> void:
      for child in nodes_container.get_children():
          child.queue_free()
      for i in range(RunManager.map_nodes.size()):
          var node_type := RunManager.map_nodes[i]
          var lbl := Label.new()
          lbl.text = NODE_NAMES.get(node_type, "?")
          if i == RunManager.current_node_index:
              lbl.modulate = Color.YELLOW
          elif i < RunManager.current_node_index:
              lbl.modulate = Color(0.5, 0.5, 0.5)
          nodes_container.add_child(lbl)

  func _update_next_button() -> void:
      if RunManager.is_run_complete():
          next_button.text = "已通关"
          next_button.disabled = true
          return
      var next_type := RunManager.get_current_node()
      next_button.text = "前往：%s" % NODE_NAMES.get(next_type, "?")

  func _on_next_pressed() -> void:
      var scene_path := RunManager.get_scene_for_current_node()
      get_tree().change_scene_to_file(scene_path)
  ```

- [ ] **Step 3：提交**

  ```bash
  git add scenes/map/ scripts/ui/map_ui.gd
  git commit -m "feat: 地图场景，显示路线和玩家状态"
  ```

---

## Task 6：商店场景

**Files:**
- Create: `scenes/shop/shop.tscn`
- Create: `scripts/ui/shop_ui.gd`

- [ ] **Step 1：创建 scenes/shop/shop.tscn**

  ```
  Shop (Control)
  ├── Title (Label)            # "商店"
  ├── GoldLabel (Label)        # "金币: N"
  ├── CommonSection (VBoxContainer)
  │   ├── SectionTitle (Label) # "普通卡牌"
  │   └── ItemsRow (HBoxContainer)   # 动态生成 ShopItem
  ├── RareSection (VBoxContainer)
  │   ├── SectionTitle (Label) # "稀有卡牌"
  │   └── ItemsRow (HBoxContainer)
  ├── DeleteSection (VBoxContainer)
  │   ├── SectionTitle (Label) # "删除卡牌（100金）"
  │   └── DeleteButton (Button)
  └── LeaveButton (Button)     # "离开"
  ```

- [ ] **Step 2：创建 scripts/ui/shop_ui.gd 并附加到根节点**

  ```gdscript
  extends Control

  const DELETE_COST := 100
  const CardViewScene = preload("res://scenes/ui/card_view.tscn")

  @onready var gold_label: Label = $GoldLabel
  @onready var common_row: HBoxContainer = $CommonSection/ItemsRow
  @onready var rare_row: HBoxContainer = $RareSection/ItemsRow

  var _shop_cards: Array[CardData] = []

  func _ready() -> void:
      _update_gold()
      _populate_shop()
      $DeleteSection/DeleteButton.pressed.connect(_on_delete_pressed)
      $LeaveButton.pressed.connect(_on_leave)

  func _update_gold() -> void:
      gold_label.text = "金币: %d" % GameState.gold

  func _populate_shop() -> void:
      var commons := CardDatabase.get_by_rarity(Enums.Rarity.COMMON)
      commons.shuffle()
      var rares := CardDatabase.get_by_rarity(Enums.Rarity.RARE)
      rares.shuffle()
      _add_shop_items(common_row, commons.slice(0, 3), 50)
      _add_shop_items(rare_row, rares.slice(0, 3), 100)

  func _add_shop_items(row: HBoxContainer, cards: Array, price: int) -> void:
      for card in cards:
          var view := CardViewScene.instantiate()
          row.add_child(view)
          view.setup(card)

          var price_label := Label.new()
          price_label.text = "%d 金" % price

          var buy_btn := Button.new()
          buy_btn.text = "购买"
          buy_btn.disabled = GameState.gold < price
          buy_btn.pressed.connect(_on_buy.bind(card, price, buy_btn))

          var container := VBoxContainer.new()
          # 将 CardView 替换为带价格和按钮的容器
          row.remove_child(view)
          container.add_child(view)
          container.add_child(price_label)
          container.add_child(buy_btn)
          row.add_child(container)

  func _on_buy(card: CardData, price: int, btn: Button) -> void:
      if not GameState.spend_gold(price):
          return
      GameState.add_card(card)
      btn.disabled = true
      btn.text = "已购买"
      _update_gold()

  func _on_delete_pressed() -> void:
      if GameState.gold < DELETE_COST:
          return
      # 简化版：删除牌组最后一张（完整版应打开选择 UI）
      if GameState.deck.is_empty():
          return
      GameState.spend_gold(DELETE_COST)
      GameState.deck.pop_back()
      _update_gold()

  func _on_leave() -> void:
      RunManager.advance_node()
      get_tree().change_scene_to_file("res://scenes/map/map.tscn")
  ```

- [ ] **Step 3：提交**

  ```bash
  git add scenes/shop/ scripts/ui/shop_ui.gd
  git commit -m "feat: 商店场景，购买卡牌和删牌功能"
  ```

---

## Task 7：主菜单与胜负结算

**Files:**
- Create: `scenes/main_menu.tscn`
- Create: `scripts/ui/main_menu.gd`
- Create: `scenes/ui/game_over.tscn`
- Create: `scripts/ui/game_over.gd`

- [ ] **Step 1：创建 scenes/main_menu.tscn**

  ```
  MainMenu (Control)
  ├── Title (Label)          # "梦境行者"
  ├── StartButton (Button)   # "开始游戏"
  └── QuitButton (Button)    # "退出"
  ```

  脚本 `scripts/ui/main_menu.gd`：

  ```gdscript
  extends Control

  func _ready() -> void:
      $StartButton.pressed.connect(_on_start)
      $QuitButton.pressed.connect(get_tree().quit)

  func _on_start() -> void:
      GameState.reset()
      # 初始牌组：6张打击、4张防御、1张睡觉
      _build_starter_deck()
      get_tree().change_scene_to_file("res://scenes/layer/layer_effect.tscn")

  func _build_starter_deck() -> void:
      for _i in range(6):
          GameState.add_card(CardDatabase.get_card("strike"))
      for _i in range(4):
          GameState.add_card(CardDatabase.get_card("defend"))
      GameState.add_card(CardDatabase.get_card("sleep"))
  ```

- [ ] **Step 2：创建 scenes/ui/game_over.tscn**

  ```
  GameOver (Control)
  ├── ResultLabel (Label)    # "胜利！" 或 "失败..."
  ├── StatsLabel (Label)     # 回合数、击杀数等简单统计
  └── RestartButton (Button) # "再来一局"
  ```

  脚本 `scripts/ui/game_over.gd`：

  ```gdscript
  extends Control

  func _ready() -> void:
      # 通过 RunManager 判断是胜利还是失败
      var won := GameState.current_hp > 0
      $ResultLabel.text = "胜利！" if won else "失败..."
      $StatsLabel.text = "剩余 HP: %d" % GameState.current_hp
      $RestartButton.pressed.connect(_on_restart)

  func _on_restart() -> void:
      get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
  ```

- [ ] **Step 3：在 project.godot 中设置主场景**

  `Project > Project Settings > Application > Run > Main Scene` → 选择 `scenes/main_menu.tscn`。

- [ ] **Step 4：提交**

  ```bash
  git add scenes/ scripts/ui/
  git commit -m "feat: 主菜单和胜负结算场景"
  ```

---

## Task 8：端到端流程验证

**Files:** 无新文件

- [ ] **Step 1：从 main_menu.tscn 运行游戏**

  按 F5 运行，按以下流程手动验证：
  1. 主菜单显示，点击"开始游戏"
  2. 进入层效果选择，三个选项显示正确文字
  3. 选择任意层效果后进入地图，显示 10 个节点
  4. 点击"前往"进入赐福选择，三个赐福按钮显示正确
  5. 选择赐福返回地图
  6. 点击前往进入战斗场景，手牌显示 5 张卡
  7. 拖拽卡牌到敌人，敌人 HP 减少，费用减少
  8. 点击"结束回合"，敌人攻击玩家，HP 减少
  9. 打败敌人后返回地图
  10. 到达 Boss 节点，进入战斗，胜利后显示结算界面

- [ ] **Step 2：修复发现的问题**

  记录并修复流程中的任何崩溃或逻辑错误。

- [ ] **Step 3：提交**

  ```bash
  git add .
  git commit -m "feat: 子计划 B 完成，端到端流程可完整运行"
  ```

---

**子计划 B 完成。** 游戏流程可以从头到尾跑通，可进入子计划 C（内容填充）。
