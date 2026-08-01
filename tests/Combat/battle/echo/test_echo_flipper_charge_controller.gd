extends GutTest

## EchoFlipperChargeController 定向测试：BROWN 门控、4 次碰撞累计 1 层、
## 不足整层不消费、消费保留尾数、加速/武装 token、掉球重绑保留、换桌清零。

const MarbleScene: PackedScene = preload("res://Combat/marbles/marble.tscn")


class FakeFlipper extends Node:
	signal marble_launched(marble: Marble, applied_impulse: Vector2)
	var progress: float = -1.0
	var updates: Array[float] = []

	func set_echo_charge(value: float) -> void:
		progress = value
		updates.append(value)


func test_fresh_controller_starts_at_zero() -> void:
	var controller := EchoFlipperChargeController.new()
	add_child_autofree(controller)
	assert_eq(controller.get_progress(), 0.0, "新表实例化后蓄力从 0 开始")
	assert_eq(controller.get_layers(), 0)


func test_enemy_collision_accumulates_quarter_per_hit_up_to_two_layers() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	assert_eq(controller.get_progress(), 1.0, "4 次敌人碰撞累计满 1 层")
	assert_eq(controller.get_layers(), 1)
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	assert_eq(controller.get_progress(), 2.0, "8 次碰撞满 2 层（上限）")
	assert_eq(controller.get_layers(), 2)
	chain.chain_collision.emit(self, "enemy")
	assert_eq(controller.get_progress(), 2.0, "满 2 层后不再累计")


func test_wall_and_flipper_collisions_do_not_charge() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	chain.chain_collision.emit(self, "wall")
	chain.chain_collision.emit(self, "flipper")
	assert_eq(controller.get_progress(), 0.0, "非敌碰撞不累计")


func test_launch_without_full_layer_consumes_nothing() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	var fake := _first_fake_flipper(controller)
	var marble: Marble = _marble_in_tree()
	for _index: int in range(3):
		chain.chain_collision.emit(self, "enemy")  # progress 0.75 < 1
	assert_eq(controller.get_progress(), 0.75)

	fake.marble_launched.emit(marble, Vector2(200, 0))
	await wait_physics_frames(2)

	assert_eq(controller.get_progress(), 0.75, "不足整层不消费")
	assert_eq(chain.get_echo_pending_tokens(), 0, "不武装 token")
	assert_lt(absf(marble.linear_velocity.x), 1.0, "不追加球速冲量")


func test_launch_consumes_one_layer_keeps_tail_and_boosts() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	var fake := _first_fake_flipper(controller)
	var marble: Marble = _marble_in_tree()
	for _index: int in range(5):
		chain.chain_collision.emit(self, "enemy")  # progress 1.25
	assert_eq(controller.get_progress(), 1.25)

	fake.marble_launched.emit(marble, Vector2(200, 0))
	await wait_physics_frames(2)

	assert_eq(controller.get_progress(), 0.25, "消费 1 层，尾数保留")
	assert_eq(chain.get_echo_pending_tokens(), 1, "武装 1 个伤害 token")
	assert_gt(marble.linear_velocity.x, 50.0, "追加球速冲量生效")
	assert_eq(fake.progress, 0.25, "挡板视觉同步到剩余进度")


func test_full_two_layer_launch_consumes_all_with_bigger_boost_and_two_tokens() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	var fake := _first_fake_flipper(controller)
	var marble: Marble = _marble_in_tree()
	for _index: int in range(8):
		chain.chain_collision.emit(self, "enemy")  # progress 2.0（红条满）
	assert_eq(controller.get_progress(), 2.0)

	fake.marble_launched.emit(marble, Vector2(200, 0))
	await wait_physics_frames(2)

	assert_eq(controller.get_progress(), 0.0, "满 2 层发射一次性全部消耗")
	assert_eq(chain.get_echo_pending_tokens(), 2, "满 2 层武装 2 个伤害 token")
	assert_gt(marble.linear_velocity.x, 100.0, "满 2 层球速加成更大（冲量×2）")
	assert_eq(fake.progress, 0.0, "挡板视觉回零")


func test_one_and_half_layer_launch_consumes_one_keeps_tail() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	var fake := _first_fake_flipper(controller)
	var marble: Marble = _marble_in_tree()
	for _index: int in range(6):
		chain.chain_collision.emit(self, "enemy")  # progress 1.5
	assert_eq(controller.get_progress(), 1.5)

	fake.marble_launched.emit(marble, Vector2(200, 0))
	await wait_physics_frames(2)

	assert_eq(controller.get_progress(), 0.5, "1.x 层消费 1 层，尾数保留")
	assert_eq(chain.get_echo_pending_tokens(), 1, "1 层只武装 1 个 token")


func test_chain_rebind_preserves_progress() -> void:
	var controller := _controller_with_chain()
	var chain_a := _chain_of(controller)
	for _index: int in range(5):
		chain_a.chain_collision.emit(self, "enemy")
	assert_eq(controller.get_progress(), 1.25)

	# 掉球：旧链销毁，新链重建并重新绑定；进度保留在控制器。
	chain_a.free()
	var chain_b := MarbleChain.new()
	controller.get_parent().add_child(chain_b)
	chain_b.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(56, 96)])

	assert_eq(controller.get_progress(), 1.25, "掉球重建后进度保留")
	var fake := _first_fake_flipper(controller)
	var marble: Marble = _marble_in_tree()
	fake.marble_launched.emit(marble, Vector2(200, 0))

	assert_eq(controller.get_progress(), 0.25, "进度被新链消费")
	assert_eq(chain_b.get_echo_pending_tokens(), 1, "token 武装在新链上")


func test_no_brown_chain_does_not_charge_or_consume() -> void:
	var controller := _controller_with_chain(Marble.MARBLE_TYPE.DEFAULT)
	var chain := _chain_of(controller)
	assert_false(controller.has_brown(), "无 BROWN 链时机制不激活")
	chain.chain_collision.emit(self, "enemy")
	chain.chain_collision.emit(self, "enemy")
	assert_eq(controller.get_progress(), 0.0, "无 BROWN 不充能")
	var fake := _first_fake_flipper(controller)
	var marble: Marble = _marble_in_tree()
	fake.marble_launched.emit(marble, Vector2(200, 0))
	await wait_physics_frames(2)
	assert_eq(controller.get_progress(), 0.0)
	assert_eq(chain.get_echo_pending_tokens(), 0, "无 BROWN 不武装 token")
	assert_lt(absf(marble.linear_velocity.x), 1.0, "无 BROWN 发射无加成")


func test_binding_non_brown_chain_clears_progress() -> void:
	var controller := _controller_with_chain()
	var chain_a := _chain_of(controller)
	for _index: int in range(5):
		chain_a.chain_collision.emit(self, "enemy")
	assert_eq(controller.get_progress(), 1.25)

	chain_a.free()
	var non_brown := MarbleChain.new()
	controller.get_parent().add_child(non_brown)
	non_brown.build_chain([_marble(Marble.MARBLE_TYPE.DEFAULT)], [Vector2(56, 96)])

	assert_false(controller.has_brown())
	assert_eq(controller.get_progress(), 0.0, "绑定无 BROWN 链时清零蓄力")


func test_reset_clears_and_emits() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	assert_eq(controller.get_progress(), 1.0)

	controller.reset()

	assert_eq(controller.get_progress(), 0.0, "reset 清零")
	assert_eq(_first_fake_flipper(controller).progress, 0.0, "reset 驱动挡板回到无蓄力")


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
	item.id = "echo_test_marble"
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	item.marble_segment_damage = 5
	return item
