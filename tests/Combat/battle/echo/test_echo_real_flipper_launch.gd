extends GutTest

## 真实发射链路：真实 flipper.tscn 的 _apply_swing_impulse → marble_launched 信号
## → 控制器消费蓄力 + 武装 token。用于排查"发射没有消费层数和伤害 token"。

const TableBaseScene: PackedScene = preload("res://Combat/levels/table_base.tscn")
const MarbleScene: PackedScene = preload("res://Combat/marbles/marble.tscn")


func test_real_flipper_launch_consumes_charge_and_arms_token() -> void:
	var table: Node = TableBaseScene.instantiate()
	add_child_autofree(table)
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	chain.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(56, 96)])
	var controller := table.get_node("EchoCharge")
	assert_true(controller.has_brown(), "BROWN 链应激活回响机制")

	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	assert_eq(controller.get_progress(), 1.0, "4 次敌人碰撞攒满 1 层")

	var flipper := table.get_node("LFlipper")
	var marble: Marble = MarbleScene.instantiate()
	add_child_autofree(marble)
	marble.global_position = Vector2(96, 200)
	flipper.call("_apply_swing_impulse", marble)

	assert_eq(controller.get_progress(), 0.0, "真实挡板发射应消费 1 层")
	assert_eq(chain.get_echo_pending_tokens(), 1, "应武装 1 个伤害 token")
	assert_eq(controller.get_layers(), 0)


func test_real_physics_launch_emits_signal_and_consumes() -> void:
	# 真实物理链路：按键抬升挡板 → _apply_swing_impulse_to_overlapping_marbles
	# → marble_launched → 控制器消费蓄力 + 武装 token。
	# 回归对象：AnimatableBody2D transform 读回滞后导致 _angular_velocity 恒 0，
	# 主动冲量从未生效、marble_launched 从未发出。
	var table: Node = TableBaseScene.instantiate()
	add_child_autofree(table)
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	chain.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(56, 96)])
	var controller := table.get_node("EchoCharge")
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	assert_eq(controller.get_progress(), 1.0, "4 次敌人碰撞攒满 1 层")

	var flipper := table.get_node("LFlipper")
	var marble: Marble = MarbleScene.instantiate()
	add_child_autofree(marble)
	marble.global_position = flipper.global_position + Vector2(22, -10)
	marble.linear_velocity = Vector2.ZERO
	var launches: Array = []
	flipper.marble_launched.connect(func(_m: Marble, _i: Vector2) -> void:
		launches.append(true)
	)
	Input.action_press("ui_left")
	await wait_physics_frames(40)
	Input.action_release("ui_left")

	assert_gt(launches.size(), 0, "真实物理发射必须发出 marble_launched")
	assert_eq(controller.get_progress(), 0.0, "发射应消费 1 层")
	assert_eq(chain.get_echo_pending_tokens(), 1, "应武装 1 个伤害 token")


func test_real_flipper_without_full_layer_does_not_consume() -> void:
	var table: Node = TableBaseScene.instantiate()
	add_child_autofree(table)
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	chain.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(56, 96)])
	var controller := table.get_node("EchoCharge")
	for _index: int in range(2):
		chain.chain_collision.emit(self, "enemy")
	assert_eq(controller.get_progress(), 0.5)

	var flipper := table.get_node("LFlipper")
	var marble: Marble = MarbleScene.instantiate()
	add_child_autofree(marble)
	flipper.call("_apply_swing_impulse", marble)

	assert_eq(controller.get_progress(), 0.5, "不足整层不消费")
	assert_eq(chain.get_echo_pending_tokens(), 0)


func _marble(marble_type: int) -> Item:
	var item := Item.new()
	item.id = "echo_launch_test"
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	item.marble_segment_damage = 5
	return item
