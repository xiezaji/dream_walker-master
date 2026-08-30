class_name CardEffectExecutor

static func execute(card: CardData, target: Object, battle: Node) -> void:
	for effect in card.effects:
		_apply_effect(effect, target, battle)

static func _apply_effect(effect: CardEffect, target: Object, battle: Node) -> void:
	var p_atk := GameState.attack
	var p_def := GameState.defense

	match effect.effect_type:

		Enums.EffectType.DEAL_DAMAGE:
			var base := int(p_atk * effect.value) if effect.is_percentage else int(effect.value)
			match effect.target:
				Enums.TargetType.ONE_ENEMY:
					if target != null and target.current_hp > 0:
						var dmg: int = battle.calculate_damage(base, target.data.defense, true)
						target.take_damage(dmg)
						battle.enemy_hp_changed.emit(target, target.current_hp)
				Enums.TargetType.ALL_ENEMIES:
					for enemy in battle.enemies:
						if enemy.current_hp > 0:
							var dmg: int = battle.calculate_damage(base, enemy.data.defense, true)
							enemy.take_damage(dmg)
							battle.enemy_hp_changed.emit(enemy, enemy.current_hp)
				Enums.TargetType.RANDOM_ENEMY:
					# X费用卡（乱战）：X值由 BattleManager 通过 meta 传递，避免污染共享 CardData
					var count := int(effect.modifier.get("count", 1))
					if effect.modifier.get("use_x", false):
						count = int(battle.get_meta("x_cost_value", 0))
					for i in range(count):
						var alive: Array = battle.enemies.filter(func(e): return e.current_hp > 0)
						if alive.is_empty():
							# 溢出：攻击玩家自身
							var self_dmg: int = battle.calculate_damage(base, p_def + battle.current_round_block)
							GameState.current_hp -= self_dmg
							battle.player_hp_changed.emit(GameState.current_hp)
						else:
							var rand_e = alive[randi() % alive.size()]
							var dmg: int = battle.calculate_damage(base, rand_e.data.defense, true)
							rand_e.take_damage(dmg)
							battle.enemy_hp_changed.emit(rand_e, rand_e.current_hp)

		Enums.EffectType.GAIN_BLOCK:
			var block_val := int(effect.value)
			battle.current_round_block += block_val

		Enums.EffectType.DRAW_CARDS:
			battle.draw_cards(int(effect.value))

		Enums.EffectType.ADD_ENERGY:
			battle.current_energy += int(effect.value)
			battle.energy_changed.emit(battle.current_energy, BattleManager.MAX_ENERGY)

		Enums.EffectType.HEAL:
			GameState.current_hp = min(GameState.current_hp + int(effect.value), GameState.max_hp)
			battle.player_hp_changed.emit(GameState.current_hp)
			if effect.modifier.get("end_turn", false):
				battle.set_meta("end_turn_after_play", true)

		Enums.EffectType.BORROW_ENERGY:
			battle.current_energy += 1
			battle.energy_changed.emit(battle.current_energy, BattleManager.MAX_ENERGY)
			battle.pending_debts.append({"type": "energy_penalty", "value": 1})

		Enums.EffectType.BORROW_DRAW:
			battle.draw_cards(2)
			battle.pending_debts.append({"type": "draw_penalty", "value": 2})

		Enums.EffectType.BORROW_DAMAGE:
			if target != null and target.current_hp > 0:
				var base_dmg := int(p_atk * 2.25)
				var dmg: int = battle.calculate_damage(base_dmg, target.data.defense)
				target.take_damage(dmg)
				battle.enemy_hp_changed.emit(target, target.current_hp)
				target.pending_heal = int(float(dmg) / 2.0)

		Enums.EffectType.BORROW_STATS:
			GameState.attack += 10
			GameState.defense += 10
			battle.pending_debts.append({"type": "stat_penalty", "value": 0})

		Enums.EffectType.BORROW_HP:
			GameState.current_hp = min(GameState.current_hp + 15, GameState.max_hp)
			battle.player_hp_changed.emit(GameState.current_hp)
			battle.pending_debts.append({"type": "hp_debt", "value": 20})

		Enums.EffectType.TRUE_DAMAGE_MODE:
			# 不息：每回合开始时对自身造成20点伤害（直接扣血，天然无视防御）
			# 注意：不开启全局真实伤害模式（否则玩家与敌人的所有伤害都会无视防御，严重失衡）
			battle.passive_self_damage = 20

		Enums.EffectType.LOSE_HP:
			var amount := int(effect.value)
			GameState.current_hp = max(0, GameState.current_hp - amount)
			battle.player_hp_changed.emit(GameState.current_hp)

		Enums.EffectType.GAIN_STATS:
			var amount := int(effect.value)
			GameState.attack += amount
			GameState.defense += amount
			battle.player_hp_changed.emit(GameState.current_hp)

		Enums.EffectType.SELF_DEF_PENALTY:
			# 预借AOE：本回合防御力-X（回合结束时恢复，见 BattleManager.end_player_turn）
			var amount := int(effect.value)
			var applied := min(amount, GameState.defense)
			GameState.defense = max(0, GameState.defense - applied)
			battle.set_meta("turn_def_penalty", battle.get_meta("turn_def_penalty", 0) + applied)
			battle.player_hp_changed.emit(GameState.current_hp)

		Enums.EffectType.ESCALATING_HIT:
			if target != null and target.current_hp > 0:
				var card_id: String = effect.modifier.get("card_id", "")
				# play_card 在 execute 前已 +1，所以 n=1 是第一次使用
				var n: int = battle.card_play_counts.get(card_id, 1)
				var pct := 2.0 + 0.5 * (n - 1)
				var base_dmg := int(p_atk * pct)
				var dmg: int = battle.calculate_damage(base_dmg, target.data.defense)
				target.take_damage(dmg)
				battle.enemy_hp_changed.emit(target, target.current_hp)
				# 使用满3次后费用改为1
				if n >= 3:
					battle.card_cost_overrides[card_id] = 1

		Enums.EffectType.POWER_DRAW_ON_HP:
			battle.passive_draw_on_hp = true

		Enums.EffectType.PICK_FROM_DRAW:
			if battle.draw_pile.is_empty():
				return
			if battle.draw_pile.size() == 1:
				battle.hand.append(battle.draw_pile.pop_back())
				battle.hand_updated.emit(battle.hand)
				return
			# 若已有待处理的 PICK_FROM_DRAW（回响形态），排队等待
			if battle.get_meta("pick_from_draw_pending", false):
				battle.set_meta("pick_from_draw_queued",
					battle.get_meta("pick_from_draw_queued", 0) as int + 1)
				return
			battle.set_meta("pick_from_draw_pending", true)
			battle.pick_from_draw_requested.emit(battle.draw_pile.duplicate(), 1)

		Enums.EffectType.APPLY_STATUS:
			var stype := int(effect.modifier.get("status_type", 0)) as Enums.StatusEffectType
			var dur := int(effect.modifier.get("duration", 1))
			match effect.target:
				Enums.TargetType.ONE_ENEMY:
					if target != null and target.current_hp > 0:
						target.apply_status(StatusEffect.make(stype, dur))
						battle.status_effects_changed.emit()
				Enums.TargetType.ALL_ENEMIES:
					for enemy in battle.enemies:
						if enemy.current_hp > 0:
							enemy.apply_status(StatusEffect.make(stype, dur))
					battle.status_effects_changed.emit()
				Enums.TargetType.SELF:
					GameState.apply_status(StatusEffect.make(stype, dur))
					battle.status_effects_changed.emit()
