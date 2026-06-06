extends Node

const EFFECT_SCRIPTS: Dictionary = {
	Item.EffectType.LIGHTNING_CHAIN: preload("res://Effects/lightning_effect/lightning.gd"),
}

var _active_effects: Dictionary = {}


func _ready() -> void:
	Inventory.inventory_changed.connect(_sync_active_effects)
	_sync_active_effects()


func on_enemy_hit_by_marble(enemy: Node2D) -> void:
	_dispatch("on_enemy_hit_by_marble", [enemy])


func _sync_active_effects() -> void:
	var owned_effects := _get_owned_effect_types()

	for effect_type in owned_effects:
		if not _active_effects.has(effect_type):
			_active_effects[effect_type] = EFFECT_SCRIPTS[effect_type].new()

	for effect_type in _active_effects.keys():
		if not owned_effects.has(effect_type):
			_active_effects.erase(effect_type)


func _get_owned_effect_types() -> Array[int]:
	var owned_effects: Array[int] = []
	for item in Inventory.items:
		if item == null:
			continue
		if item.effect_type == Item.EffectType.NONE:
			continue
		if not EFFECT_SCRIPTS.has(item.effect_type):
			continue
		if not owned_effects.has(item.effect_type):
			owned_effects.append(item.effect_type)
	return owned_effects


func _dispatch(method_name: StringName, args: Array) -> void:
	for effect in _active_effects.values():
		if effect.has_method(method_name):
			effect.callv(method_name, args)