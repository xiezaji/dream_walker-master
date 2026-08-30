class_name Enums

enum CardType { ATTACK, SKILL, POWER, CURSE }

enum Rarity { STARTER, COMMON, RARE, EPIC, LEGENDARY }

enum EffectType {
	DEAL_DAMAGE,
	GAIN_BLOCK,
	DRAW_CARDS,
	ADD_ENERGY,
	HEAL,
	REDUCE_ENEMY_DEFENSE,
	BORROW_ENERGY,
	BORROW_DRAW,
	BORROW_DAMAGE,
	BORROW_STATS,
	BORROW_HP,
	TRUE_DAMAGE_MODE,
	APPLY_STATUS,
	LOSE_HP,          # 等价交换：失去X点生命
	GAIN_STATS,       # 等价交换：永久增加ATK/DEF各X点（本场）
	SELF_DEF_PENALTY, # 预借AOE：防御力-X
	ESCALATING_HIT,   # 重拳出击：伤害随使用次数提升
	POWER_DRAW_ON_HP, # 生命如歌：HP变动时抽1张牌（被动）
	PICK_FROM_DRAW,   # 先知：从抽牌堆选1张加入手牌（不洗牌）
}

## 状态效果类型
enum StatusEffectType {
	CORRUPTION,  # 腐化：防御-10，永久
	WEAK,        # 虚弱：攻击-8，持续N回合
	SLEEP,       # 沉睡：本回合不能行动，持续1回合
	DROWSY,      # 困倦：每回合少抽1张牌，持续N回合
	NIGHTMARE,   # 噩梦：本回合手牌显示"???"，持续1回合
}

enum TargetType { SELF, ONE_ENEMY, ALL_ENEMIES, RANDOM_ENEMY }

enum BattlePhase {
	START_OF_TURN,
	PLAYER_TURN,
	END_OF_TURN,
	ENEMY_TURN,
	END_OF_ENEMY,
	BATTLE_END
}

enum LayerEffect { NONE, TOGETHER, ECHO, UNDYING }

enum NodeType { BOON, BATTLE, ELITE, BOSS, SHOP, QUESTION }

enum IntentType { ATTACK, DEBUFF, BUFF, IMMUNE, HEAL_SELF, SUMMON, SLEEPING }

enum BoonType { DELETE_CARD, RARE_CARD, RANDOM_RELIC, CHOOSE_LAYER, MAX_HP }

enum RelicRarity { COMMON, EPIC }

enum EventType { SLEEPING_MERCHANT, WARM_BED, FOUNTAIN_OF_FORGETTING }
