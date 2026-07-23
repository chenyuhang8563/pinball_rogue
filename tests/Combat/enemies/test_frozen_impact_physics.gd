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
const ItemScript: GDScript = preload("res://Content/domain/item.gd")
const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")
const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")


class ImpactRecorder:
	extends RefCounted
	var impacts: Array = []

	func on_frozen_body_impact(enemy: Node2D, hit_body: Node2D, velocity: Vector2, kind: StringName) -> void:
		impacts.append({
			&"enemy": enemy,
			&"hit_body": hit_body,
			&"velocity": velocity,
			&"kind": kind,
		})


class DamageAmplifier:
	extends RefCounted
	var calls: int = 0

	func modify_damage_packet(_enemy: Node2D, packet: DamagePacket) -> void:
		calls += 1
		packet.flat += 50.0


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
	assert_true(enemy.has_buff("frozen_debuff"), "impact event does not remove frozen state")
	# 问题来源：冰块发生碰撞时应固定损失 1 HP。修复走常规伤害结算而非直接改 health。
	# 边界：真实墙体碰撞只结算一次，冻结状态和碰撞事件仍保持有效。
	assert_eq(enemy.health, 99, "a frozen enemy loses exactly one HP on a wall collision")
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
	# 问题来源：冻结敌人互撞时，两边都是冰块，各自应结算一次 1 HP 碰撞伤害。
	# 边界：方向过滤只能抑制被撞方的事件上报，不能抑制其自身的碰撞扣血。
	assert_eq(striker.health, 99, "the moving frozen enemy loses one HP")
	assert_eq(target.health, 99, "the struck frozen enemy also loses one HP")
	assert_true(target.is_alive())


func test_cryoclasm_wall_impact_spawns_stable_shards_without_physics_flush_errors() -> void:
	# 问题来源：用户报告 cryoclasm.gd::_spawn_shards 在 body_entered 的物理查询刷新期触发
	# "Can't change this state while flushing queries"。修复应延后刚体注册，同时保持碎片从撞击点向前发射。
	# 边界：真实墙碰撞（而非直接调用 Effect）覆盖物理回调期；随后一帧验证延后生成的碎片仍有稳定前向运动。
	_configure_relics(["cryoclasm"])
	_wall(Vector2(140.0, 0.0))
	var source: Enemy = _enemy(Vector2(60.0, 0.0))
	_freeze(source)
	await wait_physics_frames(3)
	_launch_body(source, Vector2(60.0, 0.0), Vector2(200.0, 0.0))

	var shards_by_id: Dictionary[int, Node2D] = {}
	for _frame: int in range(90):
		await get_tree().physics_frame
		for node: Node in get_tree().get_nodes_in_group("relic_projectiles"):
			if node is Node2D:
				var shard: Node2D = node as Node2D
				shards_by_id[shard.get_instance_id()] = shard
		if shards_by_id.size() == 3:
			break
	var shards: Array[Node2D] = []
	for shard: Node2D in shards_by_id.values():
		shards.append(shard)

	assert_eq(shards.size(), 3, "a real frozen-wall impact creates the level-1 shard count")
	assert_engine_error_count(0, "shard registration must not mutate physics state while queries flush")
	if shards.size() != 3:
		return
	var launch_positions: Array[Vector2] = []
	for shard: Node2D in shards:
		assert_lt(
			shard.global_position.distance_to(source.global_position), 20.0,
			"shard spawns at the impact point instead of the scene origin"
		)
		launch_positions.append(shard.global_position)

	await get_tree().physics_frame
	for index: int in shards.size():
		var displacement: Vector2 = shards[index].global_position - launch_positions[index]
		assert_gt(displacement.length(), 0.1, "shard %d moves on its first active physics frame" % index)
		assert_gt(displacement.x, 0.0, "shard %d keeps the forward launch component" % index)


func test_marble_head_contact_shatters_frozen_enemy_without_a_dash() -> void:
	# 问题来源：冰爆要求冻结敌人高速移动，玩家未拿冲刺时难以触发。
	# 修复策略：真实 Head 接触在伤害链解除 Frozen 前分发冰爆；边界为固定弹珠无冲刺。
	_configure_relics(["cryoclasm"])
	var shard_count_before: int = _shards().size()
	_marble(Vector2(130.0, 0.0))
	var enemy: Enemy = _enemy(Vector2(60.0, 0.0))
	_freeze(enemy)
	await wait_physics_frames(3)
	_launch_body(enemy, Vector2(60.0, 0.0), Vector2(220.0, 0.0))

	await wait_physics_frames(90)

	assert_false(enemy.has_buff("frozen_debuff"), "Head contact shatters Frozen without a dash")
	assert_eq(_shards().size(), shard_count_before + 3, "Head-contact shatter creates three new shards")
	assert_lt(enemy.health, 100, "the marble-head damage chain still resolved")


func test_non_frozen_collision_does_not_take_ice_block_damage() -> void:
	# 边界：扣血是 Frozen 冰块规则，普通敌人的同一 body_entered 不能凭空失血。
	var enemy: Enemy = _enemy(Vector2.ZERO)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	enemy._on_body_entered(wall)
	assert_eq(enemy.health, 100, "non-frozen collision does not apply frozen_collision damage")


func test_frozen_collision_takes_one_damage_even_when_armor_is_higher() -> void:
	# 问题来源：需求是固定 -1 HP，不能被护甲减为零。
	# 边界：高于伤害值的护甲仍须让 Frozen 碰撞准确失去 1 HP。
	var enemy: Enemy = _enemy(Vector2.ZERO)
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	assert_not_null(stat_system)
	stat_system.add_modifier(
		enemy.get_stat_entity_id(),
		StatModifierScript.new("frozen_collision_armor", "armor", StatModifier.ModOp.OVERRIDE, 10.0, "test")
	)
	_freeze(enemy)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	enemy._on_body_entered(wall)
	assert_eq(enemy.health, 99, "frozen collision bypasses armor and removes exactly one HP")


func test_frozen_collision_ignores_effect_damage_modifiers_but_regular_damage_uses_them() -> void:
	# Problem source: the main-branch packet modifier hook could change frozen_collision before bypass logic ran.
	# Repair/boundary: a frozen collision remains exactly -1, while an ordinary packet still accepts effect modifiers.
	var amplifier := DamageAmplifier.new()
	_effect_manager._active_effects[&"damage_amplifier"] = amplifier
	var frozen_enemy: Enemy = _enemy(Vector2.ZERO)
	_freeze(frozen_enemy)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	frozen_enemy._on_body_entered(wall)
	assert_eq(frozen_enemy.health, 99, "frozen_collision ignores effect damage modifiers")
	assert_eq(amplifier.calls, 0, "frozen_collision never invokes packet modifiers")

	var ordinary_enemy: Enemy = _enemy(Vector2.ZERO)
	ordinary_enemy.apply_damage_packet(DamagePacketScript.new(&"untyped", 1.0))
	assert_eq(ordinary_enemy.health, 49, "ordinary damage still receives the effect modifier")
	assert_eq(amplifier.calls, 1, "ordinary packets still invoke packet modifiers")


func test_frozen_flipper_collision_damages_without_dispatching_frozen_impact() -> void:
	# 边界：挡板碰撞不触发冰爆事件，但仍属于冰块碰撞，必须扣 1 HP。
	var enemy: Enemy = _enemy(Vector2.ZERO)
	_freeze(enemy)
	var flipper := AnimatableBody2D.new()
	add_child_autofree(flipper)
	enemy._on_body_entered(flipper)
	assert_eq(enemy.health, 99, "flipper contact still damages the frozen ice block")
	assert_eq(_recorder.impacts.size(), 0, "flipper contact stays outside frozen-impact dispatch")


func test_one_hp_frozen_collision_uses_normal_death_flow() -> void:
	# 边界：碰撞伤害致死时必须走现有死亡管线，且不继续分发冻结碰撞 Effect。
	var enemy: Enemy = _enemy(Vector2.ZERO)
	enemy.take_damage(99)
	_freeze(enemy)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	enemy._on_body_entered(wall)
	assert_false(enemy.is_alive(), "one-HP frozen enemy dies from the one-point collision damage")
	assert_eq(_recorder.impacts.size(), 0, "death stops later frozen-impact dispatch")


func _configure_empty_loadout() -> void:
	var empty_loadout: RefCounted = LoadoutScript.new()
	var empty_progression: RefCounted = ProgressionScript.new(empty_loadout)
	_effect_manager.configure(empty_loadout, empty_progression)


func _configure_relics(relic_ids: Array[String]) -> void:
	var loadout: RefCounted = LoadoutScript.new()
	for relic_id: String in relic_ids:
		var relic: Item = ItemScript.new() as Item
		relic.id = relic_id
		relic.type = Item.ItemType.RELIC
		assert_true(loadout.call("add", relic), "loadout accepts relic %s" % relic_id)
	var progression: RefCounted = ProgressionScript.new(loadout)
	assert_true(_effect_manager.configure(loadout, progression))


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


func _shards() -> Array[Node2D]:
	var shards: Array[Node2D] = []
	for node: Node in get_tree().get_nodes_in_group("relic_projectiles"):
		if node is Node2D and is_instance_valid(node):
			shards.append(node as Node2D)
	return shards


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
