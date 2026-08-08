extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")

## Feedback loop for the "闪电弧出现在左上角" bug: reproduce the staff discharge
## → chain scenario with visuals ENABLED and capture every spawned LightningEffect
## so its global_position can be asserted against the expected midpoint.

var _captured_effects: Array[AnimatedSprite2D] = []
var _node_added_callback: Callable = Callable()
var _dummy_scene: Node2D = null


func before_each() -> void:
	_captured_effects = []
	# _spawn_link parents the effect to Engine.get_main_loop().current_scene,
	# which is null in headless GUT — install a stand-in scene so the effect
	# actually enters the tree and can be observed.
	_dummy_scene = Node2D.new()
	_dummy_scene.name = "LightningVisualTestScene"
	get_tree().root.add_child(_dummy_scene)
	get_tree().current_scene = _dummy_scene
	_node_added_callback = Callable(self, "_on_node_added")
	get_tree().node_added.connect(_node_added_callback)


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


func _runtime(effects: Dictionary) -> LightningArchetypeRuntime:
	var runtime := LightningArchetypeRuntime.new()
	runtime.configure(func(effect_id: StringName) -> Variant: return effects.get(effect_id, null))
	runtime.set_visuals_enabled(true)
	return runtime


func _enemy(hit_points: int, position: Vector2) -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	enemy.health = hit_points
	add_child_autofree(enemy)
	enemy.global_position = position
	return enemy


func _resolve_direct_hit(runtime: LightningArchetypeRuntime, enemy: Enemy) -> void:
	var packet := DamagePacket.new(&"marble_head", 1.0)
	packet.is_marble = true
	packet.target = enemy
	LightningMarble.prepare_direct_hit(enemy, packet)
	packet.metadata[LightningMarble.META_ORIGIN_POSITION] = enemy.global_position
	runtime.on_enemy_hit_resolved(enemy, packet)


func test_staff_chain_effect_spawns_at_enemy_midpoint_not_origin() -> void:
	var chain := LightningEffect.new()
	chain.set_level(2)
	var runtime := _runtime({&"lightning": chain})
	var source := _enemy(1000, Vector2(100.0, 100.0))
	var target := _enemy(1000, Vector2(140.0, 100.0))
	source.add_buff(ArcDebuff.new(), 1)

	_resolve_direct_hit(runtime, source)

	assert_eq(_captured_effects.size(), 1, "exactly one chain link effect spawned")
	if _captured_effects.is_empty():
		return
	var effect: AnimatedSprite2D = _captured_effects[0]
	var expected_midpoint: Vector2 = (Vector2(100.0, 100.0) + Vector2(140.0, 100.0)) * 0.5
	assert_eq(effect.global_position, expected_midpoint, "link effect must sit at the source→target midpoint")
	assert_ne(effect.global_position, Vector2.ZERO, "link effect must NOT be at world origin (top-left corner)")


func test_staff_chain_with_source_defeated_by_discharge_still_positions_correctly() -> void:
	var chain := LightningEffect.new()
	chain.set_level(2)
	var runtime := _runtime({&"lightning": chain})
	var source := _enemy(1, Vector2(100.0, 100.0))
	var target := _enemy(1000, Vector2(140.0, 100.0))
	source.add_buff(ArcDebuff.new(), 1)

	# The physical marble hit packet for a low-HP enemy is the killing blow.
	var packet := DamagePacket.new(&"marble_head", 2.0)
	packet.is_marble = true
	packet.target = source
	LightningMarble.prepare_direct_hit(source, packet)
	packet.metadata[LightningMarble.META_ORIGIN_POSITION] = source.global_position
	runtime.on_enemy_hit_resolved(source, packet)

	# Discharge (2 stacks worth of damage) is dealt after the physical hit; with
	# 1 HP the source may be defeated mid-transaction. The chain link must still
	# anchor to the recorded source position, not to (0, 0).
	assert_eq(_captured_effects.size(), 1, "chain link still spawned when source is defeated")
	if _captured_effects.is_empty():
		return
	var effect: AnimatedSprite2D = _captured_effects[0]
	var expected_midpoint: Vector2 = (Vector2(100.0, 100.0) + Vector2(140.0, 100.0)) * 0.5
	assert_eq(effect.global_position, expected_midpoint, "link effect anchored to source global position")
	assert_ne(effect.global_position, Vector2.ZERO, "link effect must NOT be at world origin")
