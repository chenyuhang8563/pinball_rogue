extends GutTest

const FortunaDiceScript: GDScript = preload("res://Combat/effects/fortuna_dice/fortuna_dice.gd")


func test_dice_skips_dot_packets() -> void:
	var effect: RefCounted = FortunaDiceScript.new()
	var packet := DamagePacket.new(&"dot_poison", 10.0)
	packet.is_dot = true
	effect.call("modify_damage_packet", null, packet)
	assert_eq(packet.damage_multiplier, 1.0)


func test_dice_rolls_a_legal_face_for_every_immediate_packet() -> void:
	var effect: RefCounted = FortunaDiceScript.new()
	effect.call("seed_rng", 42)
	var packet := DamagePacket.new(&"untyped", 10.0)
	effect.call("modify_damage_packet", null, packet)
	assert_has([0.7, 0.8, 0.9, 1.1, 1.3, 1.5], packet.damage_multiplier)


func test_awakened_dice_never_keeps_a_low_face() -> void:
	var effect: RefCounted = FortunaDiceScript.new()
	effect.call("set_awakened", true)
	effect.call("seed_rng", 9)
	for _index: int in range(20):
		var packet := DamagePacket.new(&"untyped", 10.0)
		effect.call("modify_damage_packet", null, packet)
		assert_gte(packet.damage_multiplier, 1.1)
