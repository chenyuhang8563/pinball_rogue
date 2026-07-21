extends Node

const StatInstanceScript: GDScript = preload("res://Core/stats/stat_instance.gd")
const StatContextScript: GDScript = preload("res://Core/stats/stat_context.gd")
const StatRegistryScript: GDScript = preload("res://Core/stats/stat_registry.gd")

var _stat_defs: Dictionary = {}
var _entities: Dictionary = {}
var _formula_strategy_cache: Dictionary = {}


func _init() -> void:
	_register_default_stats()


func get_stat(stat_id: String, entity_id: String = "", context: RefCounted = null) -> Variant:
	var stat_def: Resource = _stat_defs.get(stat_id) as Resource
	if stat_def == null:
		return 0
	if stat_def.get("formula") != null:
		return _evaluate_formula(stat_def, entity_id, context)

	var instance: RefCounted = _get_or_create_instance(entity_id, stat_id)
	if instance == null:
		return _format_value(stat_def, float(stat_def.get("base_value")))
	return instance.evaluate()


func add_modifier(entity_id: String, modifier: RefCounted) -> void:
	if modifier == null or String(modifier.get("stat_id")) == "":
		return
	var instance: RefCounted = _get_or_create_instance(entity_id, String(modifier.get("stat_id")))
	if instance == null:
		return
	instance.add_modifier(modifier)


func remove_modifier(entity_id: String, modifier_id: String) -> void:
	var entity_stats: Dictionary = _entities.get(_normalize_entity_id(entity_id), {})
	for value: Variant in entity_stats.values():
		var instance: RefCounted = value as RefCounted
		if instance != null:
			instance.remove_modifier(modifier_id)


func remove_modifiers_by_source(entity_id: String, source: String) -> void:
	var entity_stats: Dictionary = _entities.get(_normalize_entity_id(entity_id), {})
	for value: Variant in entity_stats.values():
		var instance: RefCounted = value as RefCounted
		if instance != null:
			instance.remove_modifiers_by_source(source)


func clear_modifiers(entity_id: String) -> void:
	var entity_stats: Dictionary = _entities.get(_normalize_entity_id(entity_id), {})
	for value: Variant in entity_stats.values():
		var instance: RefCounted = value as RefCounted
		if instance != null:
			instance.clear_modifiers()


func register_entity(entity_id: String, stat_ids: Array) -> void:
	var normalized_id: String = _normalize_entity_id(entity_id)
	if not _entities.has(normalized_id):
		_entities[normalized_id] = {}
	for stat_id: Variant in stat_ids:
		_get_or_create_instance(normalized_id, String(stat_id))


func unregister_entity(entity_id: String) -> void:
	_entities.erase(_normalize_entity_id(entity_id))


func register_stat(def: Resource) -> void:
	if def == null or String(def.get("id")) == "":
		return
	_stat_defs[String(def.get("id"))] = def


func set_stat_base(entity_id: String, stat_id: String, value: float) -> void:
	var instance: RefCounted = _get_or_create_instance(entity_id, stat_id)
	if instance != null:
		instance.set_base_value(value)


func get_damage(attacker_id: String, target_id: String, context: RefCounted = null) -> int:
	var ctx: RefCounted = context
	if ctx == null:
		ctx = StatContextScript.new(attacker_id, target_id, "damage")
	return int(get_stat(StatRegistryScript.FINAL_DAMAGE, attacker_id, ctx))


func get_speed(entity_id: String) -> float:
	return float(get_stat(StatRegistryScript.MAX_SPEED, entity_id))


func get_health(entity_id: String) -> int:
	return int(get_stat(StatRegistryScript.CURRENT_HEALTH, entity_id))


func get_max_health(entity_id: String) -> int:
	return int(get_stat(StatRegistryScript.MAX_HEALTH, entity_id))


func has_stat(stat_id: String) -> bool:
	return _stat_defs.has(stat_id)


func _register_default_stats() -> void:
	for path: String in StatRegistryScript.get_default_stat_paths():
		var stat_def: Resource = load(path) as Resource
		if stat_def != null:
			register_stat(stat_def)


func _get_or_create_instance(entity_id: String, stat_id: String) -> RefCounted:
	var stat_def: Resource = _stat_defs.get(stat_id) as Resource
	if stat_def == null:
		return null
	var normalized_id: String = _normalize_entity_id(entity_id)
	if not _entities.has(normalized_id):
		_entities[normalized_id] = {}
	var entity_stats: Dictionary = _entities[normalized_id]
	if not entity_stats.has(stat_id):
		entity_stats[stat_id] = StatInstanceScript.new(stat_def)
	return entity_stats[stat_id] as RefCounted


func _evaluate_formula(stat_def: Resource, entity_id: String, context: RefCounted) -> Variant:
	var formula: Resource = stat_def.get("formula") as Resource
	var evaluator: RefCounted = _get_formula_strategy(formula)
	if evaluator == null or not evaluator.has_method("evaluate"):
		return _format_value(stat_def, float(stat_def.get("base_value")))
	var value: Variant = evaluator.call("evaluate", self, String(stat_def.get("id")), entity_id, context, formula)
	if value is int or value is float:
		return _format_value(stat_def, float(value))
	return value


func _get_formula_strategy(formula: Resource) -> RefCounted:
	if formula == null:
		return null
	var formula_id: String = String(formula.get("formula_id"))
	var cache_key: String = formula.resource_path if formula.resource_path != "" else formula_id
	if _formula_strategy_cache.has(cache_key):
		return _formula_strategy_cache[cache_key] as RefCounted

	var script: GDScript = formula.get("strategy_script") as GDScript
	var strategy_name: String = String(formula.get("strategy_name"))
	if script == null and strategy_name != "":
		script = load("res://Core/stats/formulas/%s_formula.gd" % strategy_name) as GDScript
	if script == null:
		return null

	var evaluator: RefCounted = script.new()
	_formula_strategy_cache[cache_key] = evaluator
	return evaluator


func _format_value(stat_def: Resource, value: float) -> Variant:
	var clamped_value: float = clampf(value, float(stat_def.get("min_value")), float(stat_def.get("max_value")))
	return roundi(clamped_value) if bool(stat_def.get("integer")) else clamped_value


func _normalize_entity_id(entity_id: String) -> String:
	return "_global" if entity_id == "" else entity_id
