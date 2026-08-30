class_name EnemyIntent extends Resource

@export var intent_type: Enums.IntentType = Enums.IntentType.ATTACK
## 攻击意图时为实际伤害值；DEBUFF 意图时为效果量（通常为 0）
@export var value: int = 0
## DEBUFF 意图时指定施加的状态类型
@export var status_effect_type: Enums.StatusEffectType = Enums.StatusEffectType.CORRUPTION
