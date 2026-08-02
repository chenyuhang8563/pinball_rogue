extends GutTest

## 磨轮遗物定向测试：effect 数值（LV1-3 / 觉醒）、墙面反弹充能每发封顶 0.5 层、
## 每发计数在发射时重置、无 BROWN 链不充能、无遗物时墙面不充能（回归）、
## 敌充能与壁充能叠加。

const MarbleScene: PackedScene = preload("res://Combat/marbles/marble.tscn")


class FakeFlipper extends Node:
	signal marble_launched(marble: Marble, applied_impulse: Vector2)
	var progress: float = -1.0
	var updates: Array[float] = []

	func set_echo_charge(value: float) -> void:
		progress = value
		updates.append(value)


func test_charge_per_bounce_levels() -> void:
	var effect := GrindstoneEffect.new()
	effect.set_level(1)
	assert_almost_eq(effect.get_charge_per_bounce(), 0.05, 0.0001, "LV1 +0.05/反弹")
	effect.set_level(2)
	assert_almost_eq(effect.get_charge_per_bounce(), 0.06, 0.0001, "LV2 +0.06/反弹")
	effect.set_level(3)
	assert_almost_eq(effect.get_charge_per_bounce(), 0.07, 0.0001, "LV3 +0.07/反弹")
	effect.set_awakened(true)
	assert_almost_eq(effect.get_charge_per_bounce(), 0.10, 0.0001, "觉醒 +0.10/反弹")


func test_wall_charge_cap_is_half_layer() -> void:
	var effect := GrindstoneEffect.new()
	assert_almost_eq(effect.get_wall_charge_cap(), 0.5, 0.0001, "每发壁充能封顶 0.5 层")


func test_wall_bounces_charge_with_grindstone_capped_per_shot() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"grindstone": GrindstoneEffect.new()})
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))  # 本发开始（出生豁免结束）
	for _index: int in range(10):
		chain.chain_collision.emit(self, "wall")
	assert_almost_eq(controller.get_progress(), 0.5, 0.0001, "10 次反弹累计满 0.5 层封顶")
	chain.chain_collision.emit(self, "wall")
	chain.chain_collision.emit(self, "wall")
	assert_almost_eq(controller.get_progress(), 0.5, 0.0001, "超过每发封顶后不再累计")


func test_launch_resets_per_shot_wall_charge() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"grindstone": GrindstoneEffect.new()})
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))  # 本发开始
	for _index: int in range(10):
		chain.chain_collision.emit(self, "wall")
	assert_almost_eq(controller.get_progress(), 0.5, 0.0001, "10 次反弹累计满封顶")

	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))
	assert_almost_eq(controller.get_progress(), 0.5, 0.0001, "进度不足 1 层发射不消费")

	chain.chain_collision.emit(self, "wall")
	assert_almost_eq(controller.get_progress(), 0.55, 0.0001, "发射后每发计数重置，重新累计")


func test_wall_bounce_before_first_launch_does_not_charge() -> void:
	# 问题 4 回归：战斗开始弹珠出生后第一次撞墙不再莫名 +0.05 蓄力。
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"grindstone": GrindstoneEffect.new()})
	for _index: int in range(4):
		chain.chain_collision.emit(self, "wall")
	assert_almost_eq(controller.get_progress(), 0.0, 0.0001, "首次挡板弹起前墙反弹不充能")

	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))
	chain.chain_collision.emit(self, "wall")
	assert_almost_eq(controller.get_progress(), 0.05, 0.0001, "首次弹起后墙反弹正常充能")


func test_grindstone_charge_is_gated_by_brown() -> void:
	var controller := _controller_with_chain(Marble.MARBLE_TYPE.DEFAULT)
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"grindstone": GrindstoneEffect.new()})
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))  # 本发开始
	for _index: int in range(4):
		chain.chain_collision.emit(self, "wall")
	assert_almost_eq(controller.get_progress(), 0.0, 0.0001, "无 BROWN 链时壁充能无效")


func test_wall_bounces_do_not_charge_without_relic() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	for _index: int in range(4):
		chain.chain_collision.emit(self, "wall")
	assert_almost_eq(controller.get_progress(), 0.0, 0.0001, "无遗物时墙面反弹不充能（回归）")


func test_grindstone_stacks_with_enemy_charge() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"grindstone": GrindstoneEffect.new()})
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))  # 本发开始
	for _index: int in range(2):
		chain.chain_collision.emit(self, "enemy")  # +0.5
	for _index: int in range(6):
		chain.chain_collision.emit(self, "wall")  # +0.3
	assert_almost_eq(controller.get_progress(), 0.8, 0.0001, "敌充能与壁充能叠加")


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


func _marble(marble_type: int) -> Item:
	var item := Item.new()
	item.id = "echo_grindstone_test"
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	item.marble_segment_damage = 5
	return item
