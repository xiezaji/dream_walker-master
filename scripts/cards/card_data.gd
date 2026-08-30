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
## 不可打出的牌（如大梦）
@export var cannot_play: bool = false
