extends RefCounted

## Temporary non-stackable speed buff definition.


func get_definition() -> BuffDef:
	var buff: BuffDef = BuffDef.new()
	buff.id = "speed_up"
	buff.display_name = "BUFF_SPEED_UP_TITLE"
	buff.description = "BUFF_SPEED_UP_DESC"
	buff.duration = 3.0
	buff.stackable = false
	buff.max_stacks = 1
	buff.source = BuffDef.BuffSource.COMBAT_DROP
	buff.params = {
		"marble_speed_multiplier": 1.2,
		"dash_speed_multiplier": 1.2,
	}
	return buff
