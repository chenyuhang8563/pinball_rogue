extends GutTest

## 锻锤遗物定向测试：effect 数值（LV1-3 (3,3)/(3,4)/(3,5)、觉醒 (2,5)）、
## 发射时按本发反弹计数武装每 token 追加伤害、封顶、计数每发重置、
## 锻锤只计数不充能（壁充能属于磨轮）。

const MarbleScene: PackedScene = preload("res://Combat/marbles/marble.tscn")
const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")
## DEFAULT Head 接触伤害（dark_marble_damage 无 StatSystem 时的 fallback）。
const HEAD_BASE_DAMAGE: int = 5
## echo_bonus_damage 无 StatSystem 时的 fallback。
const ECHO_BASE_DAMAGE: int = 2


class FakeFlipper extends Node:
	signal marble_launched(marble: Marble, applied_impulse: Vector2)
	var progress: float = -1.0
	var updates: Array[float] = []

	func set_echo_charge(value: float) -> void:
		progress = value
		updates.append(value)


func test_bonus_scales_by_level_and_awakening() -> void:
	var effect := DropHammerEffect.new()
	effect.set_level(1)  # (3, 3)
	assert_eq(effect.get_bonus(0), 0)
	assert_eq(effect.get_bonus(2), 0, "不足 step 不加成")
	assert_eq(effect.get_bonus(3), 1, "3 次反弹 +1")
	assert_eq(effect.get_bonus(6), 2)
	assert_eq(effect.get_bonus(9), 3)
	assert_eq(effect.get_bonus(12), 3, "LV1 封顶 +3")
	effect.set_level(2)  # (3, 4)
	assert_eq(effect.get_bonus(12), 4, "LV2 封顶 +4")
	effect.set_level(3)  # (3, 5)
	assert_eq(effect.get_bonus(15), 5, "LV3 封顶 +5")
	effect.set_awakened(true)  # (2, 5)
	assert_eq(effect.get_bonus(1), 0)
	assert_eq(effect.get_bonus(2), 1, "觉醒每 2 次反弹 +1")
	assert_eq(effect.get_bonus(10), 5, "觉醒封顶 +5")


func test_launch_arms_token_with_bounce_bonus() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"drop_hammer": DropHammerEffect.new()})
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))  # 本发开始（出生豁免结束）
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")  # 1 层
	for _index: int in range(3):
		chain.chain_collision.emit(self, "wall")  # 3 次反弹 → bonus +1
	assert_almost_eq(controller.get_progress(), 1.0, 0.0001, "锻锤只计数不充能（壁充能属于磨轮）")

	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))
	assert_eq(chain.get_echo_pending_tokens(), 1, "消费 1 层武装 1 个 token")

	var total: int = _hit_total(chain)
	assert_eq(total, HEAD_BASE_DAMAGE + ECHO_BASE_DAMAGE + 1, "命中伤害 = 基础 + 回响(2) + 锻锤(+1)")
	assert_eq(chain.get_echo_pending_tokens(), 0, "命中消费 token")


func test_bonus_capped_at_level_cap() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"drop_hammer": DropHammerEffect.new()})
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))  # 本发开始
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	for _index: int in range(9):
		chain.chain_collision.emit(self, "wall")  # 9 次反弹 → min(3, 3) = 3
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))
	var total: int = _hit_total(chain)
	assert_eq(total, HEAD_BASE_DAMAGE + ECHO_BASE_DAMAGE + 3, "9 次反弹 bonus 封顶 +3")


func test_full_two_layer_launch_arms_two_tokens_with_same_bonus() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"drop_hammer": DropHammerEffect.new()})
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))  # 本发开始
	for _index: int in range(8):
		chain.chain_collision.emit(self, "enemy")  # 2 层
	for _index: int in range(6):
		chain.chain_collision.emit(self, "wall")  # 6 次反弹 → bonus +2
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))
	assert_eq(chain.get_echo_pending_tokens(), 2, "满 2 层武装 2 个 token")

	var target := _fake_enemy()
	var packet: DamagePacket = DamagePacketScript.new(&"marble_head", 0.0)
	assert_eq(chain.get_total_damage(target, packet), HEAD_BASE_DAMAGE + ECHO_BASE_DAMAGE + 2, "第一个 token 带锻锤加成")
	assert_eq(chain.get_echo_pending_tokens(), 1)
	assert_eq(chain.get_total_damage(target, packet), HEAD_BASE_DAMAGE + ECHO_BASE_DAMAGE + 2, "第二个 token 同加成")


func test_bounce_count_resets_each_launch() -> void:
	var controller := _controller_with_chain()
	var chain := _chain_of(controller)
	controller.set_echo_effects({&"drop_hammer": DropHammerEffect.new()})
	var fake := _first_fake_flipper(controller)
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))  # 本发开始
	for _index: int in range(3):
		chain.chain_collision.emit(self, "wall")
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))  # 无层数，不消费但重置计数
	for _index: int in range(4):
		chain.chain_collision.emit(self, "enemy")
	for _index: int in range(3):
		chain.chain_collision.emit(self, "wall")  # 本发 3 次反弹
	fake.marble_launched.emit(_marble_in_tree(), Vector2(200, 0))
	var total: int = _hit_total(chain)
	assert_eq(total, HEAD_BASE_DAMAGE + ECHO_BASE_DAMAGE + 1, "计数已重置：bonus 按本发 3 次 = +1（而非累积 6 次 = +2）")


func _hit_total(chain: MarbleChain) -> int:
	var packet: DamagePacket = DamagePacketScript.new(&"marble_head", 0.0)
	return chain.get_total_damage(_fake_enemy(), packet)


func _fake_enemy() -> Node2D:
	var enemy := Node2D.new()
	add_child_autofree(enemy)
	enemy.add_to_group("enemies")
	return enemy


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
	item.id = "echo_hammer_test"
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	item.marble_segment_damage = 5
	return item
