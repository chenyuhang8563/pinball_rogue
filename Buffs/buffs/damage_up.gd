extends RefCounted

## Permanent stackable damage buff definition.


func get_definition() -> BuffDef:
	var buff: BuffDef = BuffDef.new()
	buff.id = "damage_up"
	buff.display_name = "BUFF_DAMAGE_UP_TITLE"
	buff.description = "BUFF_DAMAGE_UP_DESC"
	buff.duration = -1.0
	buff.stackable = true
	buff.max_stacks = 3
	buff.source = BuffDef.BuffSource.SHOP
	buff.params = {
		"damage_bonus": 0.25,
	}
	return buff
