extends RefCounted
class_name DamageFormula

const StatRegistryScript: GDScript = preload("res://Stats/stat_registry.gd")

func evaluate(stat_system: Node, stat_id: String, entity_id: String, context: RefCounted, formula: Resource) -> Variant:
	if stat_id == StatRegistryScript.FINAL_DAMAGE:
		return _evaluate_final_damage(stat_system, entity_id, context, formula)
	if stat_id == StatRegistryScript.DAMAGE_RECEIVED:
		return _evaluate_damage_received(stat_system, entity_id, context)
	return 0


func _evaluate_final_damage(stat_system: Node, entity_id: String, context: RefCounted, formula: Resource) -> int:
	var params: Dictionary = formula.get("params") if formula != null else {}
	var base_damage: float = _get_context_float(context, "base_damage", float(params.get("base_damage", 0.0)))
	var multiplier: float = 1.0
	if stat_system != null and stat_system.has_method("get_stat"):
		multiplier = float(stat_system.call("get_stat", StatRegistryScript.DAMAGE_MULTIPLIER, entity_id))
	return max(0, roundi(base_damage * multiplier))


func _evaluate_damage_received(stat_system: Node, entity_id: String, context: RefCounted) -> int:
	var raw_damage: float = _get_context_float(context, "raw_damage", 0.0)
	var armor: float = 0.0
	var penetration: float = _get_context_float(context, "armor_penetration", 0.0)
	if stat_system != null and stat_system.has_method("get_stat"):
		armor = float(stat_system.call("get_stat", StatRegistryScript.ARMOR, entity_id))
	var mitigated: float = maxf(0.0, armor - penetration)
	return max(0, roundi(raw_damage - mitigated))


func _get_context_float(context: RefCounted, key: String, default_value: float) -> float:
	if context == null:
		return default_value
	var extra: Dictionary = context.get("extra")
	return float(extra.get(key, default_value))
