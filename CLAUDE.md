# DreamWalker — Claude 协作指南

## 项目简介

**梦境行者（DreamWalker）** — Godot 4 制作的杀戮尖塔风格卡牌 Roguelike 游戏。

目录：`C:\Users\LX\Desktop\23应数综测文件\dream_walker-master\dream_walker-master`（原为 slay_the_cat）

## 当前状态（2026-08 更新）

**v4 版本已合并，并完成 2026-08 数值修复与扩展。**

- 主菜单 → 层效果选择 → 地图 → 战斗 / 赐福 / 商店 / 事件 → 游戏结束，全流程可跑通
- 卡牌 30 张（新增：屏息凝神/清醒一击/梦境涟漪/冥想/噩梦降临），POWER 类型已实装（不息、生命如歌）
- 11种敌人（大/小史莱姆、企鹅、梦魇蝙蝠、梦游者、梦境蠕虫、幻音蝶、梦境守卫者、沉睡巨像、沉睡石像、沉睡之主、梦魇）
- 3种层效果（与我同去 / 回响形态 / 至死不休）
- 遗物系统已实装（RelicDatabase + RelicManager）
- 事件场景已加入（scenes/event/event.tscn）
- 卡牌奖励 / 史诗选牌 / 手牌选择 UI 已加入
- 数值说明文档：`docs/数值设计说明.md`

### 2026-08 修复清单
1. 不息：不再开启全局真实伤害模式（原为严重失衡 bug），自伤对齐文档为 20 点/回合
2. 等价交换：攻击/防御加成 5 → 10（对齐策划案 v4）
3. 乱战：X 值改经 `battle meta("x_cost_value")` 传递，不再污染共享 CardData
4. 预借AOE：防御惩罚改为本回合生效（回合结束恢复）
5. start_battle 统一清理跨战斗 meta（x_cost_value / turn_def_penalty / pick_from_draw_*）

## 已知技术问题 / 坑

- **卡牌拖拽**：`_gui_input` 无法在 HBoxContainer 子节点上触发（原因未查明），目前绕过方案是在 `BattleUI._input` 里用 `get_global_rect().has_point()` 按位置检测并调用 `CardView._start_drag()`。见 `scripts/ui/battle_ui.gd` 和 `scripts/ui/card_view.gd`。
- **卡牌/敌人数据不能用 .tres 文件**：AutoLoad `_ready()` 阶段 GDScript `class_name` 类型尚未注册进 ClassDB，`load()` .tres 文件会报 "Cannot get class"。卡牌在 `CardDatabase._ready()` 里用代码创建，敌人在 `BattleUI._build_enemy_data()` 里用代码创建。
- **拖拽时需在 remove_child 前保存 get_tree() 引用**：节点移出场景树后 `get_tree()` 为 null。
- **共享 Resource 污染**（已修）：乱战曾直接改写 `CardData.effects[].modifier`，跨战斗残留。教训：运行时数据（X 值、临时惩罚）一律走 BattleManager 的 meta，不要写进共享卡牌数据。
- **测试与实现不一致**：`tests/test_integration_battle.gd` 中 `test_layer_effect_undying_doubles_hp` 直接设置 `layer_effect` 后调用 `start_battle` 期望玩家 HP 翻倍，但玩家侧翻倍实际在 `layer_effect_ui.gd` 选层时处理——该测试需按实际流程修正后才能通过。

## 建议下一步开发方向

### 优先级高
1. **美术资源**：目前全是纯色方块和文字，替换为真实图片（卡牌插画、敌人立绘、背景）
2. **更多卡牌内容**：现有 10 张，建议扩充到 30+ 张，增加 POWER 类型（永久效果）
3. **状态效果 UI**：中毒、虚弱等状态目前有逻辑但无显示

### 优先级中
4. **音效和音乐**：`assets/audio/` 目录已准备好，接入 AudioStreamPlayer
5. **地图可视化**：目前地图是一排文字标签，改为节点图（线连接）
6. **遗物系统**：已实装基础框架，内容（遗物种类）可继续扩充

### 优先级低
7. **存档系统**：用 `ConfigFile` 或 JSON 保存 run 进度
8. **更多敌人和 BOSS**：目前只有 3 种

## 语言规范

- **全部使用 GDScript**，不使用 C#
- Godot 4 语法（非 Godot 3），注意 API 差异
- **所有回复用中文**

## 查阅文档

优先使用 **context7** MCP 查 Godot 4 API 和教程。

## 实际文件结构

```
dream_walker/
├── scenes/
│   ├── battle/       # battle.tscn, enemy_view.tscn
│   ├── boon/         # boon_select.tscn
│   ├── layer/        # layer_effect.tscn
│   ├── map/          # map.tscn
│   ├── shop/         # shop.tscn
│   ├── ui/           # card_view.tscn, game_over.tscn
│   └── main_menu.tscn
├── scenes/
│   ├── battle/       # battle.tscn, enemy_view.tscn
│   ├── boon/         # boon_select.tscn
│   ├── event/        # event.tscn
│   ├── layer/        # layer_effect.tscn
│   ├── map/          # map.tscn
│   ├── shop/         # shop.tscn
│   ├── ui/           # card_view.tscn, game_over.tscn, card_reward.tscn,
│   │                 # epic_card_choice.tscn, hand_pick.tscn
│   └── main_menu.tscn
├── scripts/
│   ├── battle/       # battle_manager.gd, card_effect_executor.gd,
│   │                 # enemy_instance.gd, layer_effect_handler.gd, enemy_ai.gd
│   ├── cards/        # card_data.gd, card_database.gd, card_effect.gd
│   ├── enemies/      # enemy_data.gd, enemy_intent.gd, enemy_database.gd
│   ├── relics/       # relic_data.gd, relic_database.gd, relic_manager.gd
│   ├── ui/           # battle_ui.gd, card_view.gd, enemy_view.gd,
│   │                 # boon_select_ui.gd, layer_effect_ui.gd, map_ui.gd,
│   │                 # shop_ui.gd, game_over.gd, main_menu.gd, event_ui.gd,
│   │                 # card_reward_ui.gd, epic_card_choice_ui.gd,
│   │                 # hand_pick_ui.gd, deck_viewer.gd
│   ├── enums.gd
│   ├── game_state.gd
│   ├── run_manager.gd
│   └── status_effect.gd
└── tests/            # GDScript 单元测试
```

## AutoLoad 单例

| 名称 | 文件 | 职责 |
|---|---|---|
| GameState | scripts/game_state.gd | 玩家 HP/攻防/牌组/金币/遗物 |
| CardDatabase | scripts/cards/card_database.gd | 注册和查询所有卡牌 |
| EnemyDatabase | scripts/enemies/enemy_database.gd | 注册所有敌人数据 |
| RelicDatabase | scripts/relics/relic_database.gd | 注册所有遗物 |
| RelicManager | scripts/relics/relic_manager.gd | 遗物被动效果处理 |
| BattleManager | scripts/battle/battle_manager.gd | 回合制战斗流程 |
| RunManager | scripts/run_manager.gd | 地图节点生成和进度 |
| DeckViewer | scripts/ui/deck_viewer.gd | 牌组查看弹窗（AutoLoad） |

## 编码规范

- 使用 `class_name` 为脚本命名
- 信号（signal）用于跨节点通信，避免直接引用
- 数据与逻辑分离：用 Resource 存数据，用 Node 写逻辑
- 变量类型需显式声明（GDScript 4 严格模式，`:=` 推断 Variant 会报 warning）
- 每个文件只做一件事
