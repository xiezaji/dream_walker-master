class_name LayerEffectHandler

## 在 BattleManager.start_battle 中、敌人实例化后调用
## 根据 GameState.layer_effect 修改战斗初始参数
static func apply_pre_battle(_battle: Node, enemies: Array) -> void:
	match GameState.layer_effect:
		Enums.LayerEffect.TOGETHER:
			# 玩家属性已在选层时一次性修改；此处只处理本场新生成的敌人
			# 修改 instance.max_hp 而非 data.max_hp，避免污染共享数据
			for enemy in enemies:
				enemy.max_hp = max(1, int(enemy.max_hp * 0.5))
				enemy.current_hp = max(1, int(enemy.current_hp * 0.5))
		Enums.LayerEffect.ECHO:
			# 回响形态：敌怪生命增加50%（向下取整）
			for enemy in enemies:
				enemy.max_hp = int(enemy.max_hp * 1.5)
				enemy.current_hp = int(enemy.current_hp * 1.5)
		Enums.LayerEffect.UNDYING, Enums.LayerEffect.NONE:
			pass  # 玩家属性已在选层时处理，或无需处理
