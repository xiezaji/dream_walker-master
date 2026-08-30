extends Node

var _relics: Dictionary = {}

func _ready() -> void:
	# ── 普通遗物 ──────────────────────────────────────────
	_reg("blocking_shield", "格挡盾",   Enums.RelicRarity.COMMON,
		"受到小于防御值的攻击时，减免一半伤害")
	_reg("feather",         "微光羽毛", Enums.RelicRarity.COMMON,
		"每回合开始时，额外抽1张牌")
	_reg("lucid_badge",     "清醒徽章", Enums.RelicRarity.COMMON,
		"不会被沉睡；被施加虚弱/腐化时效果减半")
	_reg("hourglass",       "狂乱沙漏", Enums.RelicRarity.COMMON,
		"每使用第5张牌时，本次攻击伤害+50%")
	_reg("truth_sword",     "真理之剑", Enums.RelicRarity.COMMON,
		"你造成伤害时，若攻击值小于目标防御值，本次伤害翻倍")
	_reg("spear",           "矛",       Enums.RelicRarity.COMMON,
		"提升攻击力10点")
	_reg("shield_relic",    "盾",       Enums.RelicRarity.COMMON,
		"提升防御力10点")
	# ── 史诗遗物 ──────────────────────────────────────────
	_reg("burning_blood",   "燃血",     Enums.RelicRarity.EPIC,
		"每当你失去生命时，获得等量于失去生命的攻击力")
	_reg("slumber",         "沉眠",     Enums.RelicRarity.EPIC,
		"每当你沉睡时，回复10点生命值")
	_reg("omniscience",     "全知",     Enums.RelicRarity.EPIC,
		"回合开始时，额外抽1张牌（可见全部手牌选择）")

func _reg(id: String, relic_name: String, rarity: Enums.RelicRarity, desc: String) -> void:
	var r := RelicData.new()
	r.id = id
	r.relic_name = relic_name
	r.rarity = rarity
	r.description = desc
	_relics[id] = r

func get_relic(id: String) -> RelicData:
	return _relics.get(id, null)

func get_random(rarity: Enums.RelicRarity) -> RelicData:
	var pool: Array[RelicData] = []
	for r in _relics.values():
		if r.rarity == rarity:
			pool.append(r)
	if pool.is_empty():
		return null
	pool.shuffle()
	return pool[0]

func get_all() -> Array[RelicData]:
	var result: Array[RelicData] = []
	for r in _relics.values():
		result.append(r)
	return result

func get_all_by_rarity(rarity: Enums.RelicRarity) -> Array[RelicData]:
	var result: Array[RelicData] = []
	for r in _relics.values():
		if r.rarity == rarity:
			result.append(r)
	return result
