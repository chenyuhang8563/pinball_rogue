extends GutTest

## 破城锥遗物定向测试（时间制）：effect 时长数值（LV1-3: 3/3.5/4 秒，觉醒 5 秒 +
## 穿透伤害 ×1.5）、强力击发射进入穿透态（掩码 13→5 + 传感器 + 金色描边）、
## 穿透命中复用完整伤害管线并维持「命中敌人 → 蓄力」、时间制命中不减时长、
## 逐敌去重、时长耗尽延迟退出、真实物理穿过敌人而不弹开（对照组：普通命中弹回）。

const MarbleScene: PackedScene = preload("res://Combat/marbles/marble.tscn")
const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")

const HEAD_COLLISION_MASK_NORMAL: int = 45
const HEAD_COLLISION_MASK_PIERCING: int = 5
## BROWN Head 接触伤害（无 StatSystem 时 = head.damage）。
const HEAD_BASE_DAMAGE: int = 5


class FakeFlipper extends Node:
	signal marble_launched(marble: Marble, applied_impulse: Vector2)
	var progress: float = -1.0
	var updates: Array[float] = []

	func set_echo_charge(value: float) -> void:
		progress = value
		updates.append(value)


class FakeEnemy extends Node2D:
	var hits: Array = []

	func _on_body_entered(body: Node) -> void:
		hits.append(body)


func test_pierce_duration_levels() -> void:
	var effect := BatteringRamEffect.new()
	effect.set_level(1)
	assert_almost_eq(effect.get_pierce_duration(), 3.0, 0.0001, "LV1 穿透 3 秒")
	effect.set_level(2)
	assert_almost_eq(effect.get_pierce_duration(), 3.5, 0.0001, "LV2 穿透 3.5 秒")
	effect.set_level(3)
	assert_almost_eq(effect.get_pierce_duration(), 4.0, 0.0001, "LV3 穿透 4 秒")
	effect.set_awakened(true)
	assert_almost_eq(effect.get_pierce_duration(), 5.0, 0.0001, "觉醒穿透 5 秒")


func test_pierce_damage_multiplier_levels() -> void:
	var effect := BatteringRamEffect.new()
	effect.set_level(3)
	assert_almost_eq(effect.get_pierce_damage_multiplier(), 1.0, 0.0001, "LV1-3 穿透伤害无加成")
	effect.set_awakened(true)
	assert_almost_eq(effect.get_pierce_damage_multiplier(), 1.5, 0.0001, "觉醒穿透伤害 ×1.5")


func test_launch_enters_pierce_state_with_duration() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"battering_ram": BatteringRamEffect.new()})
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")  # 1 层

	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))

	assert_true(chain.is_piercing(), "发射后进入穿透态")
	assert_almost_eq(chain.get_pierce_time_left(), 3.0, 0.0001, "剩余时长 = LV1 的 3 秒")
	assert_eq(chain.head.collision_mask, HEAD_COLLISION_MASK_PIERCING, "穿透期间移除 enemy 碰撞层")
	assert_true(_has_pierce_sensor(chain), "挂载穿透传感器")


func test_pierce_hit_resolves_full_damage_and_emits_chain_collision() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"battering_ram": BatteringRamEffect.new()})
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))

	var collisions: Array[String] = []
	chain.chain_collision.connect(func(_c: Node, t: String) -> void:
		collisions.append(t)
	)
	var enemy := FakeEnemy.new()
	add_child_autofree(enemy)
	enemy.add_to_group("enemies")
	chain.call("_on_pierce_sensor_body_entered", enemy)

	assert_eq(enemy.hits.size(), 1, "复用 Enemy 完整命中管线")
	assert_eq(collisions, ["enemy"], "穿透命中发出 chain_collision(enemy)（维持命中→蓄力）")
	assert_gt(chain.get_pierce_time_left(), 0.0, "时间制命中不减少剩余时长")


func test_same_enemy_not_double_hit_until_exit() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"battering_ram": BatteringRamEffect.new()})
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))

	var enemy := FakeEnemy.new()
	add_child_autofree(enemy)
	enemy.add_to_group("enemies")
	chain.call("_on_pierce_sensor_body_entered", enemy)
	assert_eq(enemy.hits.size(), 1)
	chain.call("_on_pierce_sensor_body_entered", enemy)
	assert_eq(enemy.hits.size(), 1, "同敌重叠不重复结算")

	chain.call("_on_pierce_sensor_body_exited", enemy)
	chain.call("_on_pierce_sensor_body_entered", enemy)
	assert_eq(enemy.hits.size(), 2, "退出传感器后可再次命中")


func test_pierce_hits_multiple_enemies_without_reducing_time() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"battering_ram": BatteringRamEffect.new()})
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))

	var enemy_a := FakeEnemy.new()
	add_child_autofree(enemy_a)
	enemy_a.add_to_group("enemies")
	var enemy_b := FakeEnemy.new()
	add_child_autofree(enemy_b)
	enemy_b.add_to_group("enemies")
	chain.call("_on_pierce_sensor_body_entered", enemy_a)
	chain.call("_on_pierce_sensor_body_entered", enemy_b)
	assert_eq(enemy_a.hits.size(), 1)
	assert_eq(enemy_b.hits.size(), 1, "时间制下可穿过多个敌人")
	assert_gt(chain.get_pierce_time_left(), 0.0, "每次命中不减少时长")


func test_pierce_time_expires_and_exits() -> void:
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	chain.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(56, 96)])
	chain.enter_pierce_state(3.0)
	assert_true(chain.is_piercing())

	chain._pierce_time_left = 0.01  # 模拟时长即将耗尽
	await wait_physics_frames(5)

	assert_false(chain.is_piercing(), "时长耗尽退出穿透态")
	assert_eq(chain.head.collision_mask, HEAD_COLLISION_MASK_NORMAL, "恢复完整碰撞掩码")
	assert_false(_has_pierce_sensor(chain), "穿透传感器已移除")


func test_awakened_multiplier_applies_to_pierce_damage() -> void:
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	chain.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(56, 96)])
	chain.enter_pierce_state(5.0, 1.5)

	var target := _fake_enemy()
	var packet: DamagePacket = DamagePacketScript.new(&"marble_head", 0.0)
	assert_eq(chain.get_total_damage(target, packet), 8, "觉醒穿透伤害 = 5 × 1.5 = 7.5 → 8")

	chain.exit_pierce_state()
	assert_eq(chain.get_total_damage(target, packet), HEAD_BASE_DAMAGE, "退出穿透后恢复基础伤害")


func test_pierce_visual_turns_golden_and_restores() -> void:
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	chain.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(56, 96)])
	var sprite: Sprite2D = chain.head.get_node("Sprite2D") as Sprite2D
	var material: ShaderMaterial = sprite.material as ShaderMaterial
	assert_not_null(material, "弹珠带描边 ShaderMaterial")

	chain.enter_pierce_state(3.0)
	assert_eq(material.get_shader_parameter(&"clr"), MarbleChain.PIERCE_OUTLINE_COLOR, "穿透态金色描边")
	assert_almost_eq(float(material.get_shader_parameter(&"thickness")), 2.0, 0.0001, "穿透态描边加粗")

	chain.exit_pierce_state()
	assert_eq(material.get_shader_parameter(&"clr"), Color.WHITE, "退出后恢复白色描边")
	assert_almost_eq(float(material.get_shader_parameter(&"thickness")), 1.0, 0.0001, "退出后描边恢复默认粗细")


func test_launch_without_ram_does_not_pierce() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))
	assert_false(chain.is_piercing(), "无破城锥不强穿")
	assert_eq(chain.head.collision_mask, HEAD_COLLISION_MASK_NORMAL, "掩码不变")


func test_enter_pierce_without_chain_head_is_noop() -> void:
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	chain.enter_pierce_state(3.0)
	assert_false(chain.is_piercing(), "无 Head 时穿透态为 noop")


func test_real_physics_pierces_through_enemy_without_bounce() -> void:
	var table := Node2D.new()
	add_child_autofree(table)
	var chain := MarbleChain.new()
	table.add_child(chain)
	chain.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(64, 160)])
	var enemy := EnemyScene.instantiate()
	table.add_child(enemy)
	enemy.global_position = Vector2(200, 160)

	chain.enter_pierce_state(3.0)
	chain.head.set_sleeping(false)
	chain.head.linear_velocity = Vector2(600, 0)
	await wait_physics_frames(40)

	assert_lt(enemy.health, 100, "穿透命中造成伤害")
	assert_true(chain.is_piercing(), "3 秒时长内仍处穿透态")
	assert_gt(chain.head.global_position.x, 200, "弹珠穿过敌人而非弹开")

	chain._pierce_time_left = 0.01  # 模拟时长耗尽
	await wait_physics_frames(5)
	assert_false(chain.is_piercing(), "时长耗尽退出穿透态")
	assert_eq(chain.head.collision_mask, HEAD_COLLISION_MASK_NORMAL, "穿透结束恢复完整掩码")


func test_real_physics_normal_hit_bounces_off_enemy() -> void:
	var table := Node2D.new()
	add_child_autofree(table)
	var chain := MarbleChain.new()
	table.add_child(chain)
	chain.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(64, 160)])
	var enemy := EnemyScene.instantiate()
	table.add_child(enemy)
	enemy.global_position = Vector2(120, 160)

	chain.head.set_sleeping(false)
	chain.head.linear_velocity = Vector2(600, 0)
	await wait_physics_frames(40)

	assert_lt(enemy.health, 100, "普通命中造成伤害")
	assert_lt(chain.head.global_position.x, 120, "普通命中弹珠被弹回（对照组）")


func _has_pierce_sensor(chain: MarbleChain) -> bool:
	if chain.head == null or not is_instance_valid(chain.head):
		return false
	for child: Node in chain.head.get_children():
		if child is Area2D and child.name == "EchoPierceSensor":
			return true
	return false


func _controller_with_chain(marble_type: int = Marble.MARBLE_TYPE.BROWN) -> EchoFlipperChargeController:
	var table := Node2D.new()
	add_child_autofree(table)
	var fake := FakeFlipper.new()
	table.add_child(fake)
	var controller := EchoFlipperChargeController.new()
	table.add_child(controller)
	var chain := MarbleChain.new()
	table.add_child(chain)
	chain.build_chain([_marble(marble_type)], [Vector2(56, 96)])
	return controller


func _chain_of(controller: EchoFlipperChargeController) -> MarbleChain:
	for child: Node in controller.get_parent().get_children():
		if child is MarbleChain:
			return child as MarbleChain
	return null


func _first_fake_flipper(controller: EchoFlipperChargeController) -> FakeFlipper:
	for child: Node in controller.get_parent().get_children():
		if child is FakeFlipper:
			return child as FakeFlipper
	return null


func _marble_in_tree() -> Marble:
	var marble: Marble = MarbleScene.instantiate()
	add_child_autofree(marble)
	marble.global_position = Vector2(96, 160)
	marble.linear_velocity = Vector2.ZERO
	marble.set_sleeping(false)
	return marble


func _fake_enemy() -> Node2D:
	var enemy := Node2D.new()
	add_child_autofree(enemy)
	enemy.add_to_group("enemies")
	return enemy


func _marble(marble_type: int) -> Item:
	var item := Item.new()
	item.id = "echo_ram_test"
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	item.marble_segment_damage = 5
	return item
