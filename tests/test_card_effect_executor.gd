extends GutTest

func before_each():
    GameState.attack = 60
    GameState.defense = 50
    GameState.current_hp = 100
    GameState.max_hp = 100
    BattleManager.current_energy = 3
    BattleManager.pending_debts = []
    BattleManager.current_round_block = 0
    BattleManager.true_damage_mode = false
    BattleManager.enemies = []
    BattleManager.hand = []
    BattleManager.draw_pile = []
    BattleManager.discard_pile = []

func _make_enemy(hp: int = 100, defense: int = 0) -> Object:
    var data = EnemyData.new()
    data.id = "test_enemy"
    data.max_hp = hp
    data.attack = 0
    data.defense = defense
    var inst = EnemyInstance.new()
    inst.setup(data)
    return inst

func test_deal_damage_percentage():
    # 攻击力60 × 100% = 60，敌防0 → max(60-0, 6) = 60
    var enemy = _make_enemy(100, 0)
    BattleManager.enemies = [enemy]
    var effect = CardEffect.new()
    effect.effect_type = Enums.EffectType.DEAL_DAMAGE
    effect.value = 1.0
    effect.is_percentage = true
    effect.target = Enums.TargetType.ONE_ENEMY
    CardEffectExecutor._apply_effect(effect, enemy, BattleManager)
    assert_eq(enemy.current_hp, 40)

func test_deal_damage_all_enemies():
    var e1 = _make_enemy(100, 0)
    var e2 = _make_enemy(80, 0)
    BattleManager.enemies = [e1, e2]
    var effect = CardEffect.new()
    effect.effect_type = Enums.EffectType.DEAL_DAMAGE
    effect.value = 0.6
    effect.is_percentage = true
    effect.target = Enums.TargetType.ALL_ENEMIES
    CardEffectExecutor._apply_effect(effect, null, BattleManager)
    # 60 * 0.6 = 36, max(36-0, 3) = 36
    assert_eq(e1.current_hp, 64)
    assert_eq(e2.current_hp, 44)

func test_gain_block():
    BattleManager.current_round_block = 0
    var effect = CardEffect.new()
    effect.effect_type = Enums.EffectType.GAIN_BLOCK
    effect.value = 10.0
    effect.is_percentage = false
    CardEffectExecutor._apply_effect(effect, null, BattleManager)
    assert_eq(BattleManager.current_round_block, 10)

func test_draw_cards():
    var c1 = CardData.new()
    var c2 = CardData.new()
    BattleManager.draw_pile = [c1, c2]
    BattleManager.hand = []
    var effect = CardEffect.new()
    effect.effect_type = Enums.EffectType.DRAW_CARDS
    effect.value = 2.0
    CardEffectExecutor._apply_effect(effect, null, BattleManager)
    assert_eq(BattleManager.hand.size(), 2)

func test_borrow_energy_adds_debt():
    BattleManager.current_energy = 2
    var effect = CardEffect.new()
    effect.effect_type = Enums.EffectType.BORROW_ENERGY
    CardEffectExecutor._apply_effect(effect, null, BattleManager)
    assert_eq(BattleManager.current_energy, 3)
    assert_eq(BattleManager.pending_debts.size(), 1)
    assert_eq(BattleManager.pending_debts[0].type, "energy_penalty")
