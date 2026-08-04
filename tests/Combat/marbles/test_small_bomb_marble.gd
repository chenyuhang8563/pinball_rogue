extends GutTest

## 小炸弹弹珠 —— 高爆弹头产出的独立投射物。
##
## 覆盖：物理契约（layer=2/mask=15/反弹）、碰撞行为（敌人爆炸 / 友军与环境的
## 纯物理反弹）、生命周期（超时 / 掉台）、group 归属（produced_marbles，不入
## marbles）、AOE 事件语义（共享 event_id、唯一 main、排除待删除）、独立结算
## 边界（不触发 on_explosion_resolved 连锁产出）、真实物理接触边界。

const SmallBombScene: PackedScene = preload("res://Combat/marbles/small_bomb_marble.tscn")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")


class SpySpawner extends Node:
	var spawn_calls: int = 0

	func spawn(_scene: PackedScene, _position: Vector2, _max_active: int) -> Node:
		spawn_calls += 1
		return null


## 记录 apply_damage_packet 的非物理测试替身（进 enemies group，无需碰撞体）。
class DamageableEnemy extends Node2D:
	var packets: Array = []

	func _ready() -> void:
		add_to_group("enemies")

	func apply_damage_packet(packet: DamagePacket) -> void:
		packets.append(packet)


## 真实物理敌人：layer=8、带碰撞体，验证 body_entered 真实接触边界。
class PhysicsEnemy extends RigidBody2D:
	var took_damage: bool = false

	func _ready() -> void:
		add_to_group("enemies")
		collision_layer = 8
		collision_mask = 0
		gravity_scale = 0.0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		add_child(shape)

	func take_damage(_amount: int) -> void:
		took_damage = true


## 真实物理链 head 替身：layer=2 / mask=13，与 marble.tscn 的碰撞属性一致，
## 验证小炸弹（mask=15）能与 head 碰撞但只反弹不引爆。
class FakeHead extends RigidBody2D:
	func _ready() -> void:
		add_to_group("marbles")
		collision_layer = 2
		collision_mask = 13
		gravity_scale = 0.0
		var shape := CollisionShape2D.new()
		var circle := CircleShape2D.new()
		circle.radius = 8.0
		shape.shape = circle
		add_child(shape)


class FakeKillZone extends Node:
	var point_inside: bool = false

	func contains_global_point(_point: Vector2) -> bool:
		return point_inside


func after_each() -> void:
	# 独立结算测试配置了 EffectManager autoload，统一复位避免泄漏。
	var effect_manager: Node = get_node_or_null("/root/EffectManager")
	if effect_manager != null:
		var empty: RefCounted = LoadoutScript.new()
		effect_manager.call("configure", empty, ProgressionScript.new(empty))


func _new_marble() -> SmallBombMarble:
	var marble: SmallBombMarble = SmallBombScene.instantiate() as SmallBombMarble
	marble.initial_impulse = 0.0
	add_child_autofree(marble)
	return marble


func _gone(marble) -> bool:
	return not is_instance_valid(marble) or marble.is_queued_for_deletion()


# ---- 物理契约 ----

func test_scene_contract_physics_properties() -> void:
	var marble: Node = SmallBombScene.instantiate()
	add_child_autofree(marble)
	assert_true(marble is SmallBombMarble, "根为 SmallBombMarble")
	assert_eq(marble.collision_layer, 2, "layer=2")
	assert_eq(marble.collision_mask, 15, "mask=15（环境1+弹珠2+挡板4+敌人8）")
	assert_almost_eq(marble.mass, 0.2, 0.0001, "mass=0.2")
	assert_almost_eq(marble.gravity_scale, 0.3, 0.0001, "gravity_scale=0.3")
	assert_almost_eq(marble.lifetime, 3.0, 0.0001, "lifetime=3.0（3s 后自动消失）")
	assert_almost_eq(marble.max_speed, 450.0, 0.0001, "max_speed=450（速度上限规范）")
	assert_eq(marble.continuous_cd, 2, "continuous_cd=2")
	assert_true(marble.contact_monitor, "contact_monitor 开启")
	assert_eq(marble.max_contacts_reported, 8, "max_contacts_reported=8")
	var shape: CollisionShape2D = marble.get_node_or_null(NodePath("CollisionShape2D")) as CollisionShape2D
	assert_not_null(shape, "含 CollisionShape2D")
	assert_not_null(shape.shape, "含碰撞形状")
	var material: PhysicsMaterial = marble.physics_material_override
	assert_not_null(material, "含 PhysicsMaterial")
	assert_almost_eq(material.bounce, 1.0, 0.0001, "bounce=1.0")
	assert_almost_eq(material.friction, 0.0, 0.0001, "friction=0.0")
	assert_true(marble.is_in_group(&"produced_marbles"), "入 produced_marbles group")
	assert_false(marble.is_in_group(&"marbles"), "不入 marbles group（避免 RunFlow 误扣生命）")


# ---- 碰撞行为 ----

func test_hits_enemy_deals_damage_but_keeps_bouncing() -> void:
	var marble := _new_marble()
	marble.global_position = Vector2(100, 100)
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(100, 100)
	marble.call("_on_body_entered", enemy)
	assert_false(marble.is_queued_for_deletion(), "碰敌造成伤害但不消失（3s 超时/掉台才消失）")
	assert_eq(enemy.packets.size(), 1, "敌人收到一次伤害包")
	if enemy.packets.size() > 0:
		assert_eq(enemy.packets[0].base, 2.0, "50% 伤害：roundi(4 × 0.5) = 2")


func test_hits_non_enemy_does_not_explode() -> void:
	var marble := _new_marble()
	marble.global_position = Vector2(100, 100)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	wall.global_position = Vector2(110, 100)
	marble.call("_on_body_entered", wall)
	assert_false(marble.is_queued_for_deletion(), "撞环境不引爆")


func test_hits_marble_head_is_friendly() -> void:
	var marble := _new_marble()
	marble.global_position = Vector2(100, 100)
	var head := Node2D.new()
	add_child_autofree(head)
	head.add_to_group("marbles")
	head.global_position = Vector2(110, 100)
	marble.call("_on_body_entered", head)
	assert_false(marble.is_queued_for_deletion(), "链 head 是友军不引爆")


# ---- 生命周期 ----

func test_expires_after_lifetime() -> void:
	var marble := _new_marble()
	marble.lifetime = 0.05
	assert_false(marble.is_queued_for_deletion())
	await wait_seconds(0.2)
	assert_true(_gone(marble), "超时后消失")


func test_speed_is_capped_at_max_speed() -> void:
	var marble := _new_marble()
	marble.max_speed = 100.0
	marble.linear_velocity = Vector2(500, 0)
	await wait_physics_frames(3)
	assert_almost_eq(marble.linear_velocity.length(), 100.0, 0.5, "超速每帧被 clamp 到 max_speed")


func test_falls_into_kill_zone_and_disappears() -> void:
	var marble := _new_marble()
	marble.global_position = Vector2(100, 100)
	var zone := FakeKillZone.new()
	add_child_autofree(zone)
	zone.point_inside = true
	marble.set("_kill_zone", zone)
	marble.call("_check_kill_zone")
	assert_true(marble.is_queued_for_deletion(), "掉出台消失")


# ---- AOE 事件语义 ----

func test_aoe_shares_event_id_and_marks_nearest_main() -> void:
	var marble := _new_marble()
	marble.global_position = Vector2(100, 100)
	var near := DamageableEnemy.new()
	add_child_autofree(near)
	near.global_position = Vector2(100, 100)
	var far := DamageableEnemy.new()
	add_child_autofree(far)
	far.global_position = Vector2(150, 100)
	var outside := DamageableEnemy.new()
	add_child_autofree(outside)
	outside.global_position = Vector2(100, 200)
	marble.call("_on_body_entered", near)
	assert_eq(near.packets.size(), 1, "近目标受伤")
	assert_eq(far.packets.size(), 1, "半径 75 内远目标受伤")
	assert_eq(outside.packets.size(), 0, "半径外敌人不受伤")
	if near.packets.size() > 0 and far.packets.size() > 0:
		var shared_id: int = near.packets[0].event_id
		assert_ne(shared_id, 0, "event_id 非零（一次逻辑 AOE）")
		assert_eq(far.packets[0].event_id, shared_id, "同一次 AOE 共享 event_id")
		assert_true(near.packets[0].is_event_main, "最近目标为 main")
		assert_false(far.packets[0].is_event_main, "远目标非 main")


func test_aoe_excludes_queued_for_deletion_enemies() -> void:
	var marble := _new_marble()
	marble.global_position = Vector2(100, 100)
	var doomed := DamageableEnemy.new()
	add_child_autofree(doomed)
	doomed.global_position = Vector2(100, 100)
	doomed.queue_free()
	var alive := DamageableEnemy.new()
	add_child_autofree(alive)
	alive.global_position = Vector2(110, 100)
	marble.call("_on_body_entered", alive)
	assert_eq(doomed.packets.size(), 0, "已排队删除的敌人排除")
	assert_eq(alive.packets.size(), 1, "存活敌人正常受伤")


# ---- 独立结算 ----

func test_independent_settlement_does_not_dispatch_explosion_hooks() -> void:
	var effect_manager: Node = get_node_or_null("/root/EffectManager")
	if effect_manager == null:
		return
	var spy := SpySpawner.new()
	add_child_autofree(spy)
	var loadout: RefCounted = LoadoutScript.new(func(_t: int, _f: int) -> int: return 4)
	var relic := Item.new()
	relic.id = "high_explosive"
	relic.type = Item.ItemType.RELIC
	loadout.call("add", relic)
	var progression: RefCounted = ProgressionScript.new(loadout)
	assert_true(effect_manager.configure(loadout, progression, null, spy))
	var he: Variant = effect_manager.get("_active_effects").get("high_explosive")
	assert_not_null(he)
	he.set_config(_certain_config())
	he.set_level(3)
	he.seed_rng(1)

	var marble := _new_marble()
	marble.global_position = Vector2(100, 100)
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(100, 100)
	marble.call("_on_body_entered", enemy)
	assert_false(marble.is_queued_for_deletion(), "小炸弹碰敌造伤但不消失")
	assert_eq(spy.spawn_calls, 0, "独立结算：小炸弹造伤不触发 on_explosion_resolved 连锁产出")


func _certain_config() -> RelicLevelConfig:
	var config := RelicLevelConfig.new()
	config.max_level = 3
	config.level_values = [100, 100, 100]
	config.extra = {"max_spawned": 3, "lifetime": 5.0}
	return config


# ---- 真实物理接触边界 ----

func test_physics_contact_with_enemy_deals_damage_but_keeps_bouncing() -> void:
	var marble := _new_marble()
	marble.global_position = Vector2(100, 100)
	var enemy := PhysicsEnemy.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(100, 116)
	marble.linear_velocity = Vector2(0, 120)
	await wait_physics_frames(30)
	assert_true(enemy.took_damage, "物理接触敌人后造成伤害")
	assert_true(is_instance_valid(marble), "碰敌后小炸弹仍存活（不消失）")
	assert_false(marble.is_queued_for_deletion(), "碰敌后不排队删除")


func test_physics_contact_with_marble_head_bounces() -> void:
	var marble := _new_marble()
	marble.global_position = Vector2(100, 100)
	var head := FakeHead.new()
	add_child_autofree(head)
	head.global_position = Vector2(100, 116)
	marble.linear_velocity = Vector2(0, 120)
	await wait_physics_frames(30)
	assert_false(marble.is_queued_for_deletion(), "与链 head 碰撞不引爆")
	assert_true(is_instance_valid(marble), "小炸弹反弹后仍存活")


func test_physics_contact_with_wall_bounces() -> void:
	var marble := _new_marble()
	marble.global_position = Vector2(100, 100)
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	wall.collision_layer = 1
	wall.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(400, 10)
	shape.shape = rect
	wall.add_child(shape)
	wall.global_position = Vector2(100, 116)
	marble.linear_velocity = Vector2(0, 120)
	await wait_physics_frames(30)
	assert_false(marble.is_queued_for_deletion(), "撞环境纯物理反弹不爆炸")
	assert_true(is_instance_valid(marble), "小炸弹仍存活")
