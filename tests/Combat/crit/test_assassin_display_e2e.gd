extends GutTest

## End-to-end runtime wiring, mirroring how RunScope builds the game: a real
## ItemProgression(loadout, StatSystem) reacts to the loadout's marble_loadout_changed
## signal. Adding an assassin marble as a BODY segment (head stays dark) must make a
## freshly spawned enemy reveal a base weak point — no "head must be assassin" gate.

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

const STAT_COUNT: String = "assassin_weak_point_count"

var _stat_system: Node


func before_each() -> void:
	_stat_system = get_node_or_null("/root/StatSystem")
	assert_not_null(_stat_system)


func after_each() -> void:
	if _stat_system != null and is_instance_valid(_stat_system):
		_stat_system.remove_modifiers_by_source("marble_chain", "marble_upgrade")


func _marble(id: String, marble_type: Marble.MARBLE_TYPE) -> Item:
	var item := Item.new()
	item.id = id
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	item.marble_segment_damage = 1
	return item


func test_assassin_body_segment_sets_count_via_real_progression() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var _progression: RefCounted = ProgressionScript.new(loadout, _stat_system)
	assert_true(loadout.call("add", _marble("dark_marble", Marble.MARBLE_TYPE.DEFAULT)))
	assert_true(loadout.call("add", _marble("assassin_marble", Marble.MARBLE_TYPE.ASSASSIN)))
	# The progression listened to marble_loadout_changed and wrote the override count.
	assert_eq(_stat_system.call("get_stat", STAT_COUNT, "marble_chain"), 1)


func test_fresh_enemy_reveals_weak_point_when_assassin_is_a_body_segment() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var _progression: RefCounted = ProgressionScript.new(loadout, _stat_system)
	assert_true(loadout.call("add", _marble("dark_marble", Marble.MARBLE_TYPE.DEFAULT)))
	assert_true(loadout.call("add", _marble("assassin_marble", Marble.MARBLE_TYPE.ASSASSIN)))

	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	var host: WeakPointHost = enemy.get_node("WeakPointHost") as WeakPointHost
	assert_eq(host.weak_points.size(), 1, "assassin anywhere in chain -> weak point on fresh enemy")
	assert_eq((host.weak_points[0] as WeakPoint).kind, WeakPoint.Kind.BASE)


func test_no_assassin_means_no_weak_point() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var _progression: RefCounted = ProgressionScript.new(loadout, _stat_system)
	assert_true(loadout.call("add", _marble("dark_marble", Marble.MARBLE_TYPE.DEFAULT)))

	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	var host: WeakPointHost = enemy.get_node("WeakPointHost") as WeakPointHost
	assert_eq(host.weak_points.size(), 0)


func test_visual_tracks_enemy_global_position_not_world_origin() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	var _progression: RefCounted = ProgressionScript.new(loadout, _stat_system)
	assert_true(loadout.call("add", _marble("dark_marble", Marble.MARBLE_TYPE.DEFAULT)))
	assert_true(loadout.call("add", _marble("assassin_marble", Marble.MARBLE_TYPE.ASSASSIN)))

	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	enemy.position = Vector2(130.0, 70.0)
	add_child_autofree(enemy)
	var host: WeakPointHost = enemy.get_node("WeakPointHost") as WeakPointHost
	assert_true(host.weak_points.size() > 0)

	# Regression: the visual must be parented under the enemy (a Node2D) so its markers
	# follow the enemy. A plain-Node parent would strand them at the world origin.
	var visual: Node2D = host.get("_visual") as Node2D
	assert_not_null(visual, "visual instantiated when assassin is present")
	assert_eq(visual.get_parent(), enemy, "visual parented to the enemy, not the host")
	assert_true(
		visual.global_position.distance_to(enemy.global_position) < 0.01,
		"visual sits at the enemy, not stranded elsewhere"
	)
	assert_true(
		visual.global_position.distance_to(Vector2.ZERO) > 1.0,
		"visual must NOT be at the world origin (top-left bug)"
	)
