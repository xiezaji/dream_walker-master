class_name EnemyInstance

var data: EnemyData
var max_hp: int   # 独立副本，不修改共享的 EnemyData
var current_hp: int
var defense: int
var current_attack: int
var intent_index: int = 0
var pending_heal: int = 0
var status_effects: Array[StatusEffect] = []

## AI 状态（turn_count, phase, last_was_debuff 等，各敌人自定义）
var ai_state: Dictionary = {}
## 梦境蠕虫钻地时为 true，免疫伤害
var is_immune: bool = false
## 受伤时觉醒（梦游者、沉睡巨像等）
var wake_on_damage: bool = false
## 需要受击次数才觉醒（-1 = 任意伤害即觉醒）
var wake_hit_count: int = -1
## 已受击次数（用于觉醒判断）
var hit_count: int = 0

func setup(enemy_data: EnemyData) -> void:
	data = enemy_data
	max_hp = enemy_data.max_hp
	current_hp = enemy_data.max_hp
	defense = enemy_data.defense
	current_attack = enemy_data.attack
	intent_index = 0
	pending_heal = 0
	status_effects = []
	ai_state = {}
	is_immune = false
	hit_count = 0

func take_damage(amount: int) -> void:
	if is_immune or amount <= 0:
		return
	current_hp = max(0, current_hp - amount)
	hit_count += 1
	_check_wake()

func _check_wake() -> void:
	if not wake_on_damage:
		return
	if ai_state.get("awake", false):
		return
	if wake_hit_count != -1 and hit_count < wake_hit_count:
		return
	ai_state["awake"] = true
	# 移除沉睡状态
	for s in status_effects.duplicate():
		if s.effect_type == Enums.StatusEffectType.SLEEP:
			_restore_status_stat(s)
			status_effects.erase(s)

func get_current_intent() -> EnemyIntent:
	return EnemyAI.get_intent(self)

## 施加状态：同类已存在则刷新持续时间
func apply_status(s: StatusEffect) -> void:
	# 沉睡不叠加
	if s.effect_type == Enums.StatusEffectType.SLEEP:
		for existing in status_effects:
			if existing.effect_type == s.effect_type:
				existing.duration = max(existing.duration, s.duration)
				return
	# 腐化/虚弱/困倦独立叠加
	status_effects.append(s)
	_apply_status_stat(s)

## 回合开始时 tick（在 execute_intent 前调用）
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
			current_attack = max(0, current_attack - 8)

func _restore_status_stat(s: StatusEffect) -> void:
	match s.effect_type:
		Enums.StatusEffectType.CORRUPTION:
			defense += 10
		Enums.StatusEffectType.WEAK:
			current_attack += 8

func execute_intent(battle: Node) -> void:
	# 结算 pending_heal（预借伤害）
	if pending_heal > 0:
		current_hp = min(current_hp + pending_heal, data.max_hp)
		battle.enemy_hp_changed.emit(self, current_hp)
		pending_heal = 0
	# 沉睡：跳过行动
	if has_status(Enums.StatusEffectType.SLEEP):
		return
	EnemyAI.execute(self, battle)
