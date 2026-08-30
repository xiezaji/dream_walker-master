# 子计划 A：基础数据层 + 战斗系统

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 搭建数据结构、AutoLoad 单例和完整战斗逻辑，使一场战斗可以在无 UI 的情况下跑通并通过自动化测试。

**Architecture:** Enums/Resource 定义数据结构；GameState/CardDatabase/BattleManager/RunManager 作为 AutoLoad 单例；CardEffectExecutor 为纯静态类处理卡牌效果；LayerEffectHandler 通过挂钩 BattleManager 信号实现三种层效果。

**Tech Stack:** Godot 4.x、GDScript、GUT（单元测试框架）

---

## 文件清单

| 路径 | 类型 | 职责 |
|---|---|---|
| `scripts/enums.gd` | class_name Enums | 全局枚举定义 |
| `scripts/cards/card_effect.gd` | Resource | 单个卡牌效果数据 |
| `scripts/cards/card_data.gd` | Resource | 卡牌数据 |
| `scripts/enemies/enemy_intent.gd` | Resource | 敌人单次行动数据 |
| `scripts/enemies/enemy_data.gd` | Resource | 敌人静态数据 |
| `scripts/status_effect.gd` | Resource | 状态效果数据 |
| `scripts/game_state.gd` | AutoLoad (Node) | 玩家持久状态 |
| `scripts/cards/card_database.gd` | AutoLoad (Node) | 卡牌注册表 |
| `scripts/battle/battle_manager.gd` | AutoLoad (Node) | 战斗回合流程、牌堆、费用 |
| `scripts/battle/card_effect_executor.gd` | class_name (静态) | 执行 CardEffect |
| `scripts/battle/enemy_instance.gd` | class_name | 敌人运行时状态 |
| `scripts/battle/layer_effect_handler.gd` | class_name | 本层效果挂钩 |
| `scripts/run_manager.gd` | AutoLoad (Node) | Run 进度、地图节点 |
| `tests/test_battle_manager.gd` | GUT 测试 | 战斗逻辑单元测试 |
| `tests/test_card_effect_executor.gd` | GUT 测试 | 卡牌效果单元测试 |

---

## Task 0：安装 GUT 测试框架

**Files:**
- Create: `addons/gut/` （通过 AssetLib 下载）

- [ ] **Step 1：在 Godot 编辑器中安装 GUT**

  打开 Godot 编辑器 → AssetLib → 搜索 "GUT" → 选择 "Gut - Godot Unit Testing" → 下载并安装。
  安装完成后在 `Project > Project Settings > Plugins` 中启用 GUT。

- [ ] **Step 2：创建 tests 目录和 GUT 场景**

  在项目根目录创建 `tests/` 文件夹。
  在编辑器中创建场景 `tests/gut_scene.tscn`，添加 GUT 节点（从场景面板 + 号搜索 GUT），在 Inspector 设置：
  - Dirs: `res://tests/`
  - 勾选 "Run On Load"

- [ ] **Step 3：验证 GUT 可运行**

  运行 `tests/gut_scene.tscn`，应看到 GUT 面板显示 "0 tests passed"（无测试是正常的）。

---

## Task 1：项目文件夹结构 + 枚举定义

**Files:**
- Create: `scripts/enums.gd`

- [ ] **Step 1：创建文件夹结构**

  在 Godot 文件系统面板中创建以下文件夹：
  ```
  scripts/
  scripts/battle/
  scripts/cards/
  scripts/enemies/
  scenes/battle/
  scenes/boon/
  scenes/layer/
  scenes/map/
  scenes/shop/
  scenes/ui/
  resources/cards/
  resources/enemies/
  tests/
  ```

- [ ] **Step 2：创建 scripts/enums.gd**

  ```gdscript
  class_name Enums

  enum CardType { ATTACK, SKILL, POWER, CURSE }

  enum Rarity { STARTER, COMMON, RARE, EPIC, LEGENDARY }

  enum EffectType {
      DEAL_DAMAGE,
      GAIN_BLOCK,
      DRAW_CARDS,
      ADD_ENERGY,
      HEAL,
      REDUCE_ENEMY_DEFENSE,
      BORROW_ENERGY,   # 预借时间：+1费，下回合-1费
      BORROW_DRAW,     # 预借抽卡：抽2，下回合少抽2
      BORROW_DAMAGE,   # 预借伤害：225%伤害，敌人下回合回复一半
      BORROW_STATS,    # 预借属性：+10ATK+10DEF，下回合-10-10
      BORROW_HP,       # 预借生命：回复15，下回合-20HP
      TRUE_DAMAGE_MODE # 不息：触发真实伤害模式
  }

  enum TargetType { SELF, ONE_ENEMY, ALL_ENEMIES, RANDOM_ENEMY }

  enum BattlePhase {
      START_OF_TURN,
      PLAYER_TURN,
      END_OF_TURN,
      ENEMY_TURN,
      END_OF_ENEMY,
      BATTLE_END
  }

  enum LayerEffect { NONE, TOGETHER, ECHO, UNDYING }

  enum NodeType { BOON, BATTLE, ELITE, BOSS, SHOP, QUESTION }

  enum IntentType { ATTACK, DEBUFF }

  enum BoonType { DELETE_CARD, RARE_CARD, RANDOM_RELIC, CHOOSE_LAYER, MAX_HP }
  ```

- [ ] **Step 3：验证**

  在编辑器底部控制台无报错，文件系统可见 `scripts/enums.gd`。

---

## Task 2：CardEffect 与 CardData Resource

**Files:**
- Create: `scripts/cards/card_effect.gd`
- Create: `scripts/cards/card_data.gd`

- [ ] **Step 1：创建 scripts/cards/card_effect.gd**

  ```gdscript
  class_name CardEffect extends Resource

  @export var effect_type: Enums.EffectType = Enums.EffectType.DEAL_DAMAGE
  ## 伤害/格挡类：is_percentage=true 时为攻击力/防御力的倍率（1.0=100%）
  ## 固定值类：is_percentage=false，直接使用 value（抽牌数、回血量等）
  @export var value: float = 1.0
  @export var is_percentage: bool = false
  @export var target: Enums.TargetType = Enums.TargetType.ONE_ENEMY
  ## 附加参数，例如：{"count": 3} 用于乱战，{"end_turn": true} 用于睡觉
  @export var modifier: Dictionary = {}
  ```

- [ ] **Step 2：创建 scripts/cards/card_data.gd**

  ```gdscript
  class_name CardData extends Resource

  @export var id: String = ""
  @export var card_name: String = ""
  @export var cost: int = 1
  @export var card_type: Enums.CardType = Enums.CardType.ATTACK
  @export var rarity: Enums.Rarity = Enums.Rarity.COMMON
  @export var description: String = ""
  @export var effects: Array[CardEffect] = []
  ## 能力卡：使用后从本场战斗中永久移除
  @export var exhaust: bool = false
  ```

- [ ] **Step 3：验证**

  在编辑器中右键 `resources/cards/` → New Resource → 搜索 CardData，应能创建，Inspector 显示所有字段。

---

## Task 3：EnemyIntent、EnemyData、StatusEffect

**Files:**
- Create: `scripts/enemies/enemy_intent.gd`
- Create: `scripts/enemies/enemy_data.gd`
- Create: `scripts/status_effect.gd`

- [ ] **Step 1：创建 scripts/enemies/enemy_intent.gd**

  ```gdscript
  class_name EnemyIntent extends Resource

  @export var intent_type: Enums.IntentType = Enums.IntentType.ATTACK
  ## 攻击意图时为实际攻击力值；减益意图时为效果强度
  @export var value: int = 0
  ## DEBUFF 时填写状态 id，如 "reduce_defense"
  @export var status_id: String = ""
  ```

- [ ] **Step 2：创建 scripts/enemies/enemy_data.gd**

  ```gdscript
  class_name EnemyData extends Resource

  @export var id: String = ""
  @export var enemy_name: String = ""
  @export var max_hp: int = 100
  @export var attack: int = 40
  @export var defense: int = 0
  @export var intent_pattern: Array[EnemyIntent] = []
  @export var experience_reward: int = 8
  @export var gold_reward: int = 10
  ```

- [ ] **Step 3：创建 scripts/status_effect.gd**

  ```gdscript
  class_name StatusEffect extends Resource

  @export var id: String = ""
  ## -1 = 永久持续（本场战斗）
  @export var duration: int = 1
  @export var value: int = 0
  ```

- [ ] **Step 4：验证**

  在 `resources/enemies/` 新建 EnemyData Resource，Inspector 中添加一个 EnemyIntent，可正常赋值。

---

## Task 4：GameState AutoLoad

**Files:**
- Create: `scripts/game_state.gd`
- Modify: `project.godot`（添加 autoload 条目）

- [ ] **Step 1：创建 scripts/game_state.gd**

  ```gdscript
  extends Node

  var max_hp: int = 100
  var current_hp: int = 100
  var attack: int = 60
  var defense: int = 50
  var gold: int = 100
  var level: int = 1
  var experience: int = 0
  var deck: Array[CardData] = []
  var relics: Array = []
  var layer_effect: Enums.LayerEffect = Enums.LayerEffect.NONE

  func reset() -> void:
      max_hp = 100
      current_hp = 100
      attack = 60
      defense = 50
      gold = 100
      level = 1
      experience = 0
      deck = []
      relics = []
      layer_effect = Enums.LayerEffect.NONE

  func add_card(card: CardData) -> void:
      deck.append(card)

  func remove_card(card: CardData) -> void:
      deck.erase(card)

  func spend_gold(amount: int) -> bool:
      if gold < amount:
          return false
      gold -= amount
      return true

  func add_experience(amount: int) -> void:
      experience += amount
      _check_level_up()

  func _check_level_up() -> void:
      var thresholds := [10, 10, 10, 10]
      var needed := 0
      for i in range(level - 1):
          needed += thresholds[i]
      if level < 4 and experience >= needed + thresholds[level - 1]:
          _level_up()

  func _level_up() -> void:
      level += 1
      match level:
          2:
              attack = 80
              current_hp = min(current_hp + int(max_hp * 0.05), max_hp)
          3:
              defense = 70
              current_hp = min(current_hp + int(max_hp * 0.05), max_hp)
          4:
              max_hp = 120
              current_hp = min(current_hp + int(max_hp * 0.10), max_hp)
  ```

- [ ] **Step 2：在 project.godot 中注册 AutoLoad**

  打开 `Project > Project Settings > AutoLoad` → 点击文件夹图标选择 `scripts/game_state.gd` → 名称填 `GameState` → 点击 Add。

- [ ] **Step 3：验证**

  运行游戏，在 Godot 调试控制台输入 `print(GameState.attack)` 应输出 `60`。

---

## Task 5：CardDatabase AutoLoad

**Files:**
- Create: `scripts/cards/card_database.gd`
- Modify: `project.godot`（添加 autoload 条目）

- [ ] **Step 1：创建 scripts/cards/card_database.gd**

  ```gdscript
  extends Node

  var _cards: Dictionary = {}  # id (String) -> CardData

  func register(card: CardData) -> void:
      if card.id == "":
          push_warning("CardDatabase: 尝试注册没有 id 的卡牌")
          return
      _cards[card.id] = card

  func register_all(cards: Array[CardData]) -> void:
      for card in cards:
          register(card)

  func get_card(id: String) -> CardData:
      return _cards.get(id, null)

  func get_all() -> Array[CardData]:
      var result: Array[CardData] = []
      for c in _cards.values():
          result.append(c)
      return result

  func get_by_rarity(rarity: Enums.Rarity) -> Array[CardData]:
      var result: Array[CardData] = []
      for c in _cards.values():
          if c.rarity == rarity:
              result.append(c)
      return result
  ```

- [ ] **Step 2：在 project.godot 中注册 AutoLoad**

  `Project > Project Settings > AutoLoad` → 选择 `scripts/cards/card_database.gd` → 名称 `CardDatabase` → Add。

- [ ] **Step 3：提交**

  ```bash
  git init
  git add scripts/ project.godot
  git commit -m "feat: 添加数据结构 Resource 和 AutoLoad 单例骨架"
  ```

---

## Task 6：BattleManager — 信号与伤害计算

**Files:**
- Create: `scripts/battle/battle_manager.gd`
- Create: `tests/test_battle_manager.gd`
- Modify: `project.godot`

- [ ] **Step 1：写失败测试**

  创建 `tests/test_battle_manager.gd`：

  ```gdscript
  extends GutTest

  func test_damage_normal():
      # 攻击60 防御40 → 60-40=20
      assert_eq(BattleManager.calculate_damage(60, 40), 20)

  func test_damage_minimum_ten_percent():
      # 攻击60 防御70 → max(-10, 6) = 6
      assert_eq(BattleManager.calculate_damage(60, 70), 6)

  func test_damage_equal():
      # 攻击50 防御50 → max(0, 5) = 5
      assert_eq(BattleManager.calculate_damage(50, 50), 5)

  func test_energy_starts_at_max():
      BattleManager.current_energy = BattleManager.MAX_ENERGY
      assert_eq(BattleManager.current_energy, 3)
  ```

- [ ] **Step 2：运行测试，确认失败**

  运行 `tests/gut_scene.tscn`，预期：FAIL "BattleManager not found"（尚未创建）。

- [ ] **Step 3：创建 scripts/battle/battle_manager.gd**

  ```gdscript
  extends Node

  const MAX_ENERGY: int = 3
  const HAND_SIZE: int = 5

  signal card_played(card: CardData, target: Object)
  signal player_hp_changed(new_hp: int)
  signal enemy_hp_changed(enemy_id: String, new_hp: int)
  signal turn_phase_changed(phase: Enums.BattlePhase)
  signal battle_ended(player_won: bool)
  signal hand_updated(hand: Array)
  signal energy_changed(current: int, maximum: int)

  var current_phase: Enums.BattlePhase = Enums.BattlePhase.BATTLE_END
  var current_energy: int = 0
  var draw_pile: Array[CardData] = []
  var hand: Array[CardData] = []
  var discard_pile: Array[CardData] = []
  var enemies: Array = []
  var current_round_block: int = 0
  var true_damage_mode: bool = false
  ## 预借债务：[{type, value}] 在下回合开始时结算
  var pending_debts: Array[Dictionary] = []

  func calculate_damage(attacker_atk: int, target_def: int) -> int:
      return max(attacker_atk - target_def, int(attacker_atk * 0.1))
  ```

- [ ] **Step 4：注册 AutoLoad**

  `Project Settings > AutoLoad` → `scripts/battle/battle_manager.gd` → 名称 `BattleManager`。

- [ ] **Step 5：运行测试，确认通过**

  运行 `tests/gut_scene.tscn`，预期：4 tests passed。

---

## Task 7：BattleManager — 牌堆操作

**Files:**
- Modify: `scripts/battle/battle_manager.gd`
- Modify: `tests/test_battle_manager.gd`

- [ ] **Step 1：追加失败测试**

  在 `tests/test_battle_manager.gd` 末尾添加：

  ```gdscript
  func test_draw_from_draw_pile():
      var c1 = CardData.new()
      var c2 = CardData.new()
      BattleManager.draw_pile = [c1, c2]
      BattleManager.hand = []
      BattleManager.discard_pile = []
      BattleManager.draw_cards(1)
      assert_eq(BattleManager.hand.size(), 1)
      assert_eq(BattleManager.draw_pile.size(), 1)

  func test_shuffle_discard_when_draw_empty():
      var c = CardData.new()
      BattleManager.draw_pile = []
      BattleManager.hand = []
      BattleManager.discard_pile = [c]
      BattleManager.draw_cards(1)
      assert_eq(BattleManager.hand.size(), 1)
      assert_eq(BattleManager.discard_pile.size(), 0)

  func test_draw_stops_when_both_piles_empty():
      BattleManager.draw_pile = []
      BattleManager.hand = []
      BattleManager.discard_pile = []
      BattleManager.draw_cards(3)
      assert_eq(BattleManager.hand.size(), 0)
  ```

- [ ] **Step 2：运行测试，确认失败**

  预期：3 new tests FAIL。

- [ ] **Step 3：在 battle_manager.gd 中添加牌堆方法**

  ```gdscript
  func draw_cards(count: int) -> void:
      for i in range(count):
          if draw_pile.is_empty():
              if discard_pile.is_empty():
                  break
              shuffle_discard_to_draw()
          if not draw_pile.is_empty():
              hand.append(draw_pile.pop_back())
      hand_updated.emit(hand)

  func shuffle_discard_to_draw() -> void:
      draw_pile = discard_pile.duplicate()
      draw_pile.shuffle()
      discard_pile = []
  ```

- [ ] **Step 4：运行测试，确认通过**

  预期：全部 pass。

- [ ] **Step 5：提交**

  ```bash
  git add scripts/battle/battle_manager.gd tests/test_battle_manager.gd
  git commit -m "feat: BattleManager 信号定义、伤害计算与牌堆操作"
  ```

---

## Task 8：BattleManager — 回合流程

**Files:**
- Modify: `scripts/battle/battle_manager.gd`

- [ ] **Step 1：在 battle_manager.gd 中添加回合流程方法**

  ```gdscript
  func start_battle(battle_enemies: Array) -> void:
      enemies = battle_enemies
      draw_pile = GameState.deck.duplicate()
      draw_pile.shuffle()
      hand = []
      discard_pile = []
      current_round_block = 0
      true_damage_mode = false
      pending_debts = []
      current_phase = Enums.BattlePhase.START_OF_TURN
      _apply_start_of_turn_debts()
      start_player_turn()

  func start_player_turn() -> void:
      current_phase = Enums.BattlePhase.START_OF_TURN
      _apply_start_of_turn_debts()
      current_round_block = 0
      current_energy = MAX_ENERGY
      energy_changed.emit(current_energy, MAX_ENERGY)
      turn_phase_changed.emit(Enums.BattlePhase.START_OF_TURN)
      draw_cards(HAND_SIZE)
      current_phase = Enums.BattlePhase.PLAYER_TURN
      turn_phase_changed.emit(Enums.BattlePhase.PLAYER_TURN)

  func end_player_turn() -> void:
      if current_phase != Enums.BattlePhase.PLAYER_TURN:
          return
      current_phase = Enums.BattlePhase.END_OF_TURN
      turn_phase_changed.emit(Enums.BattlePhase.END_OF_TURN)
      for card in hand:
          if not card.exhaust:
              discard_pile.append(card)
      hand = []
      hand_updated.emit(hand)
      current_energy = 0
      energy_changed.emit(current_energy, MAX_ENERGY)
      execute_enemy_turn()

  func execute_enemy_turn() -> void:
      current_phase = Enums.BattlePhase.ENEMY_TURN
      turn_phase_changed.emit(Enums.BattlePhase.ENEMY_TURN)
      for enemy in enemies:
          if enemy.current_hp > 0:
              enemy.execute_intent(self)
      current_phase = Enums.BattlePhase.END_OF_ENEMY
      turn_phase_changed.emit(Enums.BattlePhase.END_OF_ENEMY)
      if _all_enemies_dead():
          battle_ended.emit(true)
          return
      if GameState.current_hp <= 0:
          battle_ended.emit(false)
          return
      start_player_turn()

  func play_card(card: CardData, target: Object = null) -> void:
      if current_phase != Enums.BattlePhase.PLAYER_TURN:
          return
      if current_energy < card.cost:
          return
      if not hand.has(card):
          return
      current_energy -= card.cost
      energy_changed.emit(current_energy, MAX_ENERGY)
      hand.erase(card)
      CardEffectExecutor.execute(card, target, self)
      if not card.exhaust:
          discard_pile.append(card)
      card_played.emit(card, target)
      hand_updated.emit(hand)
      if get_meta("end_turn_after_play", false):
          set_meta("end_turn_after_play", false)
          end_player_turn()
          return
      if _all_enemies_dead():
          battle_ended.emit(true)

  func _all_enemies_dead() -> bool:
      for enemy in enemies:
          if enemy.current_hp > 0:
              return false
      return true

  func _apply_start_of_turn_debts() -> void:
      var remaining: Array[Dictionary] = []
      for debt in pending_debts:
          match debt.get("type", ""):
              "energy_penalty":
                  current_energy = max(0, current_energy - debt.value)
                  energy_changed.emit(current_energy, MAX_ENERGY)
              "draw_penalty":
                  # 存储本回合少抽牌数，在 draw_cards 中处理
                  set_meta("skip_draw", get_meta("skip_draw", 0) + debt.value)
              "stat_penalty":
                  GameState.attack -= 10
                  GameState.defense -= 10
              "hp_debt":
                  GameState.current_hp = max(1, GameState.current_hp - debt.value)
                  player_hp_changed.emit(GameState.current_hp)
      pending_debts = remaining
  ```

- [ ] **Step 2：修改 draw_cards 支持少抽惩罚**

  将现有 `draw_cards` 替换为：

  ```gdscript
  func draw_cards(count: int) -> void:
      var skip := get_meta("skip_draw", 0) as int
      if skip > 0:
          var actual := max(0, count - skip)
          set_meta("skip_draw", max(0, skip - count))
          count = actual
      for i in range(count):
          if draw_pile.is_empty():
              if discard_pile.is_empty():
                  break
              shuffle_discard_to_draw()
          if not draw_pile.is_empty():
              hand.append(draw_pile.pop_back())
      hand_updated.emit(hand)
  ```

- [ ] **Step 3：提交**

  ```bash
  git add scripts/battle/battle_manager.gd
  git commit -m "feat: BattleManager 完整回合流程（start/end player turn, enemy turn, play_card）"
  ```

---

## Task 9：CardEffectExecutor

**Files:**
- Create: `scripts/battle/card_effect_executor.gd`
- Create: `tests/test_card_effect_executor.gd`

- [ ] **Step 1：写失败测试**

  创建 `tests/test_card_effect_executor.gd`：

  ```gdscript
  extends GutTest

  var _battle: Node
  var _enemy: Object

  func before_each():
      _battle = BattleManager
      GameState.attack = 60
      GameState.defense = 50
      GameState.current_hp = 100
      GameState.max_hp = 100
      _battle.current_energy = 3
      _battle.pending_debts = []
      _battle.current_round_block = 0
      _battle.true_damage_mode = false

  func test_deal_damage_percentage():
      # 打击：攻击力100%，敌方防御0 → damage = max(60,6) = 60
      var enemy = EnemyInstance.new()
      enemy.setup(EnemyData.new())
      enemy.data.defense = 0
      enemy.current_hp = 100
      _battle.enemies = [enemy]

      var effect = CardEffect.new()
      effect.effect_type = Enums.EffectType.DEAL_DAMAGE
      effect.value = 1.0
      effect.is_percentage = true
      effect.target = Enums.TargetType.ONE_ENEMY

      CardEffectExecutor._apply_effect(effect, enemy, _battle)
      assert_eq(enemy.current_hp, 40)

  func test_draw_cards():
      var c1 = CardData.new()
      var c2 = CardData.new()
      _battle.draw_pile = [c1, c2]
      _battle.hand = []

      var effect = CardEffect.new()
      effect.effect_type = Enums.EffectType.DRAW_CARDS
      effect.value = 2.0
      effect.is_percentage = false

      CardEffectExecutor._apply_effect(effect, null, _battle)
      assert_eq(_battle.hand.size(), 2)

  func test_gain_block():
      GameState.defense = 50
      _battle.current_round_block = 0

      var effect = CardEffect.new()
      effect.effect_type = Enums.EffectType.GAIN_BLOCK
      effect.value = 10.0
      effect.is_percentage = false

      CardEffectExecutor._apply_effect(effect, null, _battle)
      assert_eq(_battle.current_round_block, 10)
  ```

- [ ] **Step 2：运行测试，确认失败**

  预期：3 tests FAIL。

- [ ] **Step 3：创建 scripts/battle/card_effect_executor.gd**

  ```gdscript
  class_name CardEffectExecutor

  static func execute(card: CardData, target: Object, battle: Node) -> void:
      for effect in card.effects:
          _apply_effect(effect, target, battle)

  static func _apply_effect(effect: CardEffect, target: Object, battle: Node) -> void:
      var p_atk := GameState.attack
      var p_def := GameState.defense

      match effect.effect_type:

          Enums.EffectType.DEAL_DAMAGE:
              var base := int(p_atk * effect.value) if effect.is_percentage else int(effect.value)
              match effect.target:
                  Enums.TargetType.ONE_ENEMY:
                      if target != null and target.current_hp > 0:
                          var dmg := battle.calculate_damage(base, target.data.defense)
                          target.take_damage(dmg)
                          battle.enemy_hp_changed.emit(target.data.id, target.current_hp)
                  Enums.TargetType.ALL_ENEMIES:
                      for enemy in battle.enemies:
                          if enemy.current_hp > 0:
                              var dmg := battle.calculate_damage(base, enemy.data.defense)
                              enemy.take_damage(dmg)
                              battle.enemy_hp_changed.emit(enemy.data.id, enemy.current_hp)
                  Enums.TargetType.RANDOM_ENEMY:
                      # 乱战：X次随机攻击，溢出次数打自己
                      var count := int(effect.modifier.get("count", 1))
                      for i in range(count):
                          var alive := battle.enemies.filter(func(e): return e.current_hp > 0)
                          if alive.is_empty():
                              # 溢出：攻击玩家自身
                              var self_dmg := battle.calculate_damage(base, p_def + battle.current_round_block)
                              GameState.current_hp -= self_dmg
                              battle.player_hp_changed.emit(GameState.current_hp)
                          else:
                              var rand_e = alive[randi() % alive.size()]
                              var dmg := battle.calculate_damage(base, rand_e.data.defense)
                              rand_e.take_damage(dmg)
                              battle.enemy_hp_changed.emit(rand_e.data.id, rand_e.current_hp)

          Enums.EffectType.GAIN_BLOCK:
              var block_val := int(effect.value)
              battle.current_round_block += block_val

          Enums.EffectType.DRAW_CARDS:
              battle.draw_cards(int(effect.value))

          Enums.EffectType.ADD_ENERGY:
              battle.current_energy += int(effect.value)
              battle.energy_changed.emit(battle.current_energy, BattleManager.MAX_ENERGY)

          Enums.EffectType.HEAL:
              GameState.current_hp = min(GameState.current_hp + int(effect.value), GameState.max_hp)
              battle.player_hp_changed.emit(GameState.current_hp)
              if effect.modifier.get("end_turn", false):
                  battle.set_meta("end_turn_after_play", true)

          Enums.EffectType.BORROW_ENERGY:
              battle.current_energy += 1
              battle.energy_changed.emit(battle.current_energy, BattleManager.MAX_ENERGY)
              battle.pending_debts.append({"type": "energy_penalty", "value": 1})

          Enums.EffectType.BORROW_DRAW:
              battle.draw_cards(2)
              battle.pending_debts.append({"type": "draw_penalty", "value": 2})

          Enums.EffectType.BORROW_DAMAGE:
              # 对目标造成 225% 伤害，在目标下回合开始时回复一半
              if target != null and target.current_hp > 0:
                  var base_dmg := int(p_atk * 2.25)
                  var dmg := battle.calculate_damage(base_dmg, target.data.defense)
                  target.take_damage(dmg)
                  battle.enemy_hp_changed.emit(target.data.id, target.current_hp)
                  target.pending_heal = int(dmg / 2)  # EnemyInstance 会在其回合开始时结算

          Enums.EffectType.BORROW_STATS:
              GameState.attack += 10
              GameState.defense += 10
              battle.pending_debts.append({"type": "stat_penalty", "value": 0})

          Enums.EffectType.BORROW_HP:
              GameState.current_hp = min(GameState.current_hp + 15, GameState.max_hp)
              battle.player_hp_changed.emit(GameState.current_hp)
              battle.pending_debts.append({"type": "hp_debt", "value": 20})

          Enums.EffectType.TRUE_DAMAGE_MODE:
              # 不息：对自身造成20点攻击力的真实伤害，后续攻击无视防御
              GameState.current_hp -= 20
              battle.player_hp_changed.emit(GameState.current_hp)
              battle.true_damage_mode = true
  ```

  > **注意：** `true_damage_mode` 激活后，`calculate_damage` 需要绕过防御。在 BattleManager 中修改：
  > ```gdscript
  > func calculate_damage(attacker_atk: int, target_def: int) -> int:
  >     if true_damage_mode:
  >         return attacker_atk
  >     return max(attacker_atk - target_def, int(attacker_atk * 0.1))
  > ```

- [ ] **Step 4：运行测试，确认通过**

  预期：3 new tests pass。

- [ ] **Step 5：提交**

  ```bash
  git add scripts/battle/card_effect_executor.gd tests/test_card_effect_executor.gd scripts/battle/battle_manager.gd
  git commit -m "feat: CardEffectExecutor 实现所有效果类型"
  ```

---

## Task 10：EnemyInstance 运行时状态

**Files:**
- Create: `scripts/battle/enemy_instance.gd`

- [ ] **Step 1：创建 scripts/battle/enemy_instance.gd**

  ```gdscript
  class_name EnemyInstance

  var data: EnemyData
  var current_hp: int
  var defense: int  # 当前轮次临时防御，每回合重置
  var intent_index: int = 0
  var pending_heal: int = 0  # 预借伤害后的待回复量

  func setup(enemy_data: EnemyData) -> void:
      data = enemy_data
      current_hp = enemy_data.max_hp
      defense = enemy_data.defense
      intent_index = 0
      pending_heal = 0

  func take_damage(amount: int) -> void:
      current_hp = max(0, current_hp - amount)

  func get_current_intent() -> EnemyIntent:
      if data.intent_pattern.is_empty():
          return null
      return data.intent_pattern[intent_index % data.intent_pattern.size()]

  func execute_intent(battle: Node) -> void:
      # 结算 pending_heal（预借伤害）
      if pending_heal > 0:
          current_hp = min(current_hp + pending_heal, data.max_hp)
          battle.enemy_hp_changed.emit(data.id, current_hp)
          pending_heal = 0

      var intent := get_current_intent()
      if intent == null:
          return

      match intent.intent_type:
          Enums.IntentType.ATTACK:
              var player_total_def := GameState.defense + battle.current_round_block
              var dmg := battle.calculate_damage(intent.value, player_total_def)
              GameState.current_hp = max(0, GameState.current_hp - dmg)
              battle.player_hp_changed.emit(GameState.current_hp)
          Enums.IntentType.DEBUFF:
              match intent.status_id:
                  "reduce_defense":
                      GameState.defense = max(0, GameState.defense - intent.value)

      intent_index += 1
      # 如果意图序列走完，下一回合以30%概率攻击，70%概率减益（史莱姆规则）
      if intent_index >= data.intent_pattern.size():
          intent_index = 0

  func get_next_intent_display() -> EnemyIntent:
      var next_idx := (intent_index + 1) % data.intent_pattern.size() if not data.intent_pattern.is_empty() else 0
      if data.intent_pattern.is_empty():
          return null
      return data.intent_pattern[next_idx]
  ```

  > 史莱姆的动态意图逻辑（攻击后 30% 继续攻击 / 70% 减益）在 EnemyData 的 intent_pattern 中通过权重配置，或者在 EnemyInstance 子类中重写 `execute_intent`。Demo 阶段直接在 `resources/enemies/slime.tres` 的 intent_pattern 里配置两个意图交替即可。

- [ ] **Step 2：提交**

  ```bash
  git add scripts/battle/enemy_instance.gd
  git commit -m "feat: EnemyInstance 运行时状态和意图执行"
  ```

---

## Task 11：RunManager AutoLoad

**Files:**
- Create: `scripts/run_manager.gd`
- Modify: `project.godot`

- [ ] **Step 1：创建 scripts/run_manager.gd**

  ```gdscript
  extends Node

  var current_node_index: int = 0
  var map_nodes: Array[Enums.NodeType] = []

  func start_run() -> void:
      current_node_index = 0
      map_nodes = _generate_map()

  func _generate_map() -> Array[Enums.NodeType]:
      # 固定结构：赐福→小怪→问号→小怪→问号→小怪→商店→精英→赐福→Boss
      var nodes: Array[Enums.NodeType] = [
          Enums.NodeType.BOON,
          Enums.NodeType.BATTLE,
          Enums.NodeType.QUESTION,
          Enums.NodeType.BATTLE,
          Enums.NodeType.QUESTION,
          Enums.NodeType.BATTLE,
          Enums.NodeType.SHOP,
          Enums.NodeType.ELITE,
          Enums.NodeType.BOON,
          Enums.NodeType.BOSS
      ]
      # 随机化问号节点（50% BATTLE / 50% BOON）
      for i in range(nodes.size()):
          if nodes[i] == Enums.NodeType.QUESTION:
              nodes[i] = Enums.NodeType.BATTLE if randf() < 0.5 else Enums.NodeType.BOON
      return nodes

  func get_current_node() -> Enums.NodeType:
      if current_node_index >= map_nodes.size():
          return Enums.NodeType.BOSS
      return map_nodes[current_node_index]

  func advance_node() -> void:
      current_node_index += 1

  func is_run_complete() -> bool:
      return current_node_index >= map_nodes.size()

  func get_scene_for_current_node() -> String:
      match get_current_node():
          Enums.NodeType.BOON: return "res://scenes/boon/boon_select.tscn"
          Enums.NodeType.BATTLE: return "res://scenes/battle/battle.tscn"
          Enums.NodeType.ELITE: return "res://scenes/battle/battle.tscn"
          Enums.NodeType.BOSS: return "res://scenes/battle/battle.tscn"
          Enums.NodeType.SHOP: return "res://scenes/shop/shop.tscn"
          _: return "res://scenes/battle/battle.tscn"
  ```

- [ ] **Step 2：注册 AutoLoad**

  `Project Settings > AutoLoad` → `scripts/run_manager.gd` → 名称 `RunManager`。

- [ ] **Step 3：提交**

  ```bash
  git add scripts/run_manager.gd project.godot
  git commit -m "feat: RunManager 地图生成与 Run 进度管理"
  ```

---

## Task 12：本层效果系统（LayerEffectHandler）

**Files:**
- Create: `scripts/battle/layer_effect_handler.gd`
- Modify: `scripts/battle/battle_manager.gd`

- [ ] **Step 1：创建 scripts/battle/layer_effect_handler.gd**

  ```gdscript
  class_name LayerEffectHandler

  ## 在 start_battle 调用前调用，根据 GameState.layer_effect 修改战斗参数
  static func apply_pre_battle(battle: Node, enemies: Array) -> void:
      match GameState.layer_effect:
          Enums.LayerEffect.TOGETHER:
              # 与我同去：双方 HP 变为 50%
              GameState.current_hp = int(GameState.current_hp * 0.5)
              GameState.max_hp = int(GameState.max_hp * 0.5)
              for enemy in enemies:
                  enemy.current_hp = int(enemy.current_hp * 0.5)
              battle.player_hp_changed.emit(GameState.current_hp)
          Enums.LayerEffect.ECHO:
              # 回响形态：标记，在 play_card 和 execute_enemy_turn 中处理
              pass  # 通过 BattleManager.layer_effect 字段读取
          Enums.LayerEffect.UNDYING:
              # 至死不休：玩家生命上限翻倍
              GameState.max_hp *= 2
              GameState.current_hp *= 2
              battle.player_hp_changed.emit(GameState.current_hp)
  ```

- [ ] **Step 2：在 battle_manager.gd 修改 start_battle 加入层效果**

  在 `start_battle` 方法的 enemies 赋值之后、调用 `start_player_turn()` 之前插入：

  ```gdscript
  func start_battle(battle_enemies: Array) -> void:
      enemies = battle_enemies
      draw_pile = GameState.deck.duplicate()
      draw_pile.shuffle()
      hand = []
      discard_pile = []
      current_round_block = 0
      true_damage_mode = false
      pending_debts = []
      LayerEffectHandler.apply_pre_battle(self, enemies)  # ← 新增
      current_phase = Enums.BattlePhase.START_OF_TURN
      _apply_start_of_turn_debts()
      start_player_turn()
  ```

- [ ] **Step 3：回响形态——play_card 执行两次**

  在 `play_card` 中，`CardEffectExecutor.execute(card, target, self)` 这一行改为：

  ```gdscript
  CardEffectExecutor.execute(card, target, self)
  if GameState.layer_effect == Enums.LayerEffect.ECHO:
      CardEffectExecutor.execute(card, target, self)
  ```

- [ ] **Step 4：回响形态——execute_enemy_turn 执行两次**

  在 `execute_enemy_turn` 的循环后增加：

  ```gdscript
  func execute_enemy_turn() -> void:
      current_phase = Enums.BattlePhase.ENEMY_TURN
      turn_phase_changed.emit(Enums.BattlePhase.ENEMY_TURN)
      var rounds := 2 if GameState.layer_effect == Enums.LayerEffect.ECHO else 1
      for _r in range(rounds):
          for enemy in enemies:
              if enemy.current_hp > 0:
                  enemy.execute_intent(self)
          if GameState.current_hp <= 0:
              break
      current_phase = Enums.BattlePhase.END_OF_ENEMY
      turn_phase_changed.emit(Enums.BattlePhase.END_OF_ENEMY)
      if _all_enemies_dead():
          battle_ended.emit(true)
          return
      if GameState.current_hp <= 0:
          battle_ended.emit(false)
          return
      start_player_turn()
  ```

- [ ] **Step 5：至死不休——敌人死亡时扣玩家 10 HP**

  在 `play_card` 和 `execute_enemy_turn` 中，每次调用 `enemy_hp_changed` 后检查：

  ```gdscript
  # 在 CardEffectExecutor 中每次打死敌人后发出信号，BattleManager 连接：
  # 在 battle_manager.gd 的 _ready 中：
  func _ready() -> void:
      enemy_hp_changed.connect(_on_enemy_hp_changed)

  func _on_enemy_hp_changed(enemy_id: String, new_hp: int) -> void:
      if new_hp <= 0 and GameState.layer_effect == Enums.LayerEffect.UNDYING:
          GameState.current_hp = max(0, GameState.current_hp - 10)
          player_hp_changed.emit(GameState.current_hp)
  ```

- [ ] **Step 6：提交**

  ```bash
  git add scripts/battle/ 
  git commit -m "feat: 三种本层效果（与我同去/回响形态/至死不休）完整实现"
  ```

---

## Task 13：集成验证

**Files:**
- Create: `tests/test_integration_battle.gd`

- [ ] **Step 1：创建集成测试**

  ```gdscript
  extends GutTest

  func test_full_battle_round():
      # 准备数据
      GameState.reset()
      GameState.layer_effect = Enums.LayerEffect.NONE
      
      var strike := CardData.new()
      strike.id = "strike"
      strike.cost = 1
      strike.card_type = Enums.CardType.ATTACK
      var effect := CardEffect.new()
      effect.effect_type = Enums.EffectType.DEAL_DAMAGE
      effect.value = 1.0
      effect.is_percentage = true
      effect.target = Enums.TargetType.ONE_ENEMY
      strike.effects = [effect]
      GameState.deck = [strike, strike, strike, strike, strike]

      var enemy_data := EnemyData.new()
      enemy_data.id = "test_enemy"
      enemy_data.max_hp = 120
      enemy_data.attack = 40
      enemy_data.defense = 40
      var intent := EnemyIntent.new()
      intent.intent_type = Enums.IntentType.ATTACK
      intent.value = 40
      enemy_data.intent_pattern = [intent]

      var enemy := EnemyInstance.new()
      enemy.setup(enemy_data)

      BattleManager.start_battle([enemy])

      assert_eq(BattleManager.current_phase, Enums.BattlePhase.PLAYER_TURN)
      assert_eq(BattleManager.hand.size(), 5)
      assert_eq(BattleManager.current_energy, 3)

      # 打出一张打击
      BattleManager.play_card(BattleManager.hand[0], enemy)
      # 伤害 = max(60-40, 6) = 20
      assert_eq(enemy.current_hp, 100)
      assert_eq(BattleManager.current_energy, 2)

  func test_layer_effect_undying():
      GameState.reset()
      GameState.layer_effect = Enums.LayerEffect.UNDYING
      GameState.max_hp = 100
      GameState.current_hp = 100

      var enemy_data := EnemyData.new()
      enemy_data.id = "dummy"
      enemy_data.max_hp = 10
      enemy_data.attack = 0
      enemy_data.defense = 0
      enemy_data.intent_pattern = []
      var enemy := EnemyInstance.new()
      enemy.setup(enemy_data)

      BattleManager.start_battle([enemy])
      # 至死不休：max_hp 翻倍
      assert_eq(GameState.max_hp, 200)
  ```

- [ ] **Step 2：运行全部测试**

  运行 `tests/gut_scene.tscn`，预期：全部 pass。

- [ ] **Step 3：提交**

  ```bash
  git add tests/
  git commit -m "test: 战斗系统集成测试通过，子计划 A 完成"
  ```

---

**子计划 A 完成。** 所有战斗逻辑已实现并通过测试，可进入子计划 B（UI + 场景流程）。
