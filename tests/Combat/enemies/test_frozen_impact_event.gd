extends GutTest

## 冻结碰撞事件的分支逻辑。问题来源：冰爆曾要求高速，并忽略弹珠接触。
## 修复策略：世界/弹珠的零速度接触也分发；敌人互撞仍仅由朝向对方的主动者分发。

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")


class ImpactRecorder:
	extends RefCounted
	var impacts: Array = []

	func on_frozen_body_impact(enemy: Node2D, hit_body: Node2D, velocity: Vector2, kind: StringName) -> void:
		impacts.append({&"enemy": enemy, &"hit_body": hit_body, &"velocity": velocity, &"kind": kind})


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


func test_zero_speed_world_impact_dispatches_snapshot() -> void:
	# 边界：零速度接触不能再被旧的 40px/s 速度阈值过滤。
	var enemy: Enemy = _frozen_enemy()
	enemy._pre_step_velocity = Vector2.ZERO
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	assert_true(enemy._try_report_frozen_impact(wall))
	assert_eq(_recorder.impacts.size(), 1)
	assert_eq(_recorder.impacts[0][&"kind"], &"world")
	assert_eq(_recorder.impacts[0][&"velocity"], Vector2.ZERO)


func test_zero_speed_marble_contact_dispatches() -> void:
	# 边界：未拿冲刺时的 Head 接触同样是一次冰爆触发机会。
	var enemy: Enemy = _frozen_enemy()
	enemy._pre_step_velocity = Vector2.ZERO
	var marble: Node2D = _grouped_body("marbles")
	assert_true(enemy._try_report_frozen_impact(marble))
	assert_eq(_recorder.impacts.size(), 1)
	assert_eq(_recorder.impacts[0][&"kind"], &"marble")


func test_separate_contacts_are_not_suppressed_by_time_cooldown() -> void:
	# 边界：觉醒永冻写的是“每碰撞一次”，不能吞掉相邻的独立接触。
	var enemy: Enemy = _frozen_enemy()
	var left_wall := StaticBody2D.new()
	var right_wall := StaticBody2D.new()
	add_child_autofree(left_wall)
	add_child_autofree(right_wall)
	assert_true(enemy._try_report_frozen_impact(left_wall))
	assert_true(enemy._try_report_frozen_impact(right_wall))
	assert_eq(_recorder.impacts.size(), 2)


func test_enemy_impact_requires_the_frozen_enemy_to_move_toward_target() -> void:
	var striker: Enemy = _frozen_enemy()
	var target: Enemy = _enemy()
	target.global_position = striker.global_position + Vector2(20.0, 0.0)
	striker._pre_step_velocity = Vector2.RIGHT
	assert_true(striker._try_report_frozen_impact(target))
	assert_eq(_recorder.impacts[0][&"kind"], &"enemy")
	var passive: Enemy = _frozen_enemy()
	passive.global_position = target.global_position + Vector2(20.0, 0.0)
	passive._pre_step_velocity = Vector2.RIGHT
	assert_false(passive._try_report_frozen_impact(target), "moving away is the passive collision side")


func test_flipper_projectile_and_unknown_bodies_remain_ignored() -> void:
	var enemy: Enemy = _frozen_enemy()
	var flipper := AnimatableBody2D.new()
	add_child_autofree(flipper)
	assert_false(enemy._try_report_frozen_impact(flipper))
	for group_name: String in ["projectiles", "skill_projectiles"]:
		assert_false(enemy._try_report_frozen_impact(_grouped_body(group_name)))
	var bare_rigid := RigidBody2D.new()
	add_child_autofree(bare_rigid)
	assert_false(enemy._try_report_frozen_impact(bare_rigid))
	assert_eq(_recorder.impacts.size(), 0)


func test_not_frozen_does_not_dispatch() -> void:
	var enemy: Enemy = _enemy()
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	assert_false(enemy._try_report_frozen_impact(wall))


func _configure_empty_loadout() -> void:
	var loadout: RefCounted = LoadoutScript.new()
	_effect_manager.configure(loadout, ProgressionScript.new(loadout))


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy


func _frozen_enemy() -> Enemy:
	var enemy: Enemy = _enemy()
	var registry: Node = get_node_or_null("/root/BuffRegistry")
	assert_not_null(registry)
	enemy.add_buff(registry.call("get_buff_def", "frozen_debuff") as BuffDef)
	assert_true(enemy.has_buff("frozen_debuff"))
	return enemy


func _grouped_body(group_name: String) -> Node2D:
	var body := Node2D.new()
	add_child_autofree(body)
	body.add_to_group(group_name)
	return body
