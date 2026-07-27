extends GutTest

const ExecutionDecreeScript: GDScript = preload("res://Combat/effects/execution_decree/execution_decree.gd")


func test_threshold_arms_then_the_next_independent_main_packet_becomes_a_crit() -> void:
	# 问题来源：暴击流派调优将暴击伤害统一提高至 200%。
	# 修复/边界：敕令制造的暴击也必须使用 ×2，且仍只消费一次武装状态。
	var effect: RefCounted = ExecutionDecreeScript.new()
	for _index: int in range(7):
		var charge := DamagePacket.new(&"untyped", 1.0)
		effect.call("modify_damage_packet", null, charge)
	assert_true(bool(effect.get("armed")))
	var execution := DamagePacket.new(&"untyped", 1.0)
	effect.call("modify_damage_packet", null, execution)
	assert_true(execution.is_crit)
	assert_eq(execution.crit_source, &"execution_decree")
	assert_eq(execution.crit_multiplier, 2.0)
	assert_false(bool(effect.get("armed")))
	assert_eq(int(effect.get("progress")), 0)


func test_shared_event_only_arms_after_event_is_flushed() -> void:
	var effect: RefCounted = ExecutionDecreeScript.new()
	for _index: int in range(7):
		var packet := DamagePacket.new(&"bomb", 1.0)
		packet.event_id = 123
		packet.is_event_main = false
		effect.call("modify_damage_packet", null, packet)
		assert_false(packet.is_crit)
	assert_false(bool(effect.get("armed")))
	var next := DamagePacket.new(&"untyped", 1.0)
	effect.call("modify_damage_packet", null, next)
	assert_true(next.is_crit, "the next event's main target consumes the post-AOE arm")
	assert_false(bool(effect.get("armed")))
