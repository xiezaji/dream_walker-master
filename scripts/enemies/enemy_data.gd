class_name EnemyData extends Resource

@export var id: String = ""
@export var enemy_name: String = ""
@export var max_hp: int = 100
@export var attack: int = 40
@export var defense: int = 0
@export var intent_pattern: Array[EnemyIntent] = []
@export var experience_reward: int = 8
@export var gold_reward: int = 10
