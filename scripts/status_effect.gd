class_name StatusEffect extends Resource

@export var effect_type: Enums.StatusEffectType = Enums.StatusEffectType.WEAK
## -1 = 永久持续（本场战斗）
@export var duration: int = 1
## 效果量（预留，当前各类型固定值）
@export var value: int = 0

static func make(type: Enums.StatusEffectType, dur: int, val: int = 0) -> StatusEffect:
	var s := StatusEffect.new()
	s.effect_type = type
	s.duration = dur
	s.value = val
	return s
