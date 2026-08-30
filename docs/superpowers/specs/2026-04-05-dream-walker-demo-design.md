# 梦境行者 Demo 设计规格

**日期：** 2026-04-05
**范围：** 单层完整流程 Demo（GDScript + Godot 4）
**架构方案：** AutoLoad 单例 + 多场景切换（方案 A）

---

## 一、Demo 目标范围

- **流程：** 本层效果选择 → 地图导航（赐福→小怪×3→商店→精英→赐福→Boss）→ 胜负结算
- **UI：** 简单可读——有卡牌框、文字信息、基本动画反馈（拖牌出牌）
- **内容：** 初始牌组 + 全部普通卡（7种）+ 全部稀有卡（5种）；2-3 种敌人 + 1 个 Boss
- **本层效果：** 全部三种（与我同去 / 回响形态 / 至死不休）均实现

---

## 二、场景结构

```
scenes/
├── main_menu.tscn
├── layer/
│   └── layer_effect.tscn       # 本层效果选择（3选1）
├── boon/
│   └── boon_select.tscn        # 赐福选择（5选1，抽3）
├── battle/
│   └── battle.tscn             # 战斗主场景
├── shop/
│   └── shop.tscn               # 商店
├── map/
│   └── map.tscn                # 路线图
└── ui/
    ├── card_view.tscn           # 单张卡牌组件（复用）
    └── game_over.tscn           # 胜负结算
```

### 场景流转

```
main_menu
  → layer_effect（选本层效果）
  → map（显示路线）
  → [battle / shop / boon_select]（按地图节点切换）
  → game_over（胜/败）
```

---

## 三、AutoLoad 单例

| 单例 | 文件 | 职责 |
|---|---|---|
| `GameState` | `scripts/game_state.gd` | 玩家 HP、金币、牌组、遗物、层效果 |
| `BattleManager` | `scripts/battle/battle_manager.gd` | 战斗回合流程、费用、手牌堆栈 |
| `CardDatabase` | `scripts/cards/card_database.gd` | 所有 CardData 的注册表，按 ID 查卡 |
| `RunManager` | `scripts/run_manager.gd` | 本次 Run 进度（地图位置、层效果） |

---

## 四、数据层（Resource 定义）

### CardData

```gdscript
class_name CardData extends Resource

@export var id: String
@export var card_name: String
@export var cost: int
@export var card_type: CardType   # ATTACK / SKILL / POWER / CURSE
@export var rarity: Rarity        # STARTER / COMMON / RARE / EPIC / LEGENDARY
@export var description: String
@export var effects: Array[CardEffect]
@export var exhaust: bool = false  # 能力卡：使用后从战斗中移除
```

### CardEffect

```gdscript
class_name CardEffect extends Resource

@export var effect_type: EffectType  # DEAL_DAMAGE / GAIN_BLOCK / DRAW / ADD_ENERGY...
@export var value: float             # 基础值：伤害/格挡类用百分比小数（1.0=100%攻击力），固定值类直接填数值（如抽牌数、回血量）
@export var is_percentage: bool = false  # true=乘以攻击力/防御力，false=固定值
@export var target: TargetType       # SELF / ONE_ENEMY / ALL_ENEMIES / RANDOM_ENEMY
@export var modifier: Dictionary     # 附加参数（如预借的下回合惩罚值）
```

### EnemyData

```gdscript
class_name EnemyData extends Resource

@export var id: String
@export var enemy_name: String
@export var max_hp: int
@export var attack: int
@export var defense: int
@export var intent_pattern: Array[EnemyIntent]
```

### StatusEffect

```gdscript
class_name StatusEffect extends Resource

@export var id: String      # "block_up", "true_damage"...
@export var duration: int   # -1 = 永久
@export var value: int
```

---

## 五、战斗系统

### 回合状态机

```gdscript
enum BattlePhase {
    START_OF_TURN,
    PLAYER_TURN,
    END_OF_TURN,
    ENEMY_TURN,
    END_OF_ENEMY,
    BATTLE_END
}
```

### BattleManager 核心方法

```gdscript
func start_battle(enemies: Array[EnemyData]) -> void
func start_player_turn() -> void
func play_card(card: CardData, target: EnemyInstance) -> void
func end_player_turn() -> void
func execute_enemy_turn() -> void
func draw_cards(count: int) -> void
func shuffle_discard_to_draw() -> void
func calculate_damage(attacker_atk: int, target_def: int) -> int
# 公式：max(atk - def, atk * 0.1)
```

### 信号

```gdscript
signal card_played(card: CardData, target)
signal player_hp_changed(new_hp: int)
signal enemy_hp_changed(enemy_id: String, new_hp: int)
signal turn_phase_changed(phase: BattlePhase)
signal battle_ended(player_won: bool)
signal hand_updated(hand: Array[CardData])
```

### 本层效果接入点

| 层效果 | 挂钩位置 |
|---|---|
| 与我同去 | `start_battle` 时将双方 HP 减半 |
| 回响形态 | `play_card` 时执行两次；`execute_enemy_turn` 时行动两次 |
| 至死不休 | 监听 `enemy_hp_changed`，检测敌人死亡时扣玩家 10 HP |

---

## 六、战斗 UI

### battle.tscn 节点树

```
Battle (Node2D)
├── Background (TextureRect)
├── EnemyArea (HBoxContainer)
│   └── EnemyView × N
│       ├── Sprite2D
│       ├── HPBar (TextureProgressBar)
│       ├── IntentIcon (Sprite2D)
│       └── StatsLabel (Label)
├── PlayerArea (Control)
│   ├── PlayerSprite (Sprite2D)
│   ├── HPBar (TextureProgressBar)
│   └── StatsLabel
├── HandArea (HBoxContainer)
├── DeckInfo (HBoxContainer)
│   ├── DrawPileCount (Label)
│   └── DiscardPileCount (Label)
├── EnergyDisplay (Label)
├── EndTurnButton (Button)
└── LayerEffectBanner (Label)
```

### CardView.tscn 节点树

```
CardView (Control)
├── CardBG (Panel)
├── NameLabel (Label)
├── CostLabel (Label)
├── TypeIcon (Sprite2D)
├── DescLabel (RichTextLabel)
└── HighlightEffect (ColorRect)
```

### 出牌交互流程

1. 点击手牌 → CardView 放大并跟随鼠标
2. 拖到敌人区域 → 高亮可选目标
3. 松开鼠标 → `BattleManager.play_card()` 执行效果
4. 费用不足或目标无效 → 卡牌弹回手牌

---

## 七、地图与 Run 流程

### 单层路线

```
[赐福] → [小怪] → [问号] → [小怪] → [问号] → [小怪] → [商店] → [精英] → [赐福] → [BOSS]
```

问号节点随机为小怪或赐福（各 50%）。

### RunManager 状态

```gdscript
var current_node_index: int = 0
var layer_effect: LayerEffect
var map_nodes: Array[NodeType]

func advance_node() -> void
func get_current_node() -> NodeType
```

### 赐福选择

- 从 5 种赐福中随机抽 3 种
- 选完后 `RunManager.advance_node()` 切换场景
- 效果直接修改 `GameState`

### 商店

- 固定出售：3 张普通卡、3 张稀有卡、3 个遗物、删牌服务
- 价格定义在 `CardData` / `RelicData` 中
- 余额不足时按钮置灰

---

## 八、文件夹结构

```
scripts/
├── game_state.gd
├── run_manager.gd
├── battle/
│   ├── battle_manager.gd
│   ├── enemy_instance.gd
│   └── status_effect_handler.gd
├── cards/
│   ├── card_data.gd
│   ├── card_effect.gd
│   └── card_database.gd
├── enemies/
│   ├── enemy_data.gd
│   └── enemy_intent.gd
└── ui/
    ├── battle_ui.gd
    ├── card_view.gd
    └── map_ui.gd

resources/
├── cards/          # .tres 文件，每张卡一个
└── enemies/        # .tres 文件，每种敌人一个
```
