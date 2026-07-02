extends RefCounted

## Permanent stackable damage buff definition.


func get_definition() -> BuffDef:
	var buff: BuffDef = BuffDef.new()
	buff.id = "damage_up"
	buff.display_name = "Damage Up"
	buff.description = "Increases marble-chain damage."
	buff.duration = -1.0
	buff.stackable = true
	buff.max_stacks = 3
	buff.source = BuffDef.BuffSource.SHOP
	buff.params = {
		"damage_bonus": 0.25,
	}
	return buff
