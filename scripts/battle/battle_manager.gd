extends Node

const MAX_ENERGY: int = 3
const HAND_SIZE: int = 5      # 每回合抽牌数
const MAX_HAND_SIZE: int = 10 # 手牌上限

signal card_played(card: CardData, target: Object)
signal player_hp_changed(new_hp: int)
signal enemy_hp_changed(enemy: EnemyInstance, new_hp: int)
signal turn_phase_changed(phase: Enums.BattlePhase)
signal battle_ended(player_won: bool)
signal hand_updated(hand: Array)
signal energy_changed(current: int, maximum: int)
signal status_effects_changed
signal enemy_spawned(instance: EnemyInstance)
## 全知遗物：请求 UI 显示手牌选择，UI 选完后调用 finish_omniscience_draw(chosen)
signal omniscience_draw_requested(pool: Array, count: int)
## 先知卡：请求 UI 从抽牌堆选牌，UI 选完后调用 finish_pick_from_draw(chosen)
@warning_ignore("unused_signal")
signal pick_from_draw_requested(pool: Array, count: int)
## 梦魇移除敌人（重塑/沉沦时用）
signal enemy_removed(instance: EnemyInstance)

var current_phase: Enums.BattlePhase = Enums.BattlePhase.BATTLE_END
var current_energy: int = 0
var draw_pile: Array[CardData] = []
var hand: Array[CardData] = []
var discard_pile: Array[CardData] = []
var enemies: Array = []
var current_round_block: int = 0
var true_damage_mode: bool = false
## 预借债务：[{type, value}] 在下回合开始时结算
var pending_debts: Array[Dictionary] = []
## 重拳出击：本场战斗各卡牌使用次数
var card_play_counts: Dictionary = {}
## 重拳出击：卡牌费用覆盖（id -> 新费用）
var card_cost_overrides: Dictionary = {}
## 生命如歌：HP变动时抽牌
var passive_draw_on_hp: bool = false
## 不息：每回合起始自伤
var passive_self_damage: int = 0
## 企鹅：本次玩家回合已出牌数
var cards_played_this_turn: int = 0

func calculate_damage(attacker_atk: int, target_def: int, is_player_atk: bool = false) -> int:
	if true_damage_mode:
		return attacker_atk
	var dmg: int = max(attacker_atk - target_def, int(attacker_atk * 0.1))
	if is_player_atk:
		dmg = RelicManager.modify_outgoing_damage(dmg, attacker_atk, target_def)
	return dmg

func draw_cards(count: int) -> void:
	var skip: int = get_meta("skip_draw", 0) as int
	if skip > 0:
		var actual: int = max(0, count - skip)
		set_meta("skip_draw", max(0, skip - count))
		count = actual
	for i in range(count):
		if hand.size() >= MAX_HAND_SIZE:
			break  # 手牌已满，停止抽卡
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			shuffle_discard_to_draw()
		if not draw_pile.is_empty():
			hand.append(draw_pile.pop_back())
	hand_updated.emit(hand)

func shuffle_discard_to_draw() -> void:
	draw_pile = discard_pile.duplicate()
	draw_pile.shuffle()
	discard_pile = []

func start_battle(battle_enemies: Array) -> void:
	# 清理上一场战斗遗留的 meta（X费用值/回合防御惩罚/先知选牌状态）
	for meta_name in ["x_cost_value", "turn_def_penalty", "pick_from_draw_pending", "pick_from_draw_queued"]:
		if has_meta(meta_name):
			remove_meta(meta_name)
	enemies = battle_enemies
	draw_pile = GameState.deck.duplicate()
	draw_pile.shuffle()
	hand = []
	discard_pile = []
	current_round_block = 0
	true_damage_mode = false
	pending_debts = []
	GameState.clear_battle_statuses()
	card_play_counts = {}
	card_cost_overrides = {}
	passive_draw_on_hp = false
	passive_self_damage = 0
	# 跨战斗惩罚（来自随机事件）
	if GameState.next_battle_def_penalty > 0:
		GameState.defense = max(0, GameState.defense - GameState.next_battle_def_penalty)
		GameState.next_battle_def_penalty = 0
	LayerEffectHandler.apply_pre_battle(self, enemies)
	RelicManager.connect_battle_signals()
	# 温暖被窝：敌人先攻
	if GameState.next_battle_enemy_first:
		GameState.next_battle_enemy_first = false
		current_phase = Enums.BattlePhase.ENEMY_TURN
		execute_enemy_turn()
		return
	current_phase = Enums.BattlePhase.START_OF_TURN
	_apply_start_of_turn_debts()
	start_player_turn()

func start_player_turn() -> void:
	current_phase = Enums.BattlePhase.START_OF_TURN
	# 先记录是否沉睡，再 tick（tick 会移除到期的状态）
	var was_sleeping := GameState.has_status(Enums.StatusEffectType.SLEEP)
	GameState.tick_statuses()
	status_effects_changed.emit()
	current_round_block = 0
	current_energy = MAX_ENERGY
	_apply_start_of_turn_debts()  # energy 重置后再结算债务，避免被覆盖
	energy_changed.emit(current_energy, MAX_ENERGY)
	turn_phase_changed.emit(Enums.BattlePhase.START_OF_TURN)
	# 不息：每回合起始自伤
	if passive_self_damage > 0:
		GameState.current_hp = max(0, GameState.current_hp - passive_self_damage)
		player_hp_changed.emit(GameState.current_hp)
		if GameState.current_hp <= 0:
			_finish_battle(false)
			return
	# 沉睡：跳过玩家回合
	if was_sleeping:
		current_phase = Enums.BattlePhase.PLAYER_TURN
		end_player_turn()
		return
	cards_played_this_turn = 0
	# 困倦：每层减少1张抽牌（叠加）
	var draw_count := HAND_SIZE
	for s in GameState.status_effects:
		if s.effect_type == Enums.StatusEffectType.DROWSY:
			draw_count -= 1
	draw_count = max(0, draw_count)
	# 全知：让玩家自选手牌，暂停等待回调
	if RelicManager.has_relic("omniscience"):
		var pool: Array = draw_pile.duplicate()
		pool.append_array(discard_pile)
		omniscience_draw_requested.emit(pool, HAND_SIZE)
		# 由 finish_omniscience_draw() 继续
		return
	draw_cards(draw_count)
	# 手牌始终补足到 HAND_SIZE（消化完 skip_draw 惩罚后再补足）
	var deficit := HAND_SIZE - hand.size()
	if deficit > 0:
		draw_cards(deficit)
	current_phase = Enums.BattlePhase.PLAYER_TURN
	turn_phase_changed.emit(Enums.BattlePhase.PLAYER_TURN)

func end_player_turn() -> void:
	if current_phase != Enums.BattlePhase.PLAYER_TURN:
		return
	current_phase = Enums.BattlePhase.END_OF_TURN
	turn_phase_changed.emit(Enums.BattlePhase.END_OF_TURN)
	for card in hand:
		if not card.exhaust:
			discard_pile.append(card)
	hand = []
	hand_updated.emit(hand)
	current_energy = 0
	energy_changed.emit(current_energy, MAX_ENERGY)
	# 恢复本回合的临时防御惩罚（预借AOE：本回合防御力-X）
	var def_penalty: int = get_meta("turn_def_penalty", 0) as int
	if def_penalty > 0:
		GameState.defense += def_penalty
		remove_meta("turn_def_penalty")
		status_effects_changed.emit()
	execute_enemy_turn()

func execute_enemy_turn() -> void:
	current_phase = Enums.BattlePhase.ENEMY_TURN
	turn_phase_changed.emit(Enums.BattlePhase.ENEMY_TURN)
	# 每回合先 tick 所有敌人的状态（记录沉睡后再 tick，避免本回合误动）
	var sleeping_enemies: Array = []
	for enemy in enemies:
		if enemy.current_hp > 0:
			if enemy.has_status(Enums.StatusEffectType.SLEEP):
				sleeping_enemies.append(enemy)
			enemy.tick_statuses()
	status_effects_changed.emit()
	var rounds := 2 if GameState.layer_effect == Enums.LayerEffect.ECHO else 1
	for _r in range(rounds):
		for enemy in enemies:
			if enemy.current_hp > 0 and enemy not in sleeping_enemies:
				enemy.execute_intent(self)
		if GameState.current_hp <= 0:
			break
	current_phase = Enums.BattlePhase.END_OF_ENEMY
	turn_phase_changed.emit(Enums.BattlePhase.END_OF_ENEMY)
	if _all_enemies_dead():
		_finish_battle(true)
		return
	if GameState.current_hp <= 0:
		_finish_battle(false)
		return
	start_player_turn()

## 全知遗物：UI 选牌完毕后调用
func finish_omniscience_draw(chosen: Array) -> void:
	hand = []
	for card in chosen:
		hand.append(card)
		draw_pile.erase(card)
		discard_pile.erase(card)
	hand_updated.emit(hand)
	energy_changed.emit(current_energy, MAX_ENERGY)
	current_phase = Enums.BattlePhase.PLAYER_TURN

func play_card(card: CardData, target: Object = null) -> void:
	if current_phase != Enums.BattlePhase.PLAYER_TURN:
		return
	if card.cannot_play:
		return
	var effective_cost: int = card_cost_overrides.get(card.id, card.cost) as int
	if current_energy < effective_cost and effective_cost != -1:
		return
	if not hand.has(card):
		return
	var actual_cost := effective_cost
	if effective_cost == -1:
		actual_cost = current_energy
		current_energy = 0
		# X费用卡（乱战）：通过 meta 传递 X 值，避免修改共享 CardData 的 modifier（跨战斗污染）
		set_meta("x_cost_value", actual_cost)
	else:
		current_energy -= effective_cost
	card_play_counts[card.id] = card_play_counts.get(card.id, 0) + 1
	cards_played_this_turn += 1
	energy_changed.emit(current_energy, MAX_ENERGY)
	hand.erase(card)
	CardEffectExecutor.execute(card, target, self)
	# 回响形态：效果触发两次（费用只支付一次）
	if GameState.layer_effect == Enums.LayerEffect.ECHO:
		CardEffectExecutor.execute(card, target, self)
	if not card.exhaust:
		discard_pile.append(card)
	card_played.emit(card, target)
	hand_updated.emit(hand)
	if get_meta("end_turn_after_play", false):
		set_meta("end_turn_after_play", false)
		end_player_turn()
		return
	if _all_enemies_dead():
		_finish_battle(true)

func _finish_battle(player_won: bool) -> void:
	battle_ended.emit(player_won)

func _all_enemies_dead() -> bool:
	for enemy in enemies:
		if enemy.current_hp > 0:
			return false
	return true

func _apply_start_of_turn_debts() -> void:
	for debt in pending_debts:
		match debt.get("type", ""):
			"energy_penalty":
				current_energy = max(0, current_energy - debt.value)
				energy_changed.emit(current_energy, MAX_ENERGY)
			"draw_penalty":
				set_meta("skip_draw", get_meta("skip_draw", 0) + debt.value)
			"stat_penalty":
				GameState.attack -= 10
				GameState.defense -= 10
			"hp_debt":
				GameState.current_hp = max(1, GameState.current_hp - debt.value)
				player_hp_changed.emit(GameState.current_hp)
	pending_debts = []

func _ready() -> void:
	enemy_hp_changed.connect(_on_enemy_hp_changed)
	player_hp_changed.connect(_on_player_hp_changed_passive)

## 生命如歌被动：HP变动时抽1张牌
func _on_player_hp_changed_passive(_new_hp: int) -> void:
	if passive_draw_on_hp and current_phase != Enums.BattlePhase.BATTLE_END:
		draw_cards(1)

## 召唤新敌人（由 EnemyAI 调用，BattleUI 监听后创建视图）
func spawn_enemy(instance: EnemyInstance) -> void:
	enemies.append(instance)
	enemy_spawned.emit(instance)

## 移除敌人（梦魇重塑/沉沦时用，不触发胜利判定）
func remove_enemy(instance: EnemyInstance) -> void:
	enemies.erase(instance)
	enemy_removed.emit(instance)

## 先知卡：UI 选牌完毕后调用
func finish_pick_from_draw(chosen: Array) -> void:
	for card in chosen:
		hand.append(card)
		draw_pile.erase(card)
	set_meta("pick_from_draw_pending", false)
	hand_updated.emit(hand)
	# 若有队列中的 PICK_FROM_DRAW（回响形态触发），继续处理
	var queued: int = get_meta("pick_from_draw_queued", 0) as int
	if queued > 0 and not draw_pile.is_empty():
		set_meta("pick_from_draw_queued", queued - 1)
		set_meta("pick_from_draw_pending", true)
		pick_from_draw_requested.emit(draw_pile.duplicate(), 1)

func _on_enemy_hp_changed(_enemy: EnemyInstance, new_hp: int) -> void:
	if new_hp <= 0 and GameState.layer_effect == Enums.LayerEffect.UNDYING:
		GameState.current_hp = max(0, GameState.current_hp - 10)
		player_hp_changed.emit(GameState.current_hp)
