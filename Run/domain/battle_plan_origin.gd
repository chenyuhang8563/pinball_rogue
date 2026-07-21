extends RefCounted
class_name BattlePlanOrigin

enum Context {
	RUN_START,
	NODE,
	EVENT,
	BOSS,
}

enum Encounter {
	NORMAL,
	ELITE,
	BOSS,
}

var context: Context
var encounter: Encounter


func _init(value_context: Context, value_encounter: Encounter) -> void:
	context = value_context
	encounter = value_encounter


func is_valid() -> bool:
	match context:
		Context.RUN_START:
			return encounter == Encounter.NORMAL
		Context.NODE:
			return encounter == Encounter.NORMAL or encounter == Encounter.ELITE
		Context.EVENT:
			return encounter == Encounter.ELITE
		Context.BOSS:
			return encounter == Encounter.BOSS
	return false


static func run_start() -> BattlePlanOrigin:
	return BattlePlanOrigin.new(Context.RUN_START, Encounter.NORMAL)


static func normal_node() -> BattlePlanOrigin:
	return BattlePlanOrigin.new(Context.NODE, Encounter.NORMAL)


static func elite_node() -> BattlePlanOrigin:
	return BattlePlanOrigin.new(Context.NODE, Encounter.ELITE)


static func crossroads() -> BattlePlanOrigin:
	return BattlePlanOrigin.new(Context.EVENT, Encounter.ELITE)


static func boss() -> BattlePlanOrigin:
	return BattlePlanOrigin.new(Context.BOSS, Encounter.BOSS)
