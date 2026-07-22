extends GutTest

## 冻结体碰撞事件的分支逻辑（直接调用 Enemy._try_report_frozen_impact 缝隙）。
## 真实物理时序由 test_frozen_impact_physics.gd 覆盖。

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")


class ImpactRecorder:
	extends RefCounted
	var impacts: Array = []

	func on_frozen_body_impact(
		enemy: Node2D, hit_body: Node2D, velocity: Vector2, kind: StringName, was_ice_ball: bool
	) -> void:
		impacts.append({
			&"enemy": enemy,
			&"hit_body": hit_body,
			&"velocity": velocity,
			&"kind": kind,
			&"was_ice_ball": was_ice_ball,
		})


var _effect_manager: Node = null
var _recorder: ImpactRecorder = null


func before_each() -> void:
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	_configure_empty_loadout()
	_recorder = ImpactRecorder.new()
	_effect_manager._active_effects[&"impact_recorder"] = _recorder


func after_each() -> void:
	if _effect_manager != null and is_instance_valid(_effect_manager):
		_configure_empty_loadout()
	_effect_manager = null
	_recorder = null


func test_world_impact_dispatches_immutable_snapshot() -> void:
	var enemy: Enemy = _enemy()
	_freeze(enemy)
	enemy._pre_step_velocity = Vector2(120.0, -30.0)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)

	assert_true(enemy._try_report_frozen_impact(wall))
	assert_eq(_recorder.impacts.size(), 1)
	var snap: Dictionary = _recorder.impacts[0]
	assert_eq(snap[&"enemy"], enemy)
	assert_eq(snap[&"hit_body"], null, "world impacts carry no hit body")
	assert_eq(snap[&"kind"], &"world")
	assert_eq(snap[&"velocity"], Vector2(120.0, -30.0), "snapshot uses pre-step velocity")
	assert_eq(snap[&"was_ice_ball"], false)


func test_impact_at_threshold_dispatches() -> void:
	var enemy: Enemy = _enemy()
	_freeze(enemy)
	enemy._pre_step_velocity = Vector2(Enemy.FROZEN_IMPACT_SPEED_THRESHOLD, 0.0)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)

	assert_true(enemy._try_report_frozen_impact(wall))
	assert_eq(_recorder.impacts.size(), 1)


func test_below_threshold_does_not_dispatch() -> void:
	var enemy: Enemy = _enemy()
	_freeze(enemy)
	enemy._pre_step_velocity = Vector2(Enemy.FROZEN_IMPACT_SPEED_THRESHOLD - 1.0, 0.0)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)

	assert_false(enemy._try_report_frozen_impact(wall))
	assert_eq(_recorder.impacts.size(), 0)


func test_cooldown_suppresses_immediate_second_impact() -> void:
	var enemy: Enemy = _enemy()
	_freeze(enemy)
	enemy._pre_step_velocity = Vector2(120.0, 0.0)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)

	assert_true(enemy._try_report_frozen_impact(wall))
	assert_false(enemy._try_report_frozen_impact(wall), "second impact within cooldown is suppressed")
	assert_eq(_recorder.impacts.size(), 1)


func test_marble_contact_is_ignored() -> void:
	var enemy: Enemy = _enemy()
	_freeze(enemy)
	enemy._pre_step_velocity = Vector2(200.0, 0.0)
	var marble_body: Node2D = _grouped_body("marbles")

	assert_false(enemy._try_report_frozen_impact(marble_body))
	assert_eq(_recorder.impacts.size(), 0, "Head contact never dispatches frozen impact")


func test_flipper_and_projectile_contacts_are_ignored() -> void:
	var enemy: Enemy = _enemy()
	_freeze(enemy)
	enemy._pre_step_velocity = Vector2(200.0, 0.0)

	# 生产中的挡板是 AnimatableBody2D（flipper.tscn 的 FlipperBody，无组），按类型识别。
	var flipper_body := AnimatableBody2D.new()
	add_child_autofree(flipper_body)
	assert_false(enemy._try_report_frozen_impact(flipper_body), "animatable flipper body")
	for group_name: String in ["projectiles", "skill_projectiles"]:
		var body: Node2D = _grouped_body(group_name)
		assert_false(enemy._try_report_frozen_impact(body), group_name)
	assert_eq(_recorder.impacts.size(), 0)


func test_unknown_bodies_are_ignored_not_world() -> void:
	var enemy: Enemy = _enemy()
	_freeze(enemy)
	enemy._pre_step_velocity = Vector2(200.0, 0.0)

	var bare_rigid := RigidBody2D.new()
	add_child_autofree(bare_rigid)
	assert_false(enemy._try_report_frozen_impact(bare_rigid), "ungrouped RigidBody2D must not count as world")
	var character := CharacterBody2D.new()
	add_child_autofree(character)
	assert_false(enemy._try_report_frozen_impact(character), "CharacterBody2D must not count as world")
	var bare_node := Node2D.new()
	add_child_autofree(bare_node)
	assert_false(enemy._try_report_frozen_impact(bare_node), "plain Node2D must not count as world")
	assert_eq(_recorder.impacts.size(), 0)


func test_enemy_impact_dispatches_with_hit_body() -> void:
	var enemy: Enemy = _enemy()
	var other: Enemy = _enemy()
	_freeze(enemy)
	enemy._pre_step_velocity = Vector2(80.0, 0.0)

	assert_true(enemy._try_report_frozen_impact(other))
	assert_eq(_recorder.impacts.size(), 1)
	var snap: Dictionary = _recorder.impacts[0]
	assert_eq(snap[&"kind"], &"enemy")
	assert_eq(snap[&"hit_body"], other)
	assert_eq(snap[&"was_ice_ball"], false)


func test_not_frozen_does_not_dispatch() -> void:
	var enemy: Enemy = _enemy()
	enemy._pre_step_velocity = Vector2(200.0, 0.0)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)

	assert_false(enemy._try_report_frozen_impact(wall))
	assert_eq(_recorder.impacts.size(), 0)


func test_was_ice_ball_flag_is_captured_in_snapshot() -> void:
	var enemy: Enemy = _enemy()
	_freeze(enemy)
	enemy.set_meta(&"ice_ball", true)
	enemy._pre_step_velocity = Vector2(120.0, 0.0)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)

	assert_true(enemy._try_report_frozen_impact(wall))
	assert_eq(_recorder.impacts.size(), 1)
	assert_eq(_recorder.impacts[0][&"was_ice_ball"], true)


func _configure_empty_loadout() -> void:
	var empty_loadout: RefCounted = LoadoutScript.new()
	var empty_progression: RefCounted = ProgressionScript.new(empty_loadout)
	_effect_manager.configure(empty_loadout, empty_progression)


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy


func _freeze(enemy: Enemy) -> void:
	var registry: Node = get_node_or_null("/root/BuffRegistry")
	assert_not_null(registry)
	var frozen_def: BuffDef = registry.call("get_buff_def", "frozen_debuff") as BuffDef
	assert_not_null(frozen_def)
	enemy.add_buff(frozen_def)
	assert_true(enemy.has_buff("frozen_debuff"))


func _grouped_body(group_name: String) -> Node2D:
	var body := Node2D.new()
	add_child_autofree(body)
	body.add_to_group(group_name)
	return body
