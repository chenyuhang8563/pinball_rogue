extends RefCounted
class_name StatInstance

const OP_ADD: int = 0
const OP_MULTIPLY: int = 1
const OP_OVERRIDE: int = 2

var definition: Resource = null
var base_value: float = 0.0

var _modifiers: Dictionary = {}
var _modifier_order: Array[String] = []
var _dirty: bool = true
var _cached_value: Variant = 0.0


func _init(p_definition: Resource = null) -> void:
	definition = p_definition
	if definition != null:
		base_value = float(definition.get("base_value"))


func set_base_value(value: float) -> void:
	base_value = value
	_dirty = true


func add_modifier(modifier: RefCounted) -> void:
	if modifier == null:
		return
	var modifier_stat_id: String = String(modifier.get("stat_id"))
	var definition_id: String = String(definition.get("id")) if definition != null else ""
	if definition != null and modifier_stat_id != "" and modifier_stat_id != definition_id:
		return
	var modifier_id: String = String(modifier.get("id"))
	if not _modifiers.has(modifier_id):
		_modifier_order.append(modifier_id)
	_modifiers[modifier_id] = modifier
	_dirty = true


func remove_modifier(modifier_id: String) -> void:
	if not _modifiers.has(modifier_id):
		return
	_modifiers.erase(modifier_id)
	_modifier_order.erase(modifier_id)
	_dirty = true


func remove_modifiers_by_source(source: String) -> void:
	var ids_to_remove: Array[String] = []
	for modifier_id: String in _modifier_order:
		var modifier: RefCounted = _modifiers.get(modifier_id) as RefCounted
		if modifier != null and String(modifier.get("source")) == source:
			ids_to_remove.append(modifier_id)
	for modifier_id: String in ids_to_remove:
		remove_modifier(modifier_id)


func clear_modifiers() -> void:
	if _modifiers.is_empty():
		return
	_modifiers.clear()
	_modifier_order.clear()
	_dirty = true


func get_modifiers() -> Array[RefCounted]:
	var result: Array[RefCounted] = []
	for modifier_id: String in _modifier_order:
		var modifier: RefCounted = _modifiers.get(modifier_id) as RefCounted
		if modifier != null:
			result.append(modifier)
	return result


func evaluate() -> Variant:
	if not _dirty:
		return _cached_value

	var value: float = base_value
	var additive_total: float = 0.0
	var multiplicative_total: float = 1.0
	var has_override: bool = false
	var override_value: float = 0.0

	for modifier_id: String in _modifier_order:
		var modifier: RefCounted = _modifiers.get(modifier_id) as RefCounted
		if modifier == null:
			continue
		match int(modifier.get("operation")):
			OP_ADD:
				additive_total += float(modifier.get("value"))
			OP_MULTIPLY:
				multiplicative_total *= float(modifier.get("value"))
			OP_OVERRIDE:
				has_override = true
				override_value = float(modifier.get("value"))
			_:
				push_warning("Unknown StatModifier operation: %s" % str(modifier.get("operation")))

	value = (value + additive_total) * multiplicative_total
	if has_override:
		value = override_value

	if definition != null:
		value = clampf(value, float(definition.get("min_value")), float(definition.get("max_value")))
		if bool(definition.get("integer")):
			_cached_value = roundi(value)
		else:
			_cached_value = value
	else:
		_cached_value = value

	_dirty = false
	return _cached_value
