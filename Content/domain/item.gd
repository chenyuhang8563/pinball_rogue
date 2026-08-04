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
	# --- 瘟疫流派遗物 ---
	CARRION,
	PARASITE,
	PUSTULE,
	# --- 通用毒系遗物（不依赖瘟疫苍蝇） ---
	VENOM_KNIFE,
	SCORPION_TAIL,
	WITCH_HAT,
	LIGHTNING_MARBLE,
	LEYDEN_JAR,
	ARC_RELAY,
	THUNDERSTORM,
	# --- 回响流派遗物（动能工坊） ---
	GRINDSTONE,
	DROP_HAMMER,
	BATTERING_RAM,
	# --- 炸弹系弹药遗物（追加到末尾，勿插入中间——枚举整数序列化） ---
	# 索引自 33 起，避开回响系已占用的 30-32；弹药遗物 .tres 的 effect_type 与此对齐。
	AMMO_POUCH,
	AMMO_RECYCLER,
	HIGH_EXPLOSIVE,
	LAST_SHOT,
	AMMO_DUMP,
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
