extends Node

var max_hp: int = 100
var current_hp: int = 100
var attack: int = 60
var defense: int = 50
var gold: int = 100
var level: int = 1
var experience: int = 0
var deck: Array[CardData] = []
var relics: Array[RelicData] = []
var layer_effect: Enums.LayerEffect = Enums.LayerEffect.NONE
var status_effects: Array[StatusEffect] = []
## 跨战斗惩罚标志（沉睡的商人事件）
var next_battle_def_penalty: int = 0
## 跨战斗标志（温暖被窝事件）
var next_battle_enemy_first: bool = false

signal level_up(new_level: int)

func reset() -> void:
	RelicManager.reset_passives()
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
	next_battle_def_penalty = 0
	next_battle_enemy_first = false

## 战斗开始时清除上一场战斗遗留的状态（同时还原被修改的属性）
func clear_battle_statuses() -> void:
	for s in status_effects:
		_restore_status_stat(s)
	status_effects = []

## 施加状态：同类型已存在则刷新持续时间（取较大值），否则新增
func apply_status(s: StatusEffect) -> void:
	# 清醒徽章：免疫沉睡；虚弱/腐化持续时间减半
	if RelicManager.has_relic("lucid_badge"):
		if s.effect_type == Enums.StatusEffectType.SLEEP:
			return
		if s.effect_type == Enums.StatusEffectType.WEAK or \
				s.effect_type == Enums.StatusEffectType.CORRUPTION:
			s.duration = max(1, int(s.duration / 2.0))
	# 沉睡/噩梦不叠加：已有则取较大持续时间
	if s.effect_type == Enums.StatusEffectType.SLEEP or \
			s.effect_type == Enums.StatusEffectType.NIGHTMARE:
		for existing in status_effects:
			if existing.effect_type == s.effect_type:
				existing.duration = max(existing.duration, s.duration)
				return
	# 腐化/虚弱/困倦：独立叠加，每层各自计时
	status_effects.append(s)
	_apply_status_stat(s)

## 回合开始时调用：持续时间 -1，到期的效果移除并还原属性
func tick_statuses() -> void:
	var to_remove: Array[StatusEffect] = []
	for s in status_effects:
		if s.duration == -1:
			continue
		s.duration -= 1
		if s.duration <= 0:
			to_remove.append(s)
	for s in to_remove:
		_restore_status_stat(s)
		status_effects.erase(s)

func has_status(type: Enums.StatusEffectType) -> bool:
	for s in status_effects:
		if s.effect_type == type:
			return true
	return false

func _apply_status_stat(s: StatusEffect) -> void:
	match s.effect_type:
		Enums.StatusEffectType.CORRUPTION:
			defense = max(0, defense - 10)
		Enums.StatusEffectType.WEAK:
			attack = max(0, attack - 8)

func _restore_status_stat(s: StatusEffect) -> void:
	match s.effect_type:
		Enums.StatusEffectType.CORRUPTION:
			defense += 10
		Enums.StatusEffectType.WEAK:
			attack += 8

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
			# 3→4：二选一由 battle_ui 的史诗卡选择界面处理（max_hp+20 或 选史诗卡）
			# 此处只给满级的10%回血（一次性）
			current_hp = min(current_hp + int(max_hp * 0.10), max_hp)
	level_up.emit(level)
