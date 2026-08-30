extends GutTest

# ── 辅助函数 ──────────────────────────────────────────────

func _make_strike_card() -> CardData:
	var effect := CardEffect.new()
	effect.effect_type = Enums.EffectType.DEAL_DAMAGE
	effect.value = 1.0
	effect.is_percentage = true
	effect.target = Enums.TargetType.ONE_ENEMY
	var card := CardData.new()
	card.id = "strike"
	card.card_name = "打击"
	card.cost = 1
	card.card_type = Enums.CardType.ATTACK
	card.effects = [effect]
	return card

func _make_slime_enemy() -> EnemyInstance:
	var intent := EnemyIntent.new()
	intent.intent_type = Enums.IntentType.ATTACK
	intent.value = 40
	var data := EnemyData.new()
	data.id = "slime"
	data.enemy_name = "史莱姆"
	data.max_hp = 50
	data.attack = 40
	data.defense = 10
	data.intent_pattern = [intent]
	var inst := EnemyInstance.new()
	inst.setup(data)
	return inst

func _reset_game_state() -> void:
	GameState.reset()
	BattleManager.true_damage_mode = false
	BattleManager.pending_debts = []
	if BattleManager.has_meta("skip_draw"):
		BattleManager.remove_meta("skip_draw")
	if BattleManager.has_meta("end_turn_after_play"):
		BattleManager.remove_meta("end_turn_after_play")

# ── 测试用例 ──────────────────────────────────────────────

func test_full_battle_setup():
	_reset_game_state()
	var card := _make_strike_card()
	GameState.deck = [card, card.duplicate(), card.duplicate(),
					  card.duplicate(), card.duplicate(), card.duplicate()]
	var enemy := _make_slime_enemy()
	BattleManager.start_battle([enemy])
	assert_eq(BattleManager.current_phase, Enums.BattlePhase.PLAYER_TURN)
	assert_eq(BattleManager.hand.size(), BattleManager.HAND_SIZE)
	assert_eq(BattleManager.current_energy, BattleManager.MAX_ENERGY)

func test_play_card_deals_damage():
	# ATK=60, DEF=10 → damage = 60*1.0 - 10 = 50
	_reset_game_state()
	var enemy := _make_slime_enemy()
	var card := _make_strike_card()
	GameState.deck = [card]
	BattleManager.start_battle([enemy])
	# 手牌中拿到 strike，直接打击史莱姆
	var strike := BattleManager.hand[0]
	BattleManager.current_phase = Enums.BattlePhase.PLAYER_TURN
	BattleManager.play_card(strike, enemy)
	var expected_dmg := BattleManager.calculate_damage(GameState.attack, enemy.data.defense)
	assert_eq(enemy.current_hp, 50 - expected_dmg)

func test_layer_effect_undying_doubles_hp():
	_reset_game_state()
	GameState.layer_effect = Enums.LayerEffect.UNDYING
	var original_hp := GameState.current_hp
	var enemy := _make_slime_enemy()
	BattleManager.start_battle([enemy])
	assert_eq(GameState.current_hp, original_hp * 2)
	assert_eq(GameState.max_hp, 100 * 2)
	GameState.layer_effect = Enums.LayerEffect.NONE

func test_layer_effect_together_halves_hp():
	_reset_game_state()
	GameState.layer_effect = Enums.LayerEffect.TOGETHER
	var original_player_hp := GameState.current_hp
	var enemy := _make_slime_enemy()
	var original_enemy_hp := enemy.current_hp
	BattleManager.start_battle([enemy])
	assert_eq(GameState.current_hp, int(original_player_hp * 0.5))
	assert_eq(enemy.current_hp, int(original_enemy_hp * 0.5))
	GameState.layer_effect = Enums.LayerEffect.NONE

func test_end_turn_moves_hand_to_discard():
	_reset_game_state()
	var cards: Array[CardData] = []
	for i in range(6):
		var c := _make_strike_card()
		c.id = "strike_%d" % i
		cards.append(c)
	GameState.deck = cards
	var enemy := _make_slime_enemy()
	BattleManager.start_battle([enemy])
	var hand_size_before := BattleManager.hand.size()
	BattleManager.end_player_turn()
	# 手牌应清空，丢弃堆应有本轮手牌（非 exhaust）
	assert_eq(BattleManager.hand.size(), 0)
	assert_eq(BattleManager.discard_pile.size(), hand_size_before)
