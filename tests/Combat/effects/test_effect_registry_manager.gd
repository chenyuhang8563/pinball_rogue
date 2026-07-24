extends GutTest

## Verifies the relic effect table has a single source (EffectRegistry) and
## that EffectManager instantiates its active effects from that registry.

const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

const RELIC_IDS: Array[StringName] = [
	&"lightning",
	&"fire_bellows",
	&"poison_culture",
	&"ice_hammer",
	&"carrion",
	&"parasite",
	&"pustule",
	&"venom_knife",
	&"scorpion_tail",
	&"witch_hat",
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
	for relic_id: StringName in RELIC_IDS:
		assert_not_null(registry.get_relic_script(relic_id), "id %s" % relic_id)
		assert_true(registry.has_relic_script(relic_id))
	assert_null(registry.get_relic_script(&"missing"))
	assert_false(registry.has_relic_script(&"missing"))


func test_effect_manager_instantiates_owned_relic_effects_from_registry() -> void:
	var loadout: RefCounted = LoadoutScript.new(
		func(_type: int, _fallback: int) -> int: return 10
	)
	for relic_id: StringName in RELIC_IDS:
		var relic := Item.new()
		relic.id = relic_id
		relic.type = Item.ItemType.RELIC
		assert_true(loadout.call("add", relic))
	var progression: RefCounted = ProgressionScript.new(loadout)
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	assert_true(_effect_manager.configure(loadout, progression))

	var active: Dictionary = _effect_manager.get("_active_effects")
	assert_eq(active.size(), RELIC_IDS.size(), "one active effect per owned relic id")
	for relic_id: StringName in RELIC_IDS:
		assert_true(active.has(relic_id), "id %s active" % relic_id)
		assert_eq(int(active[relic_id].call("get_level")), 1)
