class_name EnemyView
extends Control

var enemy_instance: EnemyInstance = null

@onready var name_label: Label = $NameLabel
@onready var hp_bar: TextureProgressBar = $HPBar
@onready var hp_label: Label = $HPLabel
@onready var intent_label: Label = $IntentLabel
@onready var stats_label: Label = $StatsLabel
@onready var status_label: Label = $StatusLabel

func setup(instance: EnemyInstance) -> void:
	enemy_instance = instance
	name_label.text = instance.data.enemy_name
	hp_bar.max_value = instance.max_hp
	update_hp(instance.current_hp)
	update_stats()
	update_intent()
	update_statuses()

func update_hp(new_hp: int) -> void:
	hp_bar.value = new_hp
	hp_label.text = "%d / %d" % [new_hp, enemy_instance.max_hp]

func update_stats() -> void:
	stats_label.text = "DEF:%d" % enemy_instance.defense

func update_intent() -> void:
	var intent := enemy_instance.get_current_intent()
	if intent == null:
		intent_label.text = "?"
		return
	match intent.intent_type:
		Enums.IntentType.ATTACK:
			intent_label.text = "⚔ %d" % intent.value
		Enums.IntentType.DEBUFF:
			intent_label.text = "↓ %s" % _status_name(intent.status_effect_type)
		Enums.IntentType.BUFF:
			intent_label.text = "↑ 强化"
		Enums.IntentType.IMMUNE:
			intent_label.text = "◎ 免伤"
		Enums.IntentType.HEAL_SELF:
			intent_label.text = "♥ 自愈%d" % intent.value
		Enums.IntentType.SUMMON:
			intent_label.text = "★ 召唤"
		Enums.IntentType.SLEEPING:
			intent_label.text = "💤 沉睡"

func update_statuses() -> void:
	if enemy_instance == null:
		return
	var parts: PackedStringArray = []
	for s in enemy_instance.status_effects:
		var label := _status_name(s.effect_type)
		if s.duration != -1:
			label += "(%d)" % s.duration
		parts.append(label)
	status_label.text = "  ".join(parts)
	update_stats()  # 防御值随状态变化（腐化/虚弱影响属性）

func _status_name(type: Enums.StatusEffectType) -> String:
	match type:
		Enums.StatusEffectType.CORRUPTION: return "腐化"
		Enums.StatusEffectType.WEAK:       return "虚弱"
		Enums.StatusEffectType.SLEEP:      return "沉睡"
		Enums.StatusEffectType.DROWSY:     return "困倦"
		Enums.StatusEffectType.NIGHTMARE:  return "噩梦"
	return ""
