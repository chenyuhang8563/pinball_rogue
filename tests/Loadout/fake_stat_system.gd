extends Node

var values: Dictionary = {}
var registered: Dictionary = {}
var modifiers: Array[RefCounted] = []


func get_stat(stat_id: String, _entity_id: String) -> Variant:
	return values.get(stat_id, 0.0)


func register_entity(entity_id: String, stat_ids: Array) -> void:
	registered[entity_id] = stat_ids.duplicate()


func add_modifier(_entity_id: String, modifier: RefCounted) -> void:
	modifiers.append(modifier)


func remove_modifiers_by_source(_entity_id: String, source: String) -> void:
	modifiers = modifiers.filter(func(modifier: RefCounted) -> bool: return modifier.source != source)


func modifier_value(stat_id: String) -> Variant:
	for modifier: RefCounted in modifiers:
		if modifier.stat_id == stat_id:
			return modifier.value
	return null
