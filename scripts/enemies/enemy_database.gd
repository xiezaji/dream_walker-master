extends Node

var _data: Dictionary = {}

func _ready() -> void:
	_reg("big_slime",           "大史莱姆",   82,  38, 38,  8, 10)
	_reg("small_slime",         "小史莱姆",   78,  42, 42,  8, 15)
	_reg("penguin",             "企鹅",      178,  14, 20,  8, 12)
	_reg("nightmare_bat",       "梦魇蝙蝠",   96,  35, 15,  8, 10)
	_reg("sleepwalker",         "梦游者",    140,  25, 30,  8, 12)
	_reg("dream_worm",          "梦境蠕虫",  110,  30, 25,  8, 12)
	_reg("illusion_butterfly",  "幻音蝶",     80,  20, 32,  8, 10)
	_reg("dream_guardian",      "梦境守卫者", 280,  50, 20, 12, 30)
	_reg("sleeping_colossus",   "沉睡巨像",  332,  45, 80, 12, 35)
	_reg("sleeping_statue",     "沉睡石像",   80,  45, 40,  0,  0)
	_reg("sleeping_lord",       "沉睡之主",  500,  60, 60, 16, 50)
	_reg("nightmare",           "梦魇",        1,   0,  0, 20,  0)

func _reg(id: String, enemy_name: String, hp: int, atk: int, def_val: int,
		xp: int, gold: int) -> void:
	var d := EnemyData.new()
	d.id = id
	d.enemy_name = enemy_name
	d.max_hp = hp
	d.attack = atk
	d.defense = def_val
	d.experience_reward = xp
	d.gold_reward = gold
	_data[id] = d

## 返回 EnemyData
func get_data(id: String) -> EnemyData:
	return _data.get(id, null)

## 创建已配置好 AI 属性的 EnemyInstance
func create_instance(id: String) -> EnemyInstance:
	var data := get_data(id)
	if data == null:
		push_warning("EnemyDatabase: 未知敌人 '%s'" % id)
		return null
	var inst := EnemyInstance.new()
	inst.setup(data)
	match id:
		"sleepwalker":
			inst.wake_on_damage = true
			inst.wake_hit_count = -1
			inst.apply_status(StatusEffect.make(Enums.StatusEffectType.SLEEP, -1))
		"sleeping_colossus":
			inst.wake_on_damage = true
			inst.wake_hit_count = 3
			inst.apply_status(StatusEffect.make(Enums.StatusEffectType.SLEEP, -1))
		"sleeping_statue":
			inst.wake_on_damage = true
			inst.wake_hit_count = 3
			inst.apply_status(StatusEffect.make(Enums.StatusEffectType.SLEEP, -1))
		"nightmare":
			inst.is_immune = true
	return inst

## 随机返回一组小怪 ID
func get_random_battle_group() -> Array[String]:
	var groups: Array = [
		["big_slime", "small_slime"],
		["penguin"],
		["sleepwalker", "dream_worm"],
		["nightmare_bat", "nightmare_bat", "nightmare_bat"],
		["nightmare_bat", "illusion_butterfly"],
	]
	var picked: Array = groups[randi() % groups.size()]
	var result: Array[String] = []
	for id in picked:
		result.append(id as String)
	return result

func get_random_elite_id() -> String:
	return ["dream_guardian", "sleeping_colossus"][randi() % 2]

func get_all_small_monster_ids() -> Array[String]:
	return ["big_slime", "small_slime", "penguin", "nightmare_bat",
			"sleepwalker", "dream_worm", "illusion_butterfly"]

func get_all_elite_ids() -> Array[String]:
	return ["dream_guardian", "sleeping_colossus"]
