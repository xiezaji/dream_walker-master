extends GutTest

func test_damage_normal():
	# 攻击60 防御40 → 60-40=20
	assert_eq(BattleManager.calculate_damage(60, 40), 20)

func test_damage_minimum_ten_percent():
	# 攻击60 防御70 → max(-10, 6) = 6
	assert_eq(BattleManager.calculate_damage(60, 70), 6)

func test_damage_equal():
	# 攻击50 防御50 → max(0, 5) = 5
	assert_eq(BattleManager.calculate_damage(50, 50), 5)

func test_true_damage_mode_ignores_defense():
	BattleManager.true_damage_mode = true
	assert_eq(BattleManager.calculate_damage(60, 9999), 60)
	BattleManager.true_damage_mode = false

func test_energy_constant():
	assert_eq(BattleManager.MAX_ENERGY, 3)

func test_draw_from_draw_pile():
	var c1 = CardData.new()
	var c2 = CardData.new()
	BattleManager.draw_pile = [c1, c2]
	BattleManager.hand = []
	BattleManager.discard_pile = []
	BattleManager.remove_meta("skip_draw") if BattleManager.has_meta("skip_draw") else null
	BattleManager.draw_cards(1)
	assert_eq(BattleManager.hand.size(), 1)
	assert_eq(BattleManager.draw_pile.size(), 1)

func test_shuffle_discard_when_draw_empty():
	var c = CardData.new()
	BattleManager.draw_pile = []
	BattleManager.hand = []
	BattleManager.discard_pile = [c]
	BattleManager.remove_meta("skip_draw") if BattleManager.has_meta("skip_draw") else null
	BattleManager.draw_cards(1)
	assert_eq(BattleManager.hand.size(), 1)
	assert_eq(BattleManager.discard_pile.size(), 0)

func test_draw_stops_when_both_piles_empty():
	BattleManager.draw_pile = []
	BattleManager.hand = []
	BattleManager.discard_pile = []
	BattleManager.remove_meta("skip_draw") if BattleManager.has_meta("skip_draw") else null
	BattleManager.draw_cards(3)
	assert_eq(BattleManager.hand.size(), 0)

func test_skip_draw_penalty():
	var c1 = CardData.new()
	var c2 = CardData.new()
	var c3 = CardData.new()
	BattleManager.draw_pile = [c1, c2, c3]
	BattleManager.hand = []
	BattleManager.discard_pile = []
	BattleManager.set_meta("skip_draw", 2)  # penalty: skip 2
	BattleManager.draw_cards(3)  # asks for 3, but only gets 1
	assert_eq(BattleManager.hand.size(), 1)
	BattleManager.remove_meta("skip_draw") if BattleManager.has_meta("skip_draw") else null
