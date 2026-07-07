extends Node

const EFFECT_SCRIPTS: Dictionary = {
	Item.EffectType.LIGHTNING_CHAIN: preload("res://Effects/lightning_effect/lightning.gd"),
}

var _active_effects: Dictionary = {}


func _ready() -> void:
	var inventory: Node = _get_inventory()
	if inventory != null and inventory.has_signal(&"inventory_changed"):
		var callable := Callable(self, "_sync_active_effects")
		if not inventory.is_connected(&"inventory_changed", callable):
			inventory.connect(&"inventory_changed", callable)
	_sync_active_effects()


func on_enemy_hit_by_marble(enemy: Node2D) -> void:
	_dispatch("on_enemy_hit_by_marble", [enemy])


func _sync_active_effects() -> void:
	var owned_effect_levels := _get_owned_effect_levels()
	var owned_effects: Array = owned_effect_levels.keys()

	for effect_type in owned_effects:
		if not _active_effects.has(effect_type):
			_active_effects[effect_type] = EFFECT_SCRIPTS[effect_type].new()
		var effect: Variant = _active_effects[effect_type]
		if effect != null and effect.has_method("set_level"):
			effect.call("set_level", int(owned_effect_levels[effect_type]))

	for effect_type in _active_effects.keys():
		if not owned_effects.has(effect_type):
			_active_effects.erase(effect_type)


func _get_owned_effect_types() -> Array[int]:
	var owned_effects: Array[int] = []
	for effect_type: int in _get_owned_effect_levels().keys():
		owned_effects.append(effect_type)
	return owned_effects


func _get_owned_effect_levels() -> Dictionary:
	var owned_effects: Dictionary = {}
	var inventory: Node = _get_inventory()
	if inventory == null:
		return owned_effects

	var raw_relic_items: Variant = inventory.get("relic_items")
	if not raw_relic_items is Array:
		return owned_effects

	var relic_items: Array = raw_relic_items
	for item: Item in relic_items:
		if item == null:
			continue
		if item.effect_type == Item.EffectType.NONE:
			continue
		if not EFFECT_SCRIPTS.has(item.effect_type):
			continue
		var level: int = 1
		if inventory.has_method("get_relic_level"):
			level = max(1, int(inventory.call("get_relic_level", item)))
		var effect_key: int = int(item.effect_type)
		owned_effects[effect_key] = maxi(int(owned_effects.get(effect_key, 0)), level)
	return owned_effects


func _dispatch(method_name: StringName, args: Array) -> void:
	for effect in _active_effects.values():
		if effect.has_method(method_name):
			effect.callv(method_name, args)


func _get_inventory() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("Inventory")
