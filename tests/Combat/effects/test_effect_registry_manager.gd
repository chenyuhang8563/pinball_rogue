extends GutTest

## Verifies the relic effect table has a single source (EffectRegistry) and
## that EffectManager instantiates its active effects from that registry.

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

const RELIC_TYPES: Array = [
	Item.EffectType.LIGHTNING_CHAIN,
	Item.EffectType.FIRE_BELLOWS,
	Item.EffectType.POISON_CULTURE,
	Item.EffectType.ICE_HAMMER,
]

var _effect_manager: Node = null


func after_each() -> void:
	if _effect_manager != null and is_instance_valid(_effect_manager):
		var empty_loadout: RefCounted = LoadoutScript.new()
		_effect_manager.configure(empty_loadout, ProgressionScript.new(empty_loadout))
	_effect_manager = null


func test_effect_registry_is_the_single_relic_script_source() -> void:
	var registry: Node = get_node_or_null("/root/EffectRegistry")
	assert_not_null(registry)
	for effect_type: int in RELIC_TYPES:
		assert_not_null(registry.get_relic_script(effect_type), "type %d" % effect_type)
		assert_true(registry.has_relic_script(effect_type))
	assert_null(registry.get_relic_script(Item.EffectType.NONE))
	assert_false(registry.has_relic_script(Item.EffectType.NONE))


func test_effect_manager_instantiates_owned_relic_effects_from_registry() -> void:
	var loadout: RefCounted = LoadoutScript.new(
		func(_type: int, _fallback: int) -> int: return 10
	)
	var index: int = 0
	for effect_type: int in RELIC_TYPES:
		var relic := Item.new()
		relic.id = "relic_%d" % index
		relic.type = Item.ItemType.RELIC
		relic.effect_type = effect_type
		assert_true(loadout.call("add", relic))
		index += 1
	var progression: RefCounted = ProgressionScript.new(loadout)
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	assert_true(_effect_manager.configure(loadout, progression))

	var active: Dictionary = _effect_manager.get("_active_effects")
	assert_eq(active.size(), RELIC_TYPES.size(), "one active effect per owned relic type")
	for effect_type: int in RELIC_TYPES:
		assert_true(active.has(effect_type), "type %d active" % effect_type)
		assert_eq(int(active[effect_type].call("get_level")), 1)
