extends Node

var _cards: Dictionary = {}  # id (String) -> CardData

func _ready() -> void:
	# ── 起始牌 ──────────────────────────────────────────────
	register(_card("strike", "打击", 1, Enums.CardType.ATTACK, Enums.Rarity.STARTER,
		"对一名敌人发动攻击力100%的攻击",
		[_fx(Enums.EffectType.DEAL_DAMAGE, 1.0, true, Enums.TargetType.ONE_ENEMY)]))

	register(_card("defend", "防御", 1, Enums.CardType.SKILL, Enums.Rarity.STARTER,
		"本轮防御力提高10点",
		[_fx(Enums.EffectType.GAIN_BLOCK, 10.0)]))

	register(_card("sleep", "睡觉", 1, Enums.CardType.SKILL, Enums.Rarity.STARTER,
		"回复10点生命，结束你的回合",
		[_fx(Enums.EffectType.HEAL, 10.0, false, Enums.TargetType.SELF, {"end_turn": true})]))

	# ── 普通牌 ──────────────────────────────────────────────
	register(_card("common_draw", "抽卡", 1, Enums.CardType.SKILL, Enums.Rarity.COMMON,
		"从抽牌堆抽3张牌",
		[_fx(Enums.EffectType.DRAW_CARDS, 3.0)]))

	register(_card("common_aoe", "群攻", 1, Enums.CardType.ATTACK, Enums.Rarity.COMMON,
		"对所有敌人发动攻击力60%的伤害",
		[_fx(Enums.EffectType.DEAL_DAMAGE, 0.6, true, Enums.TargetType.ALL_ENEMIES)]))

	register(_card("prophet", "先知", 1, Enums.CardType.ATTACK, Enums.Rarity.COMMON,
		"对一名敌人发动攻击力80%的攻击，然后从抽牌堆中选择1张牌加入手牌（不洗牌）",
		[_fx(Enums.EffectType.DEAL_DAMAGE, 0.8, true, Enums.TargetType.ONE_ENEMY),
		 _fx(Enums.EffectType.PICK_FROM_DRAW, 1.0)]))

	register(_card("borrow_energy", "预借时间", 0, Enums.CardType.SKILL, Enums.Rarity.COMMON,
		"获得1费，下一回合减1费",
		[_fx(Enums.EffectType.BORROW_ENERGY, 1.0)]))

	register(_card("borrow_draw", "预借抽卡", 0, Enums.CardType.SKILL, Enums.Rarity.COMMON,
		"抽两张牌，下回合少抽两张牌",
		[_fx(Enums.EffectType.BORROW_DRAW, 2.0)]))

	register(_card("borrow_damage", "预借伤害", 2, Enums.CardType.ATTACK, Enums.Rarity.COMMON,
		"对一名敌人发动攻击力225%的攻击，该敌人下回合回复伤害一半的生命",
		[_fx(Enums.EffectType.BORROW_DAMAGE, 2.25, true, Enums.TargetType.ONE_ENEMY)]))

	register(_card("chaos", "乱战", -1, Enums.CardType.ATTACK, Enums.Rarity.COMMON,
		"消耗全部费用，对随机敌人发动攻击力120%的攻击X次（溢出时攻击自己）",
		[_fx(Enums.EffectType.DEAL_DAMAGE, 1.2, true, Enums.TargetType.RANDOM_ENEMY, {"use_x": true})]))

	# ── 新增普通牌（2026-08 数值扩展）────────────────────
	register(_card("hold_breath", "屏息凝神", 1, Enums.CardType.SKILL, Enums.Rarity.COMMON,
		"本回合防御力+20",
		[_fx(Enums.EffectType.GAIN_BLOCK, 20.0)]))

	register(_card("awake_blow", "清醒一击", 1, Enums.CardType.ATTACK, Enums.Rarity.COMMON,
		"对一名敌人造成攻击力100%的伤害，并施加1层虚弱（2回合）",
		[_fx(Enums.EffectType.DEAL_DAMAGE, 1.0, true, Enums.TargetType.ONE_ENEMY),
		 _fx(Enums.EffectType.APPLY_STATUS, 0, false, Enums.TargetType.ONE_ENEMY,
			{"status_type": Enums.StatusEffectType.WEAK, "duration": 2})]))

	# ── 稀有牌 ──────────────────────────────────────────────
	register(_card("equal_exchange", "等价交换", 1, Enums.CardType.SKILL, Enums.Rarity.RARE,
		"失去10点生命，本场战斗攻击力和防御力各增加10点（可叠加）",
		[_fx(Enums.EffectType.LOSE_HP, 10.0),
		 _fx(Enums.EffectType.GAIN_STATS, 10.0)]))

	register(_card("borrow_stats", "预借属性", 0, Enums.CardType.SKILL, Enums.Rarity.RARE,
		"本回合攻击力和防御力各增加10点，下回合各减少10点",
		[_fx(Enums.EffectType.BORROW_STATS, 10.0)]))

	register(_card("borrow_aoe", "预借AOE", 1, Enums.CardType.ATTACK, Enums.Rarity.RARE,
		"对所有敌人发动攻击力100%的攻击，本回合防御力减少10点",
		[_fx(Enums.EffectType.DEAL_DAMAGE, 1.0, true, Enums.TargetType.ALL_ENEMIES),
		 _fx(Enums.EffectType.SELF_DEF_PENALTY, 10.0)]))

	register(_card("undying", "不息", 2, Enums.CardType.POWER, Enums.Rarity.RARE,
		"每回合开始时对自身造成20点伤害（无视防御），此后每次触发变为真实伤害",
		[_fx(Enums.EffectType.TRUE_DAMAGE_MODE, 0.0)], true))

	register(_card("borrow_hp", "预借生命", 1, Enums.CardType.SKILL, Enums.Rarity.RARE,
		"回复15点生命，下回合开始时失去20点生命",
		[_fx(Enums.EffectType.BORROW_HP, 0.0)]))

	# ── 新增稀有牌（2026-08 数值扩展）────────────────────
	register(_card("dream_ripple", "梦境涟漪", 1, Enums.CardType.SKILL, Enums.Rarity.RARE,
		"对所有敌人施加1层虚弱（2回合）",
		[_fx(Enums.EffectType.APPLY_STATUS, 0, false, Enums.TargetType.ALL_ENEMIES,
			{"status_type": Enums.StatusEffectType.WEAK, "duration": 2})]))

	register(_card("meditate", "冥想", 0, Enums.CardType.SKILL, Enums.Rarity.RARE,
		"失去5点生命，抽2张牌",
		[_fx(Enums.EffectType.LOSE_HP, 5.0),
		 _fx(Enums.EffectType.DRAW_CARDS, 2.0)]))

	# ── 史诗牌 ──────────────────────────────────────────────
	register(_card("mass_sleep", "昏昏欲睡", 2, Enums.CardType.SKILL, Enums.Rarity.EPIC,
		"敌我全体下一回合沉睡，不能行动",
		[_fx(Enums.EffectType.APPLY_STATUS, 0, false, Enums.TargetType.ALL_ENEMIES,
			{"status_type": Enums.StatusEffectType.SLEEP, "duration": 1}),
		 _fx(Enums.EffectType.APPLY_STATUS, 0, false, Enums.TargetType.SELF,
			{"status_type": Enums.StatusEffectType.SLEEP, "duration": 1})]))

	register(_card("heavy_punch", "重拳出击", 2, Enums.CardType.ATTACK, Enums.Rarity.EPIC,
		"对一名敌人发动(200+50×n)%攻击（n为本场已使用次数），使用3次后费用变为1",
		[_fx(Enums.EffectType.ESCALATING_HIT, 2.0, true, Enums.TargetType.ONE_ENEMY,
			{"card_id": "heavy_punch"})]))

	register(_card("life_song", "生命如歌", 2, Enums.CardType.POWER, Enums.Rarity.EPIC,
		"（被动）生命值每次变动时抽1张牌",
		[_fx(Enums.EffectType.POWER_DRAW_ON_HP, 0.0)], true))

	# ── 新增史诗牌（2026-08 数值扩展）────────────────────
	register(_card("nightmare_descend", "噩梦降临", 2, Enums.CardType.SKILL, Enums.Rarity.EPIC,
		"对所有敌人造成攻击力80%的伤害，并施加1层腐化",
		[_fx(Enums.EffectType.DEAL_DAMAGE, 0.8, true, Enums.TargetType.ALL_ENEMIES),
		 _fx(Enums.EffectType.APPLY_STATUS, 0, false, Enums.TargetType.ALL_ENEMIES,
			{"status_type": Enums.StatusEffectType.CORRUPTION, "duration": -1})]))

	# ── 结局卡 ──────────────────────────────────────────────
	register(_card("big_dream", "大梦", 0, Enums.CardType.SKILL, Enums.Rarity.LEGENDARY,
		"【不可打出】携带至赐福地可上交，将BOSS替换为隐藏BOSS",
		[], false, true))  # cannot_play = true


## 快捷函数 ─ CardEffect
func _fx(type: Enums.EffectType, value: float, is_pct: bool = false,
		tgt: Enums.TargetType = Enums.TargetType.SELF,
		mod: Dictionary = {}) -> CardEffect:
	var e := CardEffect.new()
	e.effect_type = type
	e.value = value
	e.is_percentage = is_pct
	e.target = tgt
	e.modifier = mod
	return e

## 快捷函数 ─ CardData
func _card(id: String, card_name: String, cost: int,
		card_type: Enums.CardType, rarity: Enums.Rarity,
		description: String, effects: Array,
		exhaust: bool = false, cannot_play: bool = false) -> CardData:
	var c := CardData.new()
	c.id = id
	c.card_name = card_name
	c.cost = cost
	c.card_type = card_type
	c.rarity = rarity
	c.description = description
	c.exhaust = exhaust
	c.cannot_play = cannot_play
	for eff in effects:
		c.effects.append(eff as CardEffect)
	return c

func register(card: CardData) -> void:
	if card.id == "":
		push_warning("CardDatabase: 尝试注册没有 id 的卡牌")
		return
	_cards[card.id] = card

func register_all(cards: Array[CardData]) -> void:
	for card in cards:
		register(card)

func get_card(id: String) -> CardData:
	return _cards.get(id, null)

func get_all() -> Array[CardData]:
	var result: Array[CardData] = []
	for c in _cards.values():
		result.append(c)
	return result

func get_by_rarity(rarity: Enums.Rarity) -> Array[CardData]:
	var result: Array[CardData] = []
	for c in _cards.values():
		if c.rarity == rarity:
			result.append(c)
	return result
