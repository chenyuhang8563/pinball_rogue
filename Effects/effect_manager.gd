extends Node

const EFFECT_SCRIPTS: Dictionary = {
	Item.EffectType.LIGHTNING_CHAIN: preload("res://Effects/lightning_effect/lightning.gd"),
	Item.EffectType.FIRE_BELLOWS: preload("res://Effects/fire_bellows/fire_bellows.gd"),
	Item.EffectType.POISON_CULTURE: preload("res://Effects/poison_culture/poison_culture.gd"),
	Item.EffectType.ICE_HAMMER: preload("res://Effects/ice_hammer/ice_hammer.gd"),
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


func on_enemy_hit_resolved(enemy: Node2D, was_burning: bool, was_frozen: bool) -> void:
	_dispatch("on_enemy_hit_resolved", [enemy, was_burning, was_frozen])


func on_poison_tick(enemy: Node2D) -> void:
	_dispatch("on_poison_tick", [enemy])


func _sync_active_effects() -> void:
	var owned_effect_levels := _get_owned_effect_levels()
	var owned_effects: Array = owned_effect_levels.keys()

	for effect_type in owned_effects:
		if not _active_effects.has(effect_type):
			_active_effects[effect_type] = EFFECT_SCRIPTS[effect_type].new()
		var effect: Variant = _active_effects[effect_type]
		if effect != null and effect.has_method("set_level"):
			var effect_state: Dictionary = owned_effect_levels[effect_type]
			effect.call("set_level", int(effect_state.get("level", 1)))
			if effect.has_method("set_awakened"):
				effect.call("set_awakened", bool(effect_state.get("awakened", false)))

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
		var awakened: bool = false
		if inventory.has_method("get_relic_level"):
			level = max(1, int(inventory.call("get_relic_level", item)))
		if inventory.has_method("is_relic_awakened"):
			awakened = bool(inventory.call("is_relic_awakened", item))
		var effect_key: int = int(item.effect_type)
		var previous: Dictionary = owned_effects.get(effect_key, {"level": 0, "awakened": false})
		owned_effects[effect_key] = {
			"level": maxi(int(previous.get("level", 0)), level),
			"awakened": bool(previous.get("awakened", false)) or awakened,
		}
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
