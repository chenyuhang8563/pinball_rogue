extends Resource
class_name Item

enum EffectType {
	NONE,
	# --- 遗物效果 —— 由 EffectManager 在战斗事件中分发 ---
	LIGHTNING_CHAIN,
	# --- 弹珠解锁效果 —— 由 EffectRegistry 提供生成数据，main.gd 启动/补球时读取 ---
	BOMB_MARBLE,
	BROWN_MARBLE,
	DARK_MARBLE,  # 默认黑色弹珠，初始即拥有
}

enum ItemType {
	NONE,
	MARBLE,
	RELIC,
}

@export var id: String = ""
@export var title: String
@export var icon: Texture2D
@export var price: int = 1
@export var description: String = ""
@export var effect_type: EffectType = EffectType.NONE
@export var type: ItemType = ItemType.NONE
