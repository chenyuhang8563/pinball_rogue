extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const LightningStaffItem: Item = preload("res://Content/data/lightning.tres")
const ArcRelayItem: Item = preload("res://Content/data/arc_relay.tres")
const LightningMarbleItem: Item = preload("res://Content/data/lightning_marble.tres")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

## Sweeps every runtime _spawn_link site across a matrix of death-timing scenarios
## and asserts NO spawned link sits at (or near) world origin — the top-left corner.

var _captured_effects: Array[AnimatedSprite2D] = []
var _node_added_callback: Callable = Callable()
var _dummy_scene: Node2D = null
var _loadout: RefCounted = null
var _progression: RefCounted = null


func before_each() -> void:
	_captured_effects = []
	_dummy_scene = Node2D.new()
	_dummy_scene.name = "LinkSweepScene"
	get_tree().root.add_child(_dummy_scene)
	get_tree().current_scene = _dummy_scene
	_node_added_callback = Callable(self, "_on_node_added")
	get_tree().node_added.connect(_node_added_callback)

	_loadout = LoadoutScript.new()
	_progression = ProgressionScript.new(_loadout)
	assert_true(_loadout.call("add", LightningMarbleItem))
	var effect_manager: Node = get_node_or_null("/root/EffectManager")
	assert_not_null(effect_manager)
	assert_true(effect_manager.call("configure", _loadout, _progression))
	var runtime: Variant = effect_manager.get("_lightning_runtime")
	if runtime != null:
		runtime.call("set_visuals_enabled", true)


func after_each() -> void:
	if get_tree() != null:
		get_tree().node_added.disconnect(_node_added_callback)
	for effect: AnimatedSprite2D in _captured_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	if _dummy_scene != null and is_instance_valid(_dummy_scene):
		_dummy_scene.queue_free()
		_dummy_scene = null
	get_tree().current_scene = null


func _on_node_added(node: Node) -> void:
	if node is AnimatedSprite2D and node.get_script() != null:
		var script_path: String = str(node.get_script().resource_path) if node.get_script().resource_path != null else ""
		if script_path.ends_with("lightning_effect.gd"):
			_captured_effects.append(node as AnimatedSprite2D)


func _enemy(hit_points: int, position: Vector2) -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	enemy.health = hit_points
	add_child_autofree(enemy)
	enemy.global_position = position
	return enemy


func _chain(item) -> MarbleChain:
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	chain.build_chain([item], [Vector2.ZERO])
	return chain


func _assert_all_links_not_at_origin(context: String) -> void:
	push_warning("SWEEP[%s] spawned %d links" % [context, _captured_effects.size()])
	for effect: AnimatedSprite2D in _captured_effects:
		var pos: Vector2 = effect.global_position
		push_warning("SWEEP[%s] link at %s" % [context, pos])
		assert_ne(pos, Vector2.ZERO, "%s: link must NOT sit at world origin (top-left)" % context)
		assert_true(pos.length() >= 20.0, "%s: link too close to origin: %s" % [context, pos])


func test_chain_two_branches_positions_ok() -> void:
	var source := _enemy(1000, Vector2(100, 100))
	var t1 := _enemy(1000, Vector2(200, 100))
	var t2 := _enemy(1000, Vector2(100, 200))
	source.add_buff(ArcDebuff.new(), 1)
	_loadout.call("add", LightningStaffItem)

	var chain := _chain(LightningMarbleItem)
	source._on_body_entered(chain.head)

	_assert_all_links_not_at_origin("chain-2branch")


func test_chain_target_killed_by_chain_damage_positions_ok() -> void:
	var source := _enemy(1000, Vector2(100, 100))
	var weak_target := _enemy(1, Vector2(200, 100))
	source.add_buff(ArcDebuff.new(), 1)
	_loadout.call("add", LightningStaffItem)

	var chain := _chain(LightningMarbleItem)
	source._on_body_entered(chain.head)

	_assert_all_links_not_at_origin("chain-target-killed")


func test_relay_on_death_positions_ok() -> void:
	var source := _enemy(1, Vector2(100, 100))
	var target := _enemy(1000, Vector2(200, 100))
	source.add_buff(ArcDebuff.new(), 3)
	_loadout.call("add", ArcRelayItem)

	# Physical hit kills source → on_enemy_defeated → relay links.
	var chain := _chain(LightningMarbleItem)
	source._on_body_entered(chain.head)

	_assert_all_links_not_at_origin("relay-death")


func test_source_killed_by_discharge_positions_ok() -> void:
	var source := _enemy(3, Vector2(100, 100))
	var target := _enemy(1000, Vector2(200, 100))
	source.add_buff(ArcDebuff.new(), 2)
	_loadout.call("add", LightningStaffItem)

	var chain := _chain(LightningMarbleItem)
	source._on_body_entered(chain.head)

	assert_true(source.is_queued_for_deletion(), "discharge killed source")
	_assert_all_links_not_at_origin("chain-source-killed")
