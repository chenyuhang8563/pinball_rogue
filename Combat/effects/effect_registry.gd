extends Node

## Relic effect registry — the single source mapping `Item.EffectType` to relic
## effect scripts. EffectManager instantiates active relic effects from here;
## no other copy of this table exists.
const RELIC_EFFECT_SCRIPTS: Dictionary = {
	&"lightning": preload("res://Combat/effects/lightning_effect/lightning.gd"),
	&"leyden_jar": preload("res://Combat/effects/leyden_jar/leyden_jar.gd"),
	&"arc_relay": preload("res://Combat/effects/arc_relay/arc_relay.gd"),
	&"thunderstorm": preload("res://Combat/effects/thunderstorm/thunderstorm.gd"),
	&"fire_bellows": preload("res://Combat/effects/fire_bellows/fire_bellows.gd"),
	&"accelerant": preload("res://Combat/effects/accelerant/accelerant.gd"),
	&"poison_culture": preload("res://Combat/effects/poison_culture/poison_culture.gd"),
	&"ice_hammer": preload("res://Combat/effects/ice_hammer/ice_hammer.gd"),
	&"assassins_whetstone": preload("res://Combat/effects/assassins_whetstone/assassins_whetstone.gd"),
	&"fortuna_dice": preload("res://Combat/effects/fortuna_dice/fortuna_dice.gd"),
	&"many_faced_prism": preload("res://Combat/effects/many_faced_prism/many_faced_prism.gd"),
	&"scarlet_thread": preload("res://Combat/effects/scarlet_thread/scarlet_thread.gd"),
	&"execution_decree": preload("res://Combat/effects/execution_decree/execution_decree.gd"),
	&"permafrost": preload("res://Combat/effects/permafrost/permafrost.gd"),
	&"cryoclasm": preload("res://Combat/effects/cryoclasm/cryoclasm.gd"),
	&"cremation": preload("res://Combat/effects/cremation/cremation.gd"),
	&"thermal_shock": preload("res://Combat/effects/thermal_shock/thermal_shock.gd"),
	&"miasma": preload("res://Combat/effects/miasma/miasma.gd"),
	&"carrion": preload("res://Combat/effects/carrion/carrion.gd"),
	&"parasite": preload("res://Combat/effects/parasite/parasite.gd"),
	&"pustule": preload("res://Combat/effects/pustule/pustule.gd"),
	&"venom_knife": preload("res://Combat/effects/venom_knife/venom_knife.gd"),
	&"scorpion_tail": preload("res://Combat/effects/scorpion_tail/scorpion_tail.gd"),
	&"witch_hat": preload("res://Combat/effects/witch_hat/witch_hat.gd"),
	&"grindstone": preload("res://Combat/effects/grindstone/grindstone.gd"),
	&"drop_hammer": preload("res://Combat/effects/drop_hammer/drop_hammer.gd"),
	&"battering_ram": preload("res://Combat/effects/battering_ram/battering_ram.gd"),
}


func get_relic_script(item_id: StringName) -> GDScript:
	if not RELIC_EFFECT_SCRIPTS.has(item_id):
		return null
	return RELIC_EFFECT_SCRIPTS[item_id] as GDScript


func has_relic_script(item_id: StringName) -> bool:
	return RELIC_EFFECT_SCRIPTS.has(item_id)
