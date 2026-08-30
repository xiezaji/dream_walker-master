class_name EnemyAI

## 执行敌人本回合的行动
static func execute(enemy: EnemyInstance, battle: Node) -> void:
	match enemy.data.id:
		"big_slime", "small_slime": _slime(enemy, battle)
		"penguin":                   _penguin(enemy, battle)
		"nightmare_bat":             _nightmare_bat(enemy, battle)
		"sleepwalker":               _sleepwalker(enemy, battle)
		"dream_worm":                _dream_worm(enemy, battle)
		"illusion_butterfly":        _illusion_butterfly(enemy, battle)
		"dream_guardian":            _dream_guardian(enemy, battle)
		"sleeping_colossus":         _sleeping_colossus(enemy, battle)
		"sleeping_statue":           _sleeping_statue(enemy, battle)
		"sleeping_lord":             _sleeping_lord(enemy, battle)
		"nightmare":                 _nightmare(enemy, battle)
		_:
			# 兜底：直接普通攻击
			_do_attack(enemy, battle, enemy.current_attack)
			enemy.ai_state["turn_count"] = enemy.ai_state.get("turn_count", 0) + 1

## 返回敌人下一步的意图预览（用于 EnemyView 显示）
static func get_intent(enemy: EnemyInstance) -> EnemyIntent:
	if enemy.has_status(Enums.StatusEffectType.SLEEP):
		return _mk(Enums.IntentType.SLEEPING, 0)
	match enemy.data.id:
		"big_slime", "small_slime": return _slime_intent(enemy)
		"penguin":                   return _penguin_intent(enemy)
		"nightmare_bat":             return _bat_intent(enemy)
		"sleepwalker":               return _sleepwalker_intent(enemy)
		"dream_worm":                return _worm_intent(enemy)
		"illusion_butterfly":        return _butterfly_intent(enemy)
		"dream_guardian":            return _guardian_intent(enemy)
		"sleeping_colossus":         return _colossus_intent(enemy)
		"sleeping_statue":           return _statue_intent(enemy)
		"sleeping_lord":             return _lord_intent(enemy)
		"nightmare":                 return _mk(Enums.IntentType.IMMUNE, 0)
	return _mk(Enums.IntentType.ATTACK, enemy.current_attack)

# ─────────────────────────────────────────────
# 小怪 AI
# ─────────────────────────────────────────────

static func _slime(enemy: EnemyInstance, battle: Node) -> void:
	var tc: int = enemy.ai_state.get("turn_count", 0)
	var last_debuff: bool = enemy.ai_state.get("last_was_debuff", false)
	if tc == 0 or last_debuff:
		_do_attack(enemy, battle, enemy.current_attack)
		enemy.ai_state["last_was_debuff"] = false
	elif randf() < 0.3:
		_do_attack(enemy, battle, enemy.current_attack)
		enemy.ai_state["last_was_debuff"] = false
	else:
		_do_apply_status_player(Enums.StatusEffectType.CORRUPTION, battle)
		enemy.ai_state["last_was_debuff"] = true
	enemy.ai_state["turn_count"] = tc + 1

static func _slime_intent(enemy: EnemyInstance) -> EnemyIntent:
	var tc: int = enemy.ai_state.get("turn_count", 0)
	if tc == 0 or enemy.ai_state.get("last_was_debuff", false):
		return _mk_atk(enemy.current_attack)
	return _mk_debuff(Enums.StatusEffectType.CORRUPTION)

# ─────────────────────────────────────────────

static func _penguin(enemy: EnemyInstance, battle: Node) -> void:
	var tc: int = enemy.ai_state.get("turn_count", 0)
	if tc == 0:
		# 咕咕嘎嘎：本回合为预告，下次攻击按玩家出牌数翻倍
		enemy.ai_state["gugu"] = true
	else:
		var cards: int = battle.cards_played_this_turn
		var multiplier: float = pow(2.0, cards) if enemy.ai_state.get("gugu", false) else 1.0
		var dmg: int = int(enemy.current_attack * multiplier)
		_do_attack(enemy, battle, dmg)
		enemy.ai_state["gugu"] = false  # 咕咕嘎嘎仅首次攻击生效
	enemy.ai_state["turn_count"] = tc + 1

static func _penguin_intent(enemy: EnemyInstance) -> EnemyIntent:
	var tc: int = enemy.ai_state.get("turn_count", 0)
	if tc == 0:
		return _mk(Enums.IntentType.BUFF, 0)
	return _mk_atk(enemy.current_attack)

# ─────────────────────────────────────────────

static func _nightmare_bat(enemy: EnemyInstance, battle: Node) -> void:
	var tc: int = enemy.ai_state.get("turn_count", 0)
	if tc == 0 or randf() < 0.5:
		_do_attack(enemy, battle, enemy.current_attack)
	else:
		_do_apply_status_player(Enums.StatusEffectType.WEAK, battle)
	enemy.ai_state["turn_count"] = tc + 1

static func _bat_intent(enemy: EnemyInstance) -> EnemyIntent:
	var tc: int = enemy.ai_state.get("turn_count", 0)
	if tc == 0:
		return _mk_atk(enemy.current_attack)
	# 展示50%可能性中伤害更大的那个
	return _mk_atk(enemy.current_attack)

# ─────────────────────────────────────────────

static func _sleepwalker(enemy: EnemyInstance, battle: Node) -> void:
	# 沉睡状态由 execute_intent 外层拦截，到这里说明已醒来
	_do_attack(enemy, battle, enemy.current_attack)
	_do_apply_status_player(Enums.StatusEffectType.DROWSY, battle)
	enemy.ai_state["turn_count"] = enemy.ai_state.get("turn_count", 0) + 1

static func _sleepwalker_intent(enemy: EnemyInstance) -> EnemyIntent:
	return _mk_atk(enemy.current_attack)

# ─────────────────────────────────────────────

static func _dream_worm(enemy: EnemyInstance, battle: Node) -> void:
	var phase: int = enemy.ai_state.get("phase", 0)
	match phase:
		0:  # 钻地：免伤
			enemy.is_immune = true
		1:  # 破土：150% 伤害
			enemy.is_immune = false
			_do_attack(enemy, battle, int(enemy.current_attack * 1.5))
		2:  # 施加腐化
			_do_apply_status_player(Enums.StatusEffectType.CORRUPTION, battle)
	enemy.ai_state["phase"] = (phase + 1) % 3

static func _worm_intent(enemy: EnemyInstance) -> EnemyIntent:
	var phase: int = enemy.ai_state.get("phase", 0)
	match phase:
		0: return _mk(Enums.IntentType.IMMUNE, 0)
		1: return _mk_atk(int(enemy.current_attack * 1.5))
		2: return _mk_debuff(Enums.StatusEffectType.CORRUPTION)
	return _mk_atk(enemy.current_attack)

# ─────────────────────────────────────────────

static func _illusion_butterfly(enemy: EnemyInstance, battle: Node) -> void:
	if randf() < 0.7:
		# 迷惑：施加2层困倦（下回合少抽2张牌）
		GameState.apply_status(StatusEffect.make(Enums.StatusEffectType.DROWSY, 1))
		GameState.apply_status(StatusEffect.make(Enums.StatusEffectType.DROWSY, 1))
		battle.status_effects_changed.emit()
	else:
		_do_attack(enemy, battle, enemy.current_attack)
	enemy.ai_state["turn_count"] = enemy.ai_state.get("turn_count", 0) + 1

static func _butterfly_intent(_enemy: EnemyInstance) -> EnemyIntent:
	return _mk_debuff(Enums.StatusEffectType.DROWSY)

# ─────────────────────────────────────────────
# 精英 AI
# ─────────────────────────────────────────────

static func _dream_guardian(enemy: EnemyInstance, battle: Node) -> void:
	var phase: int = enemy.ai_state.get("phase", 0)
	match phase:
		0:  # 壁垒：自身防御+30
			enemy.defense += 30
			battle.enemy_hp_changed.emit(enemy, enemy.current_hp)
		1:  # 重击：150%
			_do_attack(enemy, battle, int(enemy.current_attack * 1.5))
		2:  # 震荡波：100% + 玩家防御-15
			_do_attack(enemy, battle, enemy.current_attack)
			GameState.defense = max(0, GameState.defense - 15)
			battle.player_hp_changed.emit(GameState.current_hp)
	enemy.ai_state["phase"] = (phase + 1) % 3

static func _guardian_intent(enemy: EnemyInstance) -> EnemyIntent:
	var phase: int = enemy.ai_state.get("phase", 0)
	match phase:
		0: return _mk(Enums.IntentType.BUFF, 0)
		1: return _mk_atk(int(enemy.current_attack * 1.5))
		2: return _mk_atk(enemy.current_attack)
	return _mk_atk(enemy.current_attack)

# ─────────────────────────────────────────────

static func _sleeping_colossus(enemy: EnemyInstance, battle: Node) -> void:
	# 沉睡时被外层拦截；到这里说明已觉醒
	var phase: int = enemy.ai_state.get("phase", 0)
	match phase:
		0:  # 召唤沉睡石像
			var statue: EnemyInstance = EnemyDatabase.create_instance("sleeping_statue")
			if statue != null:
				battle.spawn_enemy(statue)
		1:  # 打击
			_do_attack(enemy, battle, enemy.current_attack)
		2:  # 强化：所有敌人攻击+15
			for e in battle.enemies:
				if e.current_hp > 0:
					e.current_attack += 15
			battle.enemy_hp_changed.emit(enemy, enemy.current_hp)
	# 觉醒后 phase 从0开始循环 1-2-1-2...
	if phase == 0:
		enemy.ai_state["phase"] = 1
	else:
		enemy.ai_state["phase"] = (phase % 2) + 1

static func _colossus_intent(enemy: EnemyInstance) -> EnemyIntent:
	var phase: int = enemy.ai_state.get("phase", 0)
	match phase:
		0: return _mk(Enums.IntentType.SUMMON, 0)
		1: return _mk_atk(enemy.current_attack)
		2: return _mk(Enums.IntentType.BUFF, 0)
	return _mk(Enums.IntentType.SUMMON, 0)

# ─────────────────────────────────────────────

static func _sleeping_statue(enemy: EnemyInstance, battle: Node) -> void:
	var phase: int = enemy.ai_state.get("phase", 0)
	match phase:
		0: _do_attack(enemy, battle, enemy.current_attack)
		1: _do_apply_status_player(Enums.StatusEffectType.CORRUPTION, battle)
	enemy.ai_state["phase"] = (phase + 1) % 2

static func _statue_intent(enemy: EnemyInstance) -> EnemyIntent:
	var phase: int = enemy.ai_state.get("phase", 0)
	if phase == 0:
		return _mk_atk(enemy.current_attack)
	return _mk_debuff(Enums.StatusEffectType.CORRUPTION)

# ─────────────────────────────────────────────
# BOSS AI
# ─────────────────────────────────────────────

static func _sleeping_lord(enemy: EnemyInstance, battle: Node) -> void:
	var phase: int = enemy.ai_state.get("phase", 0)
	match phase:
		0:  # 梦魇凝视：100% + 腐化
			_do_attack(enemy, battle, enemy.current_attack)
			_do_apply_status_player(Enums.StatusEffectType.CORRUPTION, battle)
		1:  # 深度沉睡：自愈30
			enemy.current_hp = min(enemy.current_hp + 30, enemy.max_hp)
			battle.enemy_hp_changed.emit(enemy, enemy.current_hp)
		2:  # 噩梦爆发：施加噩梦状态（手牌本回合显示"???"）
			GameState.apply_status(StatusEffect.make(Enums.StatusEffectType.NIGHTMARE, 1))
			battle.status_effects_changed.emit()
	enemy.ai_state["phase"] = (phase + 1) % 3

static func _lord_intent(enemy: EnemyInstance) -> EnemyIntent:
	var phase: int = enemy.ai_state.get("phase", 0)
	match phase:
		0: return _mk_atk(enemy.current_attack)
		1: return _mk(Enums.IntentType.HEAL_SELF, 30)
		2: return _mk_debuff(Enums.StatusEffectType.NIGHTMARE)  # 噩梦爆发
	return _mk_atk(enemy.current_attack)

# ─────────────────────────────────────────────
# 隐藏 BOSS
# ─────────────────────────────────────────────

static func _nightmare(enemy: EnemyInstance, battle: Node) -> void:
	var turn: int = enemy.ai_state.get("turn_count", 0) + 1
	enemy.ai_state["turn_count"] = turn
	match turn:
		1:  # 唤梦：召唤2个随机小怪
			var ids := EnemyDatabase.get_all_small_monster_ids()
			ids.shuffle()
			for i in range(min(2, ids.size())):
				var inst := EnemyDatabase.create_instance(ids[i])
				if inst != null:
					battle.spawn_enemy(inst)
		2:  # 虚弱诅咒：腐化+虚弱
			_do_apply_status_player(Enums.StatusEffectType.CORRUPTION, battle)
			_do_apply_status_player(Enums.StatusEffectType.WEAK, battle)
		3:  # 重塑：所有非BOSS小怪变为其他小怪（保留HP%）
			_reshape_enemies(enemy, battle, EnemyDatabase.get_all_small_monster_ids())
		4:  # 沉眠：所有单位（含玩家）沉睡1回合；所有非BOSS回复30%MaxHP
			GameState.apply_status(StatusEffect.make(Enums.StatusEffectType.SLEEP, 1))
			for e in battle.enemies:
				if e.current_hp > 0 and e != enemy:
					e.apply_status(StatusEffect.make(Enums.StatusEffectType.SLEEP, 1))
					e.current_hp = min(e.current_hp + int(e.max_hp * 0.3), e.max_hp)
					battle.enemy_hp_changed.emit(e, e.current_hp)
			battle.status_effects_changed.emit()
		5:  pass  # 无行动
		6:  # 沉沦·小：2×场上小怪HP之和真实伤害，消灭所有小怪
			var small_ids := EnemyDatabase.get_all_small_monster_ids()
			var total_hp: int = 0
			var to_kill: Array = []
			for e in battle.enemies:
				if e.current_hp > 0 and e != enemy and e.data.id in small_ids:
					total_hp += e.current_hp
					to_kill.append(e)
			for e in to_kill:
				battle.remove_enemy(e)
			if total_hp > 0:
				GameState.current_hp = max(0, GameState.current_hp - total_hp * 2)
				battle.player_hp_changed.emit(GameState.current_hp)
		7:  # 唤梦·精英：召唤1个随机精英
			var elite_id := EnemyDatabase.get_random_elite_id()
			var inst := EnemyDatabase.create_instance(elite_id)
			if inst != null:
				battle.spawn_enemy(inst)
		8:  # 虚弱诅咒（同第2回合）
			_do_apply_status_player(Enums.StatusEffectType.CORRUPTION, battle)
			_do_apply_status_player(Enums.StatusEffectType.WEAK, battle)
		9:  # 重塑·精英：所有非BOSS单位变为精英（保留HP%）
			_reshape_enemies(enemy, battle, EnemyDatabase.get_all_elite_ids())
		10: # 沉眠（同第4回合）
			GameState.apply_status(StatusEffect.make(Enums.StatusEffectType.SLEEP, 1))
			for e in battle.enemies:
				if e.current_hp > 0 and e != enemy:
					e.apply_status(StatusEffect.make(Enums.StatusEffectType.SLEEP, 1))
					e.current_hp = min(e.current_hp + int(e.max_hp * 0.3), e.max_hp)
					battle.enemy_hp_changed.emit(e, e.current_hp)
			battle.status_effects_changed.emit()
		11: pass  # 无行动
		12: # 沉沦·大：0.5×精英HP之和真实伤害，消灭所有精英，梦魇自动死亡
			var elite_ids := EnemyDatabase.get_all_elite_ids()
			var total_hp: int = 0
			var to_kill: Array = []
			for e in battle.enemies:
				if e.current_hp > 0 and e != enemy and e.data.id in elite_ids:
					total_hp += e.current_hp
					to_kill.append(e)
			for e in to_kill:
				battle.remove_enemy(e)
			if total_hp > 0:
				GameState.current_hp = max(0, GameState.current_hp - int(total_hp * 0.5))
				battle.player_hp_changed.emit(GameState.current_hp)
			# 梦魇自动死亡，玩家胜利
			enemy.current_hp = 0
			battle.enemy_hp_changed.emit(enemy, 0)

## 重塑：将所有非BOSS存活敌人替换为 id_pool 中的其他敌人（保留HP%）
static func _reshape_enemies(nightmare: EnemyInstance, battle: Node, id_pool: Array[String]) -> void:
	var to_replace: Array = []
	for e in battle.enemies:
		if e.current_hp > 0 and e != nightmare:
			to_replace.append(e)
	for old_e in to_replace:
		var hp_pct: float = float(old_e.current_hp) / float(old_e.max_hp)
		var available: Array[String] = id_pool.filter(func(id: String) -> bool: return id != old_e.data.id)
		if available.is_empty():
			available = id_pool
		available.shuffle()
		var new_inst := EnemyDatabase.create_instance(available[0])
		if new_inst == null:
			continue
		new_inst.current_hp = max(1, int(new_inst.max_hp * hp_pct))
		battle.remove_enemy(old_e)
		battle.spawn_enemy(new_inst)

# ─────────────────────────────────────────────
# 公共辅助函数
# ─────────────────────────────────────────────

static func _do_attack(enemy: EnemyInstance, battle: Node, damage: int) -> void:
	var player_def: int = GameState.defense + battle.current_round_block
	var dmg: int = battle.calculate_damage(damage, player_def)
	dmg = RelicManager.modify_incoming_damage(dmg, enemy.current_attack)
	GameState.current_hp = max(0, GameState.current_hp - dmg)
	battle.player_hp_changed.emit(GameState.current_hp)

static func _do_apply_status_player(type: Enums.StatusEffectType, battle: Node) -> void:
	var dur: int
	match type:
		Enums.StatusEffectType.CORRUPTION: dur = -1
		Enums.StatusEffectType.WEAK:       dur = 2
		Enums.StatusEffectType.SLEEP:      dur = 1
		Enums.StatusEffectType.DROWSY:     dur = 3
		_:                                  dur = 1
	GameState.apply_status(StatusEffect.make(type, dur))
	battle.status_effects_changed.emit()

static func _mk(type: Enums.IntentType, value: int) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.intent_type = type
	i.value = value
	return i

static func _mk_atk(value: int) -> EnemyIntent:
	return _mk(Enums.IntentType.ATTACK, value)

static func _mk_debuff(status: Enums.StatusEffectType) -> EnemyIntent:
	var i := EnemyIntent.new()
	i.intent_type = Enums.IntentType.DEBUFF
	i.status_effect_type = status
	return i
