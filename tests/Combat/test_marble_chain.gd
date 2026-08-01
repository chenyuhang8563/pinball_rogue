extends GutTest

const MarbleChainScript: GDScript = preload("res://Combat/marbles/marble_chain.gd")
const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")
const ASSASSIN_HEAD_TEST_SOURCE: StringName = &"marble_chain_assassin_head_test"


class DamageableEnemy extends Node2D:
	var received_damage: int = 0
	var received_buff_count: int = 0


	func take_damage(amount: int) -> void:
		received_damage += amount


	func add_buff(_buff: BuffDef, _stacks: int, _packet: DamagePacket = null) -> void:
		received_buff_count += 1


	func has_buff(_buff_id: StringName) -> bool:
		return false


	func get_buff_stacks(_buff_id: StringName) -> int:
		return 0


func test_first_equipped_marble_defines_head_type() -> void:
	# 问题来源：卖出黑色弹珠后，战斗链首颗非默认弹珠仍被创建为黑色 Head。
	# 修复方式与边界：Head 必须采用装备序列首项的类型；单颗非默认弹珠也必须保持其类型。
	var chain: MarbleChain = MarbleChainScript.new()
	add_child_autofree(chain)
	var only_bomb := _marble("only_bomb", Marble.MARBLE_TYPE.BOMB)

	chain.build_chain([only_bomb], [Vector2(56, 96)])

	assert_not_null(chain.head)
	assert_eq(chain.head.marble_type, Marble.MARBLE_TYPE.BOMB)
	assert_eq(chain.body.size(), 0)


func test_bomb_head_explodes_when_it_is_the_only_remaining_marble() -> void:
	# 问题来源：卖出黑色弹珠后，炸弹弹珠成为 Head 却不会在命中敌人时爆炸。
	# 修复方式与边界：Head 与 Body 必须共享特殊效果判定；仅剩一颗炸弹弹珠也应造成爆炸伤害。
	var chain: MarbleChain = MarbleChainScript.new()
	var enemy := DamageableEnemy.new()
	add_child_autofree(chain)
	add_child_autofree(enemy)
	chain.build_chain([_marble("only_bomb", Marble.MARBLE_TYPE.BOMB)], [Vector2(56, 96)])
	enemy.global_position = chain.head.global_position
	enemy.add_to_group("enemies")

	chain.call("_on_head_body_entered", enemy)

	assert_true(enemy.received_damage > 0, "唯一的炸弹 Head 命中敌人时应触发爆炸伤害")


func test_elemental_head_applies_its_status_when_it_is_the_only_remaining_marble() -> void:
	# 问题来源：卖出黑色弹珠后，首位的绿、蓝、火弹珠只保留了类型，命中不再施加状态。
	# 修复方式与边界：所有元素弹珠在 Head 或 Body 位置都应施加一次对应状态；此处覆盖仅剩一颗的边界。
	for marble_type: Marble.MARBLE_TYPE in [
		Marble.MARBLE_TYPE.GREEN,
		Marble.MARBLE_TYPE.BLUE,
		Marble.MARBLE_TYPE.FIRE,
	]:
		var chain: MarbleChain = MarbleChainScript.new()
		var enemy := DamageableEnemy.new()
		add_child_autofree(chain)
		add_child_autofree(enemy)
		chain.build_chain([_marble("only_%d" % marble_type, marble_type)], [Vector2(56, 96)])

		chain.get_total_damage(enemy)

		assert_eq(enemy.received_buff_count, 1, "%d Head 命中敌人时应施加状态" % marble_type)


func test_armed_echo_token_adds_damage_and_flags_packet_on_enemy_hit() -> void:
	# 回响弹珠重构：伤害 token 由挡板消费蓄力后武装（arm_echo_damage），
	# 敌人命中消费一个 token 并标记 is_echo；非敌目标不消费。
	var chain: MarbleChain = MarbleChainScript.new()
	var enemy := DamageableEnemy.new()
	var brown := _marble("only_brown", Marble.MARBLE_TYPE.BROWN)
	brown.marble_segment_damage = 5
	add_child_autofree(chain)
	add_child_autofree(enemy)
	chain.build_chain([brown], [Vector2(56, 96)])
	enemy.add_to_group("enemies")
	var packet := DamagePacket.new(&"marble_head", 0.0)

	chain.arm_echo_damage(1)
	var total := chain.get_total_damage(enemy, packet)

	assert_true(packet.is_echo, "消费 token 的命中必须标记 is_echo")
	assert_eq(total, 7, "token 追加 echo_bonus_damage（默认 2），5 + 2 = 7")
	assert_eq(chain.get_echo_pending_tokens(), 0, "token 消费后清零")
	assert_eq(chain.get_total_damage(enemy), 5, "无 token 时不再追加")


func test_echo_token_is_not_consumed_by_non_enemy_target() -> void:
	# 墙面/挡板等非敌碰撞不消费待结算 token。
	var chain: MarbleChain = MarbleChainScript.new()
	var wall := StaticBody2D.new()
	var brown := _marble("only_brown", Marble.MARBLE_TYPE.BROWN)
	brown.marble_segment_damage = 5
	add_child_autofree(chain)
	add_child_autofree(wall)
	chain.build_chain([brown], [Vector2(56, 96)])

	chain.arm_echo_damage(1)
	var total := chain.get_total_damage(wall)

	assert_eq(total, 5, "非敌目标不消费 token 也不追加伤害")
	assert_eq(chain.get_echo_pending_tokens(), 1, "token 保留")


func test_has_brown_marble_reflects_head_and_body() -> void:
	# BROWN 门控：回响蓄力仅在链中存在 BROWN（大地）弹珠时激活。
	var chain: MarbleChain = MarbleChainScript.new()
	add_child_autofree(chain)

	chain.build_chain([_marble("dark", Marble.MARBLE_TYPE.DEFAULT)], [Vector2(56, 96)])
	assert_false(chain.has_brown_marble(), "无 BROWN 时机制不激活")

	chain.build_chain([_marble("brown_head", Marble.MARBLE_TYPE.BROWN)], [Vector2(56, 96)])
	assert_true(chain.has_brown_marble(), "BROWN 作为 Head 时激活")

	chain.build_chain([
		_marble("dark_head", Marble.MARBLE_TYPE.DEFAULT),
		_marble("brown_body", Marble.MARBLE_TYPE.BROWN),
	], [Vector2(56, 96), Vector2(56, 72)])
	assert_true(chain.has_brown_marble(), "BROWN 在 Body 段时同样激活")


func test_assassin_head_uses_assassin_damage_stat_when_it_is_the_only_remaining_marble() -> void:
	# 问题来源：卖出黑色弹珠后，刺客弹珠成为 Head 仍错误读取黑色弹珠伤害属性。
	# 修复方式与边界：唯一的刺客 Head 必须读取 assassin_segment_damage，保留升级后的伤害成长。
	var stat_system := get_node_or_null("/root/StatSystem") as Node
	assert_not_null(stat_system)
	stat_system.add_modifier(
		"marble_chain",
		StatModifierScript.new(
			"%s:damage" % ASSASSIN_HEAD_TEST_SOURCE,
			"assassin_segment_damage",
			StatModifier.ModOp.OVERRIDE,
			9.0,
			ASSASSIN_HEAD_TEST_SOURCE
		)
	)
	var chain: MarbleChain = MarbleChainScript.new()
	add_child_autofree(chain)
	chain.build_chain([_marble("only_assassin", Marble.MARBLE_TYPE.ASSASSIN)], [Vector2(56, 96)])
	var total_damage := chain.get_total_damage(null)
	stat_system.remove_modifiers_by_source("marble_chain", ASSASSIN_HEAD_TEST_SOURCE)

	assert_eq(total_damage, 9)


func _marble(id: String, marble_type: Marble.MARBLE_TYPE) -> Item:
	var item := Item.new()
	item.id = id
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	return item
