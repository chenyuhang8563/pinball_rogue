extends GutTest

class FakeStatSystem:
	extends Node
	var multiplier: float = 1.0

	func get_stat(stat_id: StringName, _entity_id: StringName, context: RefCounted = null) -> float:
		if stat_id == &"final_damage":
			var base_damage: float = float(context.get("extra").get("base_damage", 0.0))
			return roundi(base_damage * multiplier)
		return multiplier if stat_id == &"damage_multiplier" else 0.0


func test_pre_armor_uses_legacy_rounding_for_allowlisted_sources() -> void:
	# Regression source: GUT previously hung because this fake did not match
	# StatSystem.get_stat's optional context argument. Boundary: legacy formula context.
	var stats := FakeStatSystem.new()
	add_child_autofree(stats)
	stats.multiplier = 1.5
	var packet := DamagePacket.new(&"marble_head", 5.0)
	assert_eq(DamagePipeline.resolve_pre_armor(packet, stats), 8)


func test_pre_armor_leaves_dot_relic_and_untyped_damage_unmultiplied() -> void:
	var stats := FakeStatSystem.new()
	add_child_autofree(stats)
	stats.multiplier = 3.0
	for source: StringName in [&"dot_poison", &"relic_lightning", &"skill_missile", &"untyped"]:
		assert_eq(DamagePipeline.resolve_pre_armor(DamagePacket.new(source, 5.0), stats), 5, String(source))


func test_pre_armor_clamps_negative_base_plus_flat_to_zero() -> void:
	var packet := DamagePacket.new(&"untyped", -2.0)
	packet.flat = 1.0
	assert_eq(DamagePipeline.resolve_pre_armor(packet), 0)
