extends GutTest

## 冻结体碰撞事件的真实物理验证：在含墙/敌人的场景里给冻结敌人真实初速度，
## 证明 Godot 真实碰撞时序下碰撞前速度采样正确（body_entered 比碰撞步晚一个
## 物理步触发，回调时 linear_velocity 已是反弹值；Enemy 用最近采样环还原碰撞前速度）、
## 事件只发一次、分类正确，且 Head 接触绝不误报。
## 分支逻辑由 test_frozen_impact_event.gd 覆盖。
##
## 物理测试要点（探针验证）：
## 1. RigidBody2D 的 transform 每物理步由物理服务器回写：位置在进入场景树之前设置，
##    中途重置需额外 PhysicsServer2D.body_set_state 写入。
## 2. 两个 freeze=true 的静态刚体互相重叠不会产生碰撞回调。
## 3. GUT 的 wait_physics_frames 必须直接在测试函数体内 await；包进异步 helper
##    再无 await 调用会导致等待不恢复（实测初速度从未生效）。

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


func test_frozen_enemy_sliding_into_wall_dispatches_one_world_impact() -> void:
	_wall(Vector2(140.0, 0.0))
	var enemy: Enemy = _enemy(Vector2(60.0, 0.0))
	_freeze(enemy)
	await wait_physics_frames(3)
	_launch_body(enemy, Vector2(60.0, 0.0), Vector2(200.0, 0.0))

	await wait_physics_frames(90)

	assert_eq(_recorder.impacts.size(), 1, "exactly one impact for a single wall hit")
	if _recorder.impacts.is_empty():
		return
	var snap: Dictionary = _recorder.impacts[0]
	assert_eq(snap[&"enemy"], enemy)
	assert_eq(snap[&"kind"], &"world")
	assert_eq(snap[&"hit_body"], null)
	var velocity: Vector2 = snap[&"velocity"]
	assert_gt(velocity.x, 100.0, "snapshot is the pre-collision velocity, not the rebound")
	assert_lt(absf(velocity.y), 10.0, "snapshot preserves the near-zero lateral component")
	assert_eq(snap[&"was_ice_ball"], false)
	assert_true(enemy.has_buff("frozen_debuff"), "impact event does not remove frozen state")
	assert_true(enemy.is_alive())


func test_frozen_enemy_sliding_into_another_enemy_dispatches_enemy_impact() -> void:
	var striker: Enemy = _enemy(Vector2(60.0, 0.0))
	var target: Enemy = _enemy(Vector2(120.0, 0.0))
	_freeze(striker)
	_freeze(target)
	await wait_physics_frames(3)
	_launch_body(striker, Vector2(60.0, 0.0), Vector2(200.0, 0.0))

	await wait_physics_frames(90)

	assert_eq(_recorder.impacts.size(), 1, "only the fast striker reports; the idle target stays silent")
	if _recorder.impacts.is_empty():
		return
	var snap: Dictionary = _recorder.impacts[0]
	assert_eq(snap[&"enemy"], striker)
	assert_eq(snap[&"kind"], &"enemy")
	assert_eq(snap[&"hit_body"], target)
	assert_gt(snap[&"velocity"].x, 100.0)
	assert_true(target.is_alive(), "the collision event itself deals no damage")


func test_marble_head_contact_never_dispatches_frozen_impact() -> void:
	_marble(Vector2(130.0, 0.0))
	var enemy: Enemy = _enemy(Vector2(60.0, 0.0))
	_freeze(enemy)
	await wait_physics_frames(3)
	_launch_body(enemy, Vector2(60.0, 0.0), Vector2(220.0, 0.0))

	await wait_physics_frames(90)

	assert_eq(
		_recorder.impacts.size(), 0,
		"Head contact goes through the ice-hammer chain, never the frozen-impact event"
	)
	assert_lt(enemy.health, 100, "the marble-head damage chain still resolved")


func _configure_empty_loadout() -> void:
	var empty_loadout: RefCounted = LoadoutScript.new()
	var empty_progression: RefCounted = ProgressionScript.new(empty_loadout)
	_effect_manager.configure(empty_loadout, empty_progression)


## 位置在进入场景树之前设置：RigidBody2D 入树后其 transform 由物理服务器同步，
## add_child 之后再赋值可能被服务器旧 transform 覆盖（探针实测）。
func _enemy(pos: Vector2) -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	enemy.position = pos
	add_child_autofree(enemy)
	return enemy


func _freeze(enemy: Enemy) -> void:
	var registry: Node = get_node_or_null("/root/BuffRegistry")
	assert_not_null(registry)
	var frozen_def: BuffDef = registry.call("get_buff_def", "frozen_debuff") as BuffDef
	assert_not_null(frozen_def)
	enemy.add_buff(frozen_def)
	assert_true(enemy.has_buff("frozen_debuff"))


## 同步 helper（绝不含 await）：等调用方先 await 冻结物理态生效后，再用
## body_set_state 重设位置（节点级赋值会被物理服务器回写覆盖）并给初速度。
func _launch_body(enemy: Enemy, launch_pos: Vector2, velocity: Vector2) -> void:
	enemy.global_position = launch_pos
	PhysicsServer2D.body_set_state(
		enemy.get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, launch_pos)
	)
	enemy.linear_velocity = velocity
	enemy.set_sleeping(false)
	assert_almost_eq(enemy.global_position.x, launch_pos.x, 1.0, "launch position must hold")


func _wall(pos: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20.0, 400.0)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = pos
	add_child_autofree(wall)
	return wall


func _marble(pos: Vector2) -> RigidBody2D:
	var marble := RigidBody2D.new()
	marble.collision_layer = 2
	marble.collision_mask = 8
	marble.gravity_scale = 0.0
	marble.freeze = true
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	marble.add_child(shape)
	marble.position = pos
	marble.add_to_group("marbles")
	add_child_autofree(marble)
	return marble
