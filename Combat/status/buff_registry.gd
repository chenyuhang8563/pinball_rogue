extends Node

## Registry for buff definitions — the single source for constructing BuffDef
## resources. Stable buff ids map to scripts that extend BuffDef. Enemy status
## debuffs (poison/frost/frozen/burn) are all obtained here; marbles and relic
## effects never preload buff scripts directly.

const BUFF_DEFS: Dictionary = {
	"poison_debuff": preload("res://Combat/status/buffs/poison_debuff.gd"),
	"frost_debuff": preload("res://Combat/status/buffs/frost_debuff.gd"),
	"frozen_debuff": preload("res://Combat/status/buffs/frozen_debuff.gd"),
	"fire_burn_debuff": preload("res://Combat/status/buffs/fire_burn_debuff.gd"),
}


func get_buff_def(buff_id: String) -> BuffDef:
	if not BUFF_DEFS.has(buff_id):
		return null
	var definition: Variant = BUFF_DEFS[buff_id].new()
	if definition is BuffDef:
		return definition as BuffDef
	push_error("BuffRegistry.get_buff_def: '%s' does not extend BuffDef" % buff_id)
	return null


func has_buff(buff_id: String) -> bool:
	return BUFF_DEFS.has(buff_id)
