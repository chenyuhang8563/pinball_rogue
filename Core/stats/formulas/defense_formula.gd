extends RefCounted
class_name DefenseFormula


func evaluate(_stat_system: Node, _stat_id: String, _entity_id: String, _context: RefCounted, formula: Resource) -> Variant:
	var params: Dictionary = formula.get("params") if formula != null else {}
	return params.get("value", 0.0)
