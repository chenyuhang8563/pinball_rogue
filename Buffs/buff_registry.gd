extends Node

## Registry for buff definitions.
##
## The registry mirrors the relic EffectRegistry pattern: stable buff ids map
## to scripts that construct BuffDef resources for BuffManager.

const BUFF_DEFS: Dictionary = {
	"damage_up": preload("res://Buffs/buffs/damage_up.gd"),
	"speed_up": preload("res://Buffs/buffs/speed_up.gd"),
	"shield": preload("res://Buffs/buffs/shield.gd"),
	"poison_debuff": preload("res://Buffs/buffs/poison_debuff.gd"),
}


func get_buff_def(buff_id: String) -> BuffDef:
	if not BUFF_DEFS.has(buff_id):
		return null

	var script: GDScript = BUFF_DEFS[buff_id]
	var provider: Variant = script.new()
	if provider is BuffDef:
		return provider as BuffDef
	if provider == null or not provider.has_method("get_definition"):
		push_error("BuffRegistry.get_buff_def: provider for '%s' has no get_definition()" % buff_id)
		return null

	return provider.call("get_definition") as BuffDef


func has_buff(buff_id: String) -> bool:
	return BUFF_DEFS.has(buff_id)
