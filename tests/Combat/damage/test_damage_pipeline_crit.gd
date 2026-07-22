extends GutTest

## Locks the weak-point crit multiplier into DamagePipeline.resolve_pre_armor for both
## the allowlisted (marble_head) and non-allowlisted (untyped/dot) paths, and pins the
## non-crit legacy rounding boundary so crit defaults (multiplier 1.0) change nothing.


class FakeStatSystem:
	extends Node
	var multiplier: float = 1.0

	func get_stat(stat_id: StringName, _entity_id: StringName, context: RefCounted = null) -> float:
		if stat_id == &"final_damage":
			var base_damage: float = float(context.get("extra").get("base_damage", 0.0))
			return roundi(base_damage * multiplier)
		return multiplier if stat_id == &"damage_multiplier" else 0.0


func test_damage_packet_crit_fields_default_to_inactive() -> void:
	var packet := DamagePacket.new(&"marble_head", 5.0)
	assert_false(packet.is_crit)
	assert_eq(packet.crit_multiplier, 1.0)
	assert_eq(packet.crit_source, &"")
	assert_false(packet.is_perfect_crit)


func test_crit_multiplier_applies_to_allowlisted_marble_source() -> void:
	var stats := FakeStatSystem.new()
	add_child_autofree(stats)
	stats.multiplier = 1.0
	var packet := DamagePacket.new(&"marble_head", 10.0)
	packet.is_crit = true
	packet.crit_multiplier = 1.5
	# legacy formula result = round(10 * 1.0) = 10, then crit x1.5 = 15.
	assert_eq(DamagePipeline.resolve_pre_armor(packet, stats), 15)


func test_crit_multiplier_applies_to_non_allowlisted_source() -> void:
	var stats := FakeStatSystem.new()
	add_child_autofree(stats)
	stats.multiplier = 3.0
	var packet := DamagePacket.new(&"untyped", 10.0)
	packet.is_crit = true
	packet.crit_multiplier = 1.5
	# non-allowlisted path: raw = 10 (multiplier ignored), then crit x1.5 = 15.
	assert_eq(DamagePipeline.resolve_pre_armor(packet, stats), 15)


func test_crit_multiplier_locks_half_value_rounding() -> void:
	var stats := FakeStatSystem.new()
	add_child_autofree(stats)
	stats.multiplier = 1.0
	var packet := DamagePacket.new(&"marble_head", 5.0)
	packet.is_crit = true
	packet.crit_multiplier = 1.5
	# 5 x 1.5 = 7.5 rounds to 8 (half away from zero).
	assert_eq(DamagePipeline.resolve_pre_armor(packet, stats), 8)


func test_non_crit_packet_preserves_legacy_boundary() -> void:
	var stats := FakeStatSystem.new()
	add_child_autofree(stats)
	stats.multiplier = 1.5
	# Identical to the pre-crit regression expectation: round(5 * 1.5) = 8.
	var packet := DamagePacket.new(&"marble_head", 5.0)
	assert_eq(DamagePipeline.resolve_pre_armor(packet, stats), 8)


func test_crit_multiplier_one_is_identity_on_both_paths() -> void:
	var stats := FakeStatSystem.new()
	add_child_autofree(stats)
	stats.multiplier = 2.0
	var allowlisted := DamagePacket.new(&"marble_head", 5.0)
	allowlisted.crit_multiplier = 1.0
	assert_eq(DamagePipeline.resolve_pre_armor(allowlisted, stats), 10)
	var raw := DamagePacket.new(&"dot_poison", 5.0)
	raw.crit_multiplier = 1.0
	assert_eq(DamagePipeline.resolve_pre_armor(raw, stats), 5)
