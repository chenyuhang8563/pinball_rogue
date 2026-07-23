extends Resource
class_name Item

enum EffectType {
	NONE,
	# --- 遗物效果 —— 由 EffectManager 在战斗事件中分发 ---
	LIGHTNING_CHAIN,
	# --- 弹珠解锁效果 —— Item 自身携带弹珠链数据，main.gd 启动/补球时读取 ---
	BOMB_MARBLE,
	BROWN_MARBLE,
	DARK_MARBLE,  # 默认黑色弹珠，初始即拥有
	BLUE_MARBLE,
	FIRE_MARBLE,
	FIRE_BELLOWS,
	POISON_CULTURE,
	ICE_HAMMER,
	ASSASSIN_MARBLE,
	ASSASSINS_WHETSTONE,
	FORTUNA_DICE,
	MANY_FACED_PRISM,
	SCARLET_THREAD,
	EXECUTION_DECREE,
	ACCELERANT,
	CREMATION,
	THERMAL_SHOCK,
	MIASMA,
}

enum ItemType {
	NONE,
	MARBLE,
	RELIC,
	SKILL,
}

enum Rarity {
	COMMON,
	UNCOMMON,
	RARE,
	BOSS,
	CURSE,
}

@export var id: String = ""
@export var title: String
@export var icon: Texture2D
@export var price: int = 1
@export var description: String = ""
@export var effect_type: EffectType = EffectType.NONE
@export var type: ItemType = ItemType.NONE
@export var rarity: Rarity = Rarity.COMMON
@export var tags: Array[StringName] = []
@export var weight: float = 1.0
@export var requires_tags: Array[StringName] = []
@export var marble_type: Marble.MARBLE_TYPE = Marble.MARBLE_TYPE.DEFAULT
@export var marble_segment_damage: int = 1
@export var skill_definition: SkillDefinition
