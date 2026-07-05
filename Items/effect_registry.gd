extends Node

## Relic effect registry.
##
## Marble chain data now lives directly on Item resources.
const RELIC_EFFECT_SCRIPTS: Dictionary = {
	Item.EffectType.LIGHTNING_CHAIN: preload("res://Effects/lightning_effect/lightning.gd"),
}


func _ready() -> void:
	pass


func get_relic_script(effect_type: int) -> GDScript:
	if not RELIC_EFFECT_SCRIPTS.has(effect_type):
		return null
	return RELIC_EFFECT_SCRIPTS[effect_type] as GDScript


func get_relic_effect_types(inventory: Node) -> Array[int]:
	var owned: Array[int] = []
	if inventory == null:
		return owned

	var raw_relic_items: Variant = inventory.get("relic_items")
	if not raw_relic_items is Array:
		return owned

	var relic_items: Array = raw_relic_items
	for item: Item in relic_items:
		if item == null:
			continue
		if item.effect_type == Item.EffectType.NONE:
			continue
		if not RELIC_EFFECT_SCRIPTS.has(item.effect_type):
			continue
		if not owned.has(item.effect_type):
			owned.append(item.effect_type)
	return owned
