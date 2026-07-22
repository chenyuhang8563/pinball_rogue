extends Node

## Relic effect registry — the single source mapping `Item.EffectType` to relic
## effect scripts. EffectManager instantiates active relic effects from here;
## no other copy of this table exists.
const RELIC_EFFECT_SCRIPTS: Dictionary = {
	&"lightning": preload("res://Combat/effects/lightning_effect/lightning.gd"),
	&"fire_bellows": preload("res://Combat/effects/fire_bellows/fire_bellows.gd"),
	&"poison_culture": preload("res://Combat/effects/poison_culture/poison_culture.gd"),
	&"ice_hammer": preload("res://Combat/effects/ice_hammer/ice_hammer.gd"),
}


func get_relic_script(item_id: StringName) -> GDScript:
	if not RELIC_EFFECT_SCRIPTS.has(item_id):
		return null
	return RELIC_EFFECT_SCRIPTS[item_id] as GDScript


func has_relic_script(item_id: StringName) -> bool:
	return RELIC_EFFECT_SCRIPTS.has(item_id)
