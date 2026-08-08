extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const LightningStaffItem: Item = preload("res://Content/data/lightning.tres")
const LightningMarbleItem: Item = preload("res://Content/data/lightning_marble.tres")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

## Live-flow reproduction: drives the REAL enemy.gd _on_body_entered → apply_damage_packet
## → on_enemy_hit_resolved path with the staff in the loadout, then inspects where the
## chain link effect is spawned.

var _captured_effects: Array[AnimatedSprite2D] = []
var _node_added_callback: Callable = Callable()
var _dummy_scene: Node2D = null
var _loadout: RefCounted = null
var _progression: RefCounted = null


func before_each() -> void:
	_captured_effects = []
	_dummy_scene = Node2D.new()
	_dummy_scene.name = "LiveFlowScene"
	get_tree().root.add_child(_dummy_scene)
	get_tree().current_scene = _dummy_scene
	_node_added_callback = Callable(self, "_on_node_added")
	get_tree().node_added.connect(_node_added_callback)

	_loadout = LoadoutScript.new()
	_progression = ProgressionScript.new(_loadout)
	assert_true(_loadout.call("add", LightningMarbleItem))
	assert_true(_loadout.call("add", LightningStaffItem))
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


func test_live_chain_spawns_at_midpoint_between_real_enemies() -> void:
	var source := _enemy(1000, Vector2(100.0, 100.0))
	var target := _enemy(1000, Vector2(140.0, 100.0))
	source.add_buff(ArcDebuff.new(), 1)

	var chain := MarbleChain.new()
	add_child_autofree(chain)
	var item := Item.new()
	item.id = "lightning_marble"
	item.type = Item.ItemType.MARBLE
	item.marble_type = Marble.MARBLE_TYPE.LIGHTNING
	item.marble_segment_damage = 1
	chain.build_chain([item], [Vector2.ZERO])

	source._on_body_entered(chain.head)

	assert_eq(_captured_effects.size(), 1, "staff chain link spawned")
	if _captured_effects.is_empty():
		return
	var effect: AnimatedSprite2D = _captured_effects[0]
	var expected: Vector2 = (Vector2(100.0, 100.0) + Vector2(140.0, 100.0)) * 0.5
	assert_eq(effect.global_position, expected, "link sits at source→target midpoint")
	assert_ne(effect.global_position, Vector2.ZERO, "link must NOT appear at world origin (top-left)")


func test_live_chain_when_discharge_kills_source_positions_correctly() -> void:
	# Source survives the physical marble hit but is killed BY the discharge.
	# Physical hit = 2 (marble_segment_damage), discharge = 2 stacks * 2 per stack = 4.
	# HP 3 → survives physical (1 HP left) → discharge kills → chain fires while
	# the source is queued for deletion.
	var source := _enemy(3, Vector2(100.0, 100.0))
	var target := _enemy(1000, Vector2(140.0, 100.0))
	source.add_buff(ArcDebuff.new(), 2)

	var chain := MarbleChain.new()
	add_child_autofree(chain)
	var item := Item.new()
	item.id = "lightning_marble"
	item.type = Item.ItemType.MARBLE
	item.marble_type = Marble.MARBLE_TYPE.LIGHTNING
	item.marble_segment_damage = 2
	chain.build_chain([item], [Vector2.ZERO])

	source._on_body_entered(chain.head)

	assert_true(source.is_queued_for_deletion(), "discharge killed the source")
	assert_eq(_captured_effects.size(), 1, "chain link spawned even when source dies mid-transaction")
	if _captured_effects.is_empty():
		return
	var effect: AnimatedSprite2D = _captured_effects[0]
	var expected: Vector2 = (Vector2(100.0, 100.0) + Vector2(140.0, 100.0)) * 0.5
	assert_eq(effect.global_position, expected, "link anchored to source position")
	assert_ne(effect.global_position, Vector2.ZERO, "link must NOT appear at world origin")
