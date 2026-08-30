class_name CardEffect extends Resource

@export var effect_type: Enums.EffectType = Enums.EffectType.DEAL_DAMAGE
## 伤害/格挡类：is_percentage=true 时为攻击力/防御力的倍率（1.0=100%）
## 固定值类：is_percentage=false，直接使用 value（抽牌数、回血量等）
@export var value: float = 1.0
@export var is_percentage: bool = false
@export var target: Enums.TargetType = Enums.TargetType.ONE_ENEMY
## 附加参数，例如：{"count": 3} 用于乱战，{"end_turn": true} 用于睡觉
@export var modifier: Dictionary = {}
