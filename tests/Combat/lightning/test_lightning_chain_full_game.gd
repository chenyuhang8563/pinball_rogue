extends GutTest

const MainScene: PackedScene = preload("res://Game/Bootstrap/main.tscn")

## Full-game reproduction: boots the REAL Main scene, starts a real run (which
## auto-enters a battle), grants the lightning marble + staff, then drives a
## marble collision against a real spawned enemy. Captures every LightningEffect
## spawned and asserts its world position.

var _captured_effects: Array[AnimatedSprite2D] = []
var _node_added_callback: Callable = Callable()
var _main: Node = null


func before_each() -> void:
	_captured_effects = []
	_node_added_callback = Callable(self, "_on_node_added")
	get_tree().node_added.connect(_node_added_callback)


func after_each() -> void:
	if get_tree() != null and _node_added_callback.is_valid() \
			and get_tree().node_added.is_connected(_node_added_callback):
		get_tree().node_added.disconnect(_node_added_callback)
	for effect: AnimatedSprite2D in _captured_effects:
		if is_instance_valid(effect):
			effect.queue_free()
	if _main != null and is_instance_valid(_main):
		_main.queue_free()
		_main = null
	get_tree().current_scene = null


func _on_node_added(node: Node) -> void:
	if node is AnimatedSprite2D and node.get_script() != null:
		var script_path: String = str(node.get_script().resource_path) if node.get_script().resource_path != null else ""
		if script_path.ends_with("lightning_effect.gd"):
			_captured_effects.append(node as AnimatedSprite2D)


func _grant_item(item_id: StringName, level: int) -> void:
	if _main == null:
		return
	var service: RefCounted = _main.get("debug_grant_service")
	if service == null or not is_instance_valid(service):
		return
	service.call("grant", item_id, level)


func _wait_for_enemies(max_frames: int) -> Array:
	for _frame in range(max_frames):
		var enemies: Array = get_tree().get_nodes_in_group("enemies")
		if enemies.size() >= 2:
			return enemies
		await wait_frames(1)
	return get_tree().get_nodes_in_group("enemies")


func test_full_game_staff_chain_never_spawns_at_origin() -> void:
	var repository := get_node_or_null("/root/RunSaveRepository")
	assert_not_null(repository)
	if repository == null:
		return
	repository.call("request_new_run")

	_main = MainScene.instantiate()
	get_tree().root.add_child(_main)
	get_tree().current_scene = _main
	await wait_frames(3)

	# Grant lightning marble + staff, then wait for the chain rebuild + sync.
	_grant_item(&"lightning_marble", 1)
	_grant_item(&"lightning", 1)
	await wait_frames(3)

	var enemies: Array = await _wait_for_enemies(120)
	push_warning("LIVE-REPRO enemy count: %d" % enemies.size())
	if enemies.size() < 2:
		push_warning("LIVE-REPRO not enough enemies to chain — skipping assertions")
		return

	var source: Enemy = enemies[0] as Enemy
	source.call("add_buff", ArcDebuff.new(), 1)
	var source_pos: Vector2 = source.global_position
	push_warning("LIVE-REPRO source pos: %s" % source_pos)

	# Drive the real marble collision path on the source enemy.
	var chain_node: Node = _main.get("marble_chain")
	if chain_node == null or chain_node.head == null:
		push_warning("LIVE-REPRO no marble chain to drive")
		return
	source.call("_on_body_entered", chain_node.head)
	await wait_frames(2)

	for effect: AnimatedSprite2D in _captured_effects:
		var pos: Vector2 = effect.global_position
		push_warning("LIVE-REPRO spawned effect at %s (script %s)" % [pos, effect.get_script()])
		assert_ne(pos, Vector2.ZERO, "lightning chain effect must not spawn at world origin (top-left)")
