extends GutTest

## Verifies the poison-cycle inversion: buffs emit a typed tick event and never
## call the Effect domain; the host facade forwards poison ticks to
## EffectManager.on_poison_tick, which drives poison_culture spread.

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

var _effect_manager: Node = null
var _loadout: RefCounted = null
var _progression: RefCounted = null


func after_each() -> void:
	if _effect_manager != null and is_instance_valid(_effect_manager):
		var empty_loadout: RefCounted = LoadoutScript.new()
		var empty_progression: RefCounted = ProgressionScript.new(empty_loadout)
		_effect_manager.configure(empty_loadout, empty_progression)
	_effect_manager = null
	_loadout = null
	_progression = null


func test_host_facade_emits_typed_buff_tick_event() -> void:
	var enemy: Enemy = _enemy()
	var ticks: Array[Dictionary] = []
	var callback := func(buff_id: String, host: Node) -> void:
		ticks.append({&"id": buff_id, &"host": host})
	enemy.buff_host.buff_ticked.connect(callback)

	enemy.notify_buff_ticked("poison_debuff")

	assert_eq(ticks.size(), 1)
	assert_eq(ticks[0][&"id"], "poison_debuff")
	assert_eq(ticks[0][&"host"], enemy)
	enemy.buff_host.buff_ticked.disconnect(callback)


func test_poison_spread_only_happens_through_tick_events() -> void:
	_configure_poison_culture()
	var source: Enemy = _enemy()
	var neighbor: Enemy = _enemy()
	neighbor.global_position = source.global_position + Vector2(24, 0)
	GreenMarble.apply_poison_to_enemy(source)
	assert_true(source.has_buff("poison_debuff"))
	# No tick processed yet -> poison_culture must not have spread anything.
	assert_false(neighbor.has_buff("poison_debuff"), "no tick, no spread")


func test_poison_tick_reaches_poison_culture_via_typed_event() -> void:
	_configure_poison_culture()
	var source: Enemy = _enemy()
	var neighbor: Enemy = _enemy()
	neighbor.global_position = source.global_position + Vector2(24, 0)
	GreenMarble.apply_poison_to_enemy(source)
	assert_false(neighbor.has_buff("poison_debuff"))

	# Drive several poison ticks through the BuffHost; each tick emits the typed
	# event the host forwards to EffectManager.on_poison_tick.
	for i: int in range(5):
		source.buff_host._process(1.1)

	assert_true(source.has_buff("poison_debuff"), "poison still active during the test")
	assert_true(
		neighbor.has_buff("poison_debuff"),
		"poison_culture spreads poison once enough typed ticks arrive"
	)


func _configure_poison_culture() -> void:
	_loadout = LoadoutScript.new()
	var relic := Item.new()
	relic.id = "poison_culture"
	relic.type = Item.ItemType.RELIC
	assert_true(_loadout.call("add", relic))
	_progression = ProgressionScript.new(_loadout)
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	assert_true(_effect_manager.configure(_loadout, _progression))


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
