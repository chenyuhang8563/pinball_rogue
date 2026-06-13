extends Resource
class_name Item

enum EffectType {
	NONE,
	LIGHTNING_CHAIN,
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
