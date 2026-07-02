extends RefCounted

## Stackable temporary shield buff definition.


func get_definition() -> BuffDef:
	var buff: BuffDef = BuffDef.new()
	buff.id = "shield"
	buff.display_name = "Shield"
	buff.description = "Adds temporary shield charges."
	buff.duration = 8.0
	buff.stackable = true
	buff.max_stacks = 5
	buff.source = BuffDef.BuffSource.CHAIN_MECHANIC
	buff.params = {
		"shield_charges": 1,
	}
	return buff
