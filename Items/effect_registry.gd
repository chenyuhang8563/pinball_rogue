extends Node

## Relic effect registry — the single source mapping `Item.EffectType` to relic
## effect scripts. EffectManager instantiates active relic effects from here;
## no other copy of this table exists.
const RELIC_EFFECT_SCRIPTS: Dictionary = {
	Item.EffectType.LIGHTNING_CHAIN: preload("res://Effects/lightning_effect/lightning.gd"),
	Item.EffectType.FIRE_BELLOWS: preload("res://Effects/fire_bellows/fire_bellows.gd"),
	Item.EffectType.POISON_CULTURE: preload("res://Effects/poison_culture/poison_culture.gd"),
	Item.EffectType.ICE_HAMMER: preload("res://Effects/ice_hammer/ice_hammer.gd"),
}


func get_relic_script(effect_type: int) -> GDScript:
	if not RELIC_EFFECT_SCRIPTS.has(effect_type):
		return null
	return RELIC_EFFECT_SCRIPTS[effect_type] as GDScript


func has_relic_script(effect_type: int) -> bool:
	return RELIC_EFFECT_SCRIPTS.has(effect_type)
