extends GutTest

## 抛射炸弹飞行与落地：launch 后 freeze=true、入 skill_projectiles 组、
## Tween 驱动弧线插值（手动推进 _flight_progress 验证 lerp+sin）、
## 动画结束落地 → freeze=false、清空速度（落地无速度，后续被推动才有）。

const BombScene: PackedScene = preload("res://Combat/skills/DemolitionCharge/demolition_charge_bomb.tscn")
const Definition: Resource = preload("res://Combat/skills/DemolitionCharge/demolition_charge_skill_definition.tres")


func after_each() -> void:
	Engine.time_scale = 1.0


## 默认 fuse 拉长到 5s，避免测试期间触发爆炸。
func _definition_with(overrides: Dictionary = {}) -> SkillDefinition:
	var def: SkillDefinition = (Definition as SkillDefinition).duplicate()
	def.base_damage = 12
	def.blast_radius = 70.0
	def.fuse_time = 5.0
	def.flight_duration = 0.15
	def.aim_arc_height = 60.0
	for key: String in overrides:
		def.set(key, overrides[key])
	return def


func _bomb_in_tree(def: SkillDefinition) -> DemolitionChargeBomb:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var bomb: DemolitionChargeBomb = BombScene.instantiate() as DemolitionChargeBomb
	parent.add_child(bomb)
	bomb.global_position = Vector2(50, 100)
	bomb.launch(Vector2(150, 100), def)
	return bomb


func test_launch_freezes_physics_and_enters_skill_projectiles() -> void:
	var bomb: DemolitionChargeBomb = _bomb_in_tree(_definition_with())
	assert_true(bomb.freeze, "抛射期冻结物理（无速度无碰撞反应）")
	assert_true(bomb.is_in_group(&"skill_projectiles"), "加入 skill_projectiles 组（战斗边界清理）")
	assert_eq(bomb.linear_velocity, Vector2.ZERO, "抛射期无速度")


func test_flight_follows_parabolic_arc() -> void:
	var bomb: DemolitionChargeBomb = _bomb_in_tree(_definition_with())
	bomb._flight_progress = 0.5
	bomb._update_arc_position()
	var expected: Vector2 = Vector2(50, 100).lerp(Vector2(150, 100), 0.5) + Vector2(0.0, -60.0 * sin(PI * 0.5))
	assert_almost_eq(bomb.global_position.x, expected.x, 0.0001, "水平方向线性插值")
	assert_almost_eq(bomb.global_position.y, expected.y, 0.0001, "竖直方向 sin 弧线")


func test_landing_enters_physics_with_zero_velocity() -> void:
	var bomb: DemolitionChargeBomb = _bomb_in_tree(_definition_with())
	bomb._flight_progress = 1.0
	bomb._on_landed()
	assert_false(bool(bomb.get("_flying")), "飞行结束")
	assert_true(bool(bomb.get("_landed")), "落地")
	assert_false(bomb.freeze, "落地转物理（可被弹珠推动）")
	assert_eq(bomb.linear_velocity, Vector2.ZERO, "落地无速度")
	assert_eq(bomb.angular_velocity, 0.0, "落地无角速度")


func test_full_flight_then_landed_after_flight_duration() -> void:
	var bomb: DemolitionChargeBomb = _bomb_in_tree(_definition_with())
	assert_true(bool(bomb.get("_flying")), "launch 后处于飞行态")
	await wait_seconds(0.2)
	assert_true(bool(bomb.get("_landed")), "飞行动画结束自动落地")
	assert_false(bomb.freeze, "落地转入物理")
	# 重力为 0：落地后无重力加速，速度保持精确为零（静止待推动）。
	assert_eq(bomb.linear_velocity, Vector2.ZERO, "落地后重力为 0 → 速度保持零")
	assert_eq(bomb.angular_velocity, 0.0, "lock_rotation → 无角速度")
	assert_true(is_instance_valid(bomb), "未爆炸仍在场")


func test_scene_contract_gravity_zero_and_rotation_locked() -> void:
	# 场景契约：重力 0（落点静止）、lock_rotation（弹珠推动只平移不旋转）。
	var bomb: DemolitionChargeBomb = BombScene.instantiate() as DemolitionChargeBomb
	add_child_autofree(bomb)
	assert_eq(bomb.gravity_scale, 0.0, "gravity_scale = 0")
	assert_true(bomb.lock_rotation, "lock_rotation = true")
