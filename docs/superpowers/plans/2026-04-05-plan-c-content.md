# 子计划 C：内容填充（卡牌 + 敌人）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建所有卡牌和敌人的 `.tres` Resource 文件，并在 CardDatabase 中注册，使 Demo 具备完整的游戏内容。

**Architecture:** 每张卡对应一个 `.tres` 文件（CardData Resource），每种敌人对应一个 `.tres` 文件（EnemyData Resource）。CardDatabase 在 `_ready()` 中统一加载注册。所有文件命名与卡牌 id 一致。

**Tech Stack:** Godot 4 Resource 系统，GDScript

**前置条件：** 子计划 A 完成（CardData、CardEffect、EnemyData、CardDatabase 均可用）

---

## 文件清单

| 路径 | 内容 |
|---|---|
| `resources/cards/starter_strike.tres` | 打击 ×6（初始牌组用同一个资源） |
| `resources/cards/starter_defend.tres` | 防御 |
| `resources/cards/starter_sleep.tres` | 睡觉 |
| `resources/cards/common_draw.tres` | 抽卡 |
| `resources/cards/common_aoe.tres` | AOE |
| `resources/cards/rare_prophet.tres` | 先知 |
| `resources/cards/rare_borrow_energy.tres` | 预借时间 |
| `resources/cards/rare_borrow_draw.tres` | 预借抽卡 |
| `resources/cards/rare_borrow_damage.tres` | 预借伤害 |
| `resources/cards/rare_chaos.tres` | 乱战 |
| `resources/enemies/slime.tres` | 史莱姆 |
| `resources/enemies/shadow.tres` | 暗影（第二种小怪） |
| `resources/enemies/elite_golem.tres` | 精英：岩石傀儡 |
| `resources/enemies/boss_nightmare.tres` | Boss：梦魇 |
| `scripts/cards/card_database.gd` | 修改 _ready() 注册所有卡牌 |

---

## Task 1：初始牌组卡牌（3 种）

**Files:**
- Create: `resources/cards/starter_strike.tres`
- Create: `resources/cards/starter_defend.tres`
- Create: `resources/cards/starter_sleep.tres`

- [ ] **Step 1：在编辑器中创建 starter_strike.tres**

  在文件系统 `resources/cards/` 中右键 → New Resource → 搜索 CardData → 创建后在 Inspector 填写：

  | 字段 | 值 |
  |---|---|
  | id | `strike` |
  | card_name | `打击` |
  | cost | `1` |
  | card_type | `ATTACK` |
  | rarity | `STARTER` |
  | description | `对一名敌人发动攻击力100%的攻击` |
  | exhaust | `false` |

  在 effects 数组添加一个 CardEffect，字段：
  | 字段 | 值 |
  |---|---|
  | effect_type | `DEAL_DAMAGE` |
  | value | `1.0` |
  | is_percentage | `true` |
  | target | `ONE_ENEMY` |

  保存为 `resources/cards/starter_strike.tres`。

- [ ] **Step 2：创建 starter_defend.tres**

  CardData：
  | 字段 | 值 |
  |---|---|
  | id | `defend` |
  | card_name | `防御` |
  | cost | `1` |
  | card_type | `SKILL` |
  | rarity | `STARTER` |
  | description | `本轮防御力提高10点` |

  CardEffect：
  | 字段 | 值 |
  |---|---|
  | effect_type | `GAIN_BLOCK` |
  | value | `10.0` |
  | is_percentage | `false` |
  | target | `SELF` |

- [ ] **Step 3：创建 starter_sleep.tres**

  CardData：
  | 字段 | 值 |
  |---|---|
  | id | `sleep` |
  | card_name | `睡觉` |
  | cost | `1` |
  | card_type | `SKILL` |
  | rarity | `STARTER` |
  | description | `回复10点生命，结束你的回合` |

  CardEffect：
  | 字段 | 值 |
  |---|---|
  | effect_type | `HEAL` |
  | value | `10.0` |
  | is_percentage | `false` |
  | target | `SELF` |
  | modifier | `{"end_turn": true}` |

- [ ] **Step 4：提交**

  ```bash
  git add resources/cards/starter_*.tres
  git commit -m "feat: 初始牌组卡牌 tres 文件（打击/防御/睡觉）"
  ```

---

## Task 2：普通卡牌（2 种）

**Files:**
- Create: `resources/cards/common_draw.tres`
- Create: `resources/cards/common_aoe.tres`

- [ ] **Step 1：创建 common_draw.tres**

  | 字段 | 值 |
  |---|---|
  | id | `common_draw` |
  | card_name | `抽卡` |
  | cost | `1` |
  | card_type | `SKILL` |
  | rarity | `COMMON` |
  | description | `从抽牌堆抽3张牌` |

  CardEffect：
  | 字段 | 值 |
  |---|---|
  | effect_type | `DRAW_CARDS` |
  | value | `3.0` |
  | is_percentage | `false` |

- [ ] **Step 2：创建 common_aoe.tres**

  | 字段 | 值 |
  |---|---|
  | id | `common_aoe` |
  | card_name | `AOE` |
  | cost | `1` |
  | card_type | `ATTACK` |
  | rarity | `COMMON` |
  | description | `对所有敌人发动攻击力60%的伤害` |

  CardEffect：
  | 字段 | 值 |
  |---|---|
  | effect_type | `DEAL_DAMAGE` |
  | value | `0.6` |
  | is_percentage | `true` |
  | target | `ALL_ENEMIES` |

- [ ] **Step 3：提交**

  ```bash
  git add resources/cards/common_*.tres
  git commit -m "feat: 普通卡牌 tres 文件（抽卡/AOE）"
  ```

---

## Task 3：稀有卡牌（5 种）

**Files:**
- Create: `resources/cards/rare_prophet.tres`
- Create: `resources/cards/rare_borrow_energy.tres`
- Create: `resources/cards/rare_borrow_draw.tres`
- Create: `resources/cards/rare_borrow_damage.tres`
- Create: `resources/cards/rare_chaos.tres`

- [ ] **Step 1：创建 rare_prophet.tres（先知）**

  CardData：id=`rare_prophet`，名称=`先知`，cost=1，类型=ATTACK，稀有度=RARE，描述=`对一名敌人发动攻击80%的攻击，并从抽牌堆选一张牌加入手牌`

  effects（两个）：
  1. effect_type=`DEAL_DAMAGE`，value=0.8，is_percentage=true，target=ONE_ENEMY
  2. effect_type=`DRAW_CARDS`，value=1.0，is_percentage=false

- [ ] **Step 2：创建 rare_borrow_energy.tres（预借时间）**

  CardData：id=`rare_borrow_energy`，名称=`预借时间`，cost=0，类型=SKILL，稀有度=RARE，描述=`获得1费用，下一回合减1费用`

  effects（一个）：effect_type=`BORROW_ENERGY`，value=1.0，is_percentage=false，target=SELF

- [ ] **Step 3：创建 rare_borrow_draw.tres（预借抽卡）**

  CardData：id=`rare_borrow_draw`，名称=`预借抽卡`，cost=0，类型=SKILL，稀有度=RARE，描述=`抽两张牌，下一回合少抽两张牌`

  effects（一个）：effect_type=`BORROW_DRAW`，value=2.0，is_percentage=false，target=SELF

- [ ] **Step 4：创建 rare_borrow_damage.tres（预借伤害）**

  CardData：id=`rare_borrow_damage`，名称=`预借伤害`，cost=2，类型=ATTACK，稀有度=RARE，描述=`对一名敌人发动攻击力225%的攻击，该敌人回合开始时回复伤害一半的生命值`

  effects（一个）：effect_type=`BORROW_DAMAGE`，value=2.25，is_percentage=true，target=ONE_ENEMY

- [ ] **Step 5：创建 rare_chaos.tres（乱战）**

  CardData：id=`rare_chaos`，名称=`乱战`，cost=-1（X费用，在 description 说明），类型=ATTACK，稀有度=RARE，描述=`对随机敌人发动攻击力120%的攻击X次，溢出次数攻击自己`

  > 乱战的 X 费用：cost=-1 表示消耗全部费用。在 `BattleManager.play_card` 中特殊处理：当 `card.cost == -1` 时，`count = current_energy`，费用清零。
  
  在 `battle_manager.gd` 的 `play_card` 中，在 `current_energy -= card.cost` 前增加：
  ```gdscript
  var actual_cost := card.cost
  if card.cost == -1:
      actual_cost = current_energy
      current_energy = 0
      energy_changed.emit(current_energy, MAX_ENERGY)
      # 将 count 传给 modifier
      card.effects[0].modifier["count"] = actual_cost
  else:
      current_energy -= card.cost
      energy_changed.emit(current_energy, MAX_ENERGY)
  ```

  effects（一个）：effect_type=`DEAL_DAMAGE`，value=1.2，is_percentage=true，target=RANDOM_ENEMY，modifier=`{"count": 1}`（运行时被覆盖）

- [ ] **Step 6：提交**

  ```bash
  git add resources/cards/rare_*.tres scripts/battle/battle_manager.gd
  git commit -m "feat: 稀有卡牌 tres 文件（先知/预借系列/乱战）"
  ```

---

## Task 4：敌人数据（4 种）

**Files:**
- Create: `resources/enemies/slime.tres`
- Create: `resources/enemies/shadow.tres`
- Create: `resources/enemies/elite_golem.tres`
- Create: `resources/enemies/boss_nightmare.tres`

- [ ] **Step 1：创建 slime.tres（史莱姆，小怪）**

  EnemyData：id=`slime`，名称=`史莱姆`，max_hp=120，attack=40，defense=40，experience_reward=8，gold_reward=10

  intent_pattern（2个 EnemyIntent 交替）：
  1. intent_type=ATTACK，value=40（攻击意图）
  2. intent_type=DEBUFF，value=10，status_id=`reduce_defense`（减少玩家10点防御）

- [ ] **Step 2：创建 shadow.tres（暗影，第二种小怪）**

  EnemyData：id=`shadow`，名称=`暗影`，max_hp=90，attack=50，defense=20，experience_reward=8，gold_reward=12

  intent_pattern（3个）：
  1. intent_type=ATTACK，value=50
  2. intent_type=ATTACK，value=30
  3. intent_type=ATTACK，value=50

- [ ] **Step 3：创建 elite_golem.tres（精英：岩石傀儡）**

  EnemyData：id=`elite`，名称=`岩石傀儡`，max_hp=200，attack=55，defense=60，experience_reward=12，gold_reward=35

  intent_pattern（3个）：
  1. intent_type=ATTACK，value=55
  2. intent_type=ATTACK，value=55
  3. intent_type=DEBUFF，value=15，status_id=`reduce_defense`

- [ ] **Step 4：创建 boss_nightmare.tres（Boss：梦魇）**

  EnemyData：id=`boss`，名称=`梦魇`，max_hp=350，attack=70，defense=50，experience_reward=16，gold_reward=50

  intent_pattern（4个，循环）：
  1. intent_type=ATTACK，value=70
  2. intent_type=ATTACK，value=50
  3. intent_type=DEBUFF，value=20，status_id=`reduce_defense`
  4. intent_type=ATTACK，value=90

- [ ] **Step 5：提交**

  ```bash
  git add resources/enemies/
  git commit -m "feat: 4种敌人数据（史莱姆/暗影/精英/Boss）"
  ```

---

## Task 5：CardDatabase 注册所有卡牌

**Files:**
- Modify: `scripts/cards/card_database.gd`

- [ ] **Step 1：在 card_database.gd 的 _ready() 中加载并注册所有卡牌**

  ```gdscript
  extends Node

  var _cards: Dictionary = {}

  func _ready() -> void:
      var card_files := [
          "res://resources/cards/starter_strike.tres",
          "res://resources/cards/starter_defend.tres",
          "res://resources/cards/starter_sleep.tres",
          "res://resources/cards/common_draw.tres",
          "res://resources/cards/common_aoe.tres",
          "res://resources/cards/rare_prophet.tres",
          "res://resources/cards/rare_borrow_energy.tres",
          "res://resources/cards/rare_borrow_draw.tres",
          "res://resources/cards/rare_borrow_damage.tres",
          "res://resources/cards/rare_chaos.tres",
      ]
      for path in card_files:
          var card := load(path) as CardData
          if card:
              register(card)
          else:
              push_warning("CardDatabase: 无法加载 %s" % path)

  func register(card: CardData) -> void:
      if card.id == "":
          push_warning("CardDatabase: 注册了没有 id 的卡牌")
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

- [ ] **Step 2：验证所有卡牌加载成功**

  运行游戏，在 Godot 调试控制台不应有任何 "无法加载" 警告。
  在 main_menu 的 `_on_start` 里临时加一行 `print(CardDatabase.get_all().size())`，应输出 `10`，验证后删除。

- [ ] **Step 3：提交**

  ```bash
  git add scripts/cards/card_database.gd
  git commit -m "feat: CardDatabase 自动加载注册所有卡牌，子计划 C 完成"
  ```

---

## Task 6：完整 Demo 验收测试

- [ ] **Step 1：运行完整流程**

  从主菜单开始，完整跑一局，验证：
  - [ ] 初始牌组：抽牌时手牌显示打击/防御/睡觉
  - [ ] 打击（ATK 60）打史莱姆（DEF 40）：`max(60-40, 6) = 20` 伤害，史莱姆 HP 从 120 变 100
  - [ ] 赐福选稀有卡后，牌组有稀有卡可抽到
  - [ ] 精英岩石傀儡 HP 200，比普通小怪难打
  - [ ] Boss 梦魇 HP 350，第 4 回合意图为 90 攻击
  - [ ] 层效果「回响形态」下，打击执行两次，单次 20 伤 × 2 = 40 总伤
  - [ ] 层效果「至死不休」下，生命上限为 200，击杀史莱姆后玩家 -10 HP

- [ ] **Step 2：最终提交**

  ```bash
  git add .
  git commit -m "feat: 梦境行者 Demo 完成，全内容验收通过"
  ```

---

**子计划 C 完成，Demo 全部实现。**
