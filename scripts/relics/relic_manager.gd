extends Node

var _last_player_hp: int = 0
var _damage_bonus_next: float = 1.0  # 狂乱沙漏：下次攻击加成
var _cards_in_battle: int = 0        # 狂乱沙漏：本场已出牌数
var _burning_blood_bonus: int = 0    # 燃血：本场临时攻击力加成

# ─────────────────────────────────────────────
# 公共接口
# ─────────────────────────────────────────────

func has_relic(id: String) -> bool:
	for r in GameState.relics:
		if r.id == id:
			return true
	return false

func add_relic(relic: RelicData) -> void:
	if relic == null:
		return
	GameState.relics.append(relic)
	# 被动属性遗物立即生效
	match relic.id:
		"spear":        GameState.attack += 10
		"shield_relic": GameState.defense += 10

## 在 GameState.reset() 前调用，还原被动属性加成
func reset_passives() -> void:
	for r in GameState.relics:
		match r.id:
			"spear":        GameState.attack -= 10
			"shield_relic": GameState.defense -= 10

# ─────────────────────────────────────────────
# 战斗信号连接（在 start_battle / battle_ended 时调用）
# ─────────────────────────────────────────────

func connect_battle_signals() -> void:
	BattleManager.turn_phase_changed.connect(_on_turn_phase_changed)
	BattleManager.card_played.connect(_on_card_played)
	BattleManager.player_hp_changed.connect(_on_player_hp_changed)
	BattleManager.battle_ended.connect(_on_battle_ended)
	_last_player_hp = GameState.current_hp
	_cards_in_battle = 0
	_damage_bonus_next = 1.0
	_burning_blood_bonus = 0

func disconnect_battle_signals() -> void:
	if BattleManager.turn_phase_changed.is_connected(_on_turn_phase_changed):
		BattleManager.turn_phase_changed.disconnect(_on_turn_phase_changed)
	if BattleManager.card_played.is_connected(_on_card_played):
		BattleManager.card_played.disconnect(_on_card_played)
	if BattleManager.player_hp_changed.is_connected(_on_player_hp_changed):
		BattleManager.player_hp_changed.disconnect(_on_player_hp_changed)
	if BattleManager.battle_ended.is_connected(_on_battle_ended):
		BattleManager.battle_ended.disconnect(_on_battle_ended)

# ─────────────────────────────────────────────
# 伤害修正（供 BattleManager / EnemyAI 调用）
# ─────────────────────────────────────────────

## 玩家出伤修正：在 calculate_damage 末尾调用
func modify_outgoing_damage(dmg: int, base_atk: int, target_def: int) -> int:
	# 真理之剑：攻击值 < 目标防御值时，伤害翻倍
	if has_relic("truth_sword") and base_atk < target_def:
		dmg *= 2
	# 狂乱沙漏：下次攻击 +50%
	if _damage_bonus_next > 1.0:
		dmg = int(dmg * _damage_bonus_next)
		_damage_bonus_next = 1.0
	return dmg

## 玩家受伤修正：在 EnemyAI._do_attack 扣血前调用
func modify_incoming_damage(dmg: int, enemy_atk: int) -> int:
	# 格挡盾：敌人攻击值 < 玩家防御值时，减免一半
	if has_relic("blocking_shield") and enemy_atk < GameState.defense:
		dmg = int(ceil(dmg / 2.0))  # 向上取整，与 v3 规格一致
	return dmg

# ─────────────────────────────────────────────
# 信号处理
# ─────────────────────────────────────────────

func _on_battle_ended(_won: bool) -> void:
	# 燃血：战斗结束还原临时攻击力
	if _burning_blood_bonus > 0:
		GameState.attack -= _burning_blood_bonus
		_burning_blood_bonus = 0
	disconnect_battle_signals()

func _on_turn_phase_changed(phase: Enums.BattlePhase) -> void:
	if phase != Enums.BattlePhase.START_OF_TURN:
		return
	# 微光羽毛：每回合开始抽1张牌
	if has_relic("feather"):
		BattleManager.draw_cards(1)
	# 沉眠：沉睡状态下回复10生命
	if has_relic("slumber") and GameState.has_status(Enums.StatusEffectType.SLEEP):
		GameState.current_hp = min(GameState.current_hp + 10, GameState.max_hp)
		BattleManager.player_hp_changed.emit(GameState.current_hp)
	# 全知：由 BattleManager.start_player_turn() 发 omniscience_draw_requested 信号处理，此处不再额外抽牌

func _on_card_played(_card: CardData, _target: Object) -> void:
	# 狂乱沙漏：每第5张牌触发
	if has_relic("hourglass"):
		_cards_in_battle += 1
		if _cards_in_battle % 5 == 0:
			_damage_bonus_next = 1.5

func _on_player_hp_changed(new_hp: int) -> void:
	var old_hp := _last_player_hp
	_last_player_hp = new_hp  # 先更新防止递归
	if new_hp >= old_hp:
		return
	var lost := old_hp - new_hp
	# 燃血：失去生命时获得等量临时攻击力（战斗结束消失）
	if has_relic("burning_blood"):
		GameState.attack += lost
		_burning_blood_bonus += lost
		BattleManager.player_hp_changed.emit(GameState.current_hp)
