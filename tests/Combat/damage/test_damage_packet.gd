extends GutTest

## 0a packet contract: only the three legacy marble sources may consume the
## global attack multiplier; metadata alone must not broaden that behavior.


func test_multiplier_allowlist_is_source_based() -> void:
	for source: StringName in [&"marble_head", &"chain_segment", &"bomb"]:
		assert_true(DamagePacket.new(source).applies_global_multiplier(), String(source))
	for source: StringName in [&"untyped", &"dot_poison", &"dot_burn", &"relic_lightning", &"skill_missile"]:
		var packet := DamagePacket.new(source)
		packet.is_marble = true
		assert_false(packet.applies_global_multiplier(), String(source))


func test_packet_defaults_preserve_neutral_combat_metadata() -> void:
	var packet := DamagePacket.new()
	assert_eq(packet.base, 0.0)
	assert_eq(packet.flat, 0.0)
	assert_eq(packet.final_amount, 0)
	assert_false(packet.is_dot)
	assert_false(packet.is_skill)
	assert_false(packet.is_relic)
	assert_eq(packet.proc_coefficient, 1.0)
	assert_eq(packet.generation, 0)
