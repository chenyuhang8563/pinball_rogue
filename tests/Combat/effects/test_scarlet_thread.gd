extends GutTest

const ScarletThreadScript: GDScript = preload("res://Combat/effects/scarlet_thread/scarlet_thread.gd")
const WhetstoneScript: GDScript = preload("res://Combat/effects/assassins_whetstone/assassins_whetstone.gd")


class DamageTarget:
	extends Node2D
	var packets: Array[DamagePacket] = []

	func apply_damage_packet(packet: DamagePacket) -> void:
		packets.append(packet)

	func is_alive() -> bool:
		return true


var _stat_system: Node


func before_each() -> void:
	_stat_system = get_node_or_null("/root/StatSystem")
	assert_not_null(_stat_system)


func after_each() -> void:
	if _stat_system != null:
		_stat_system.remove_modifiers_by_source("marble_chain", "relic:assassins_whetstone")


func test_scarlet_thread_level_values_and_awakened_extra_target_damage() -> void:
	# Source: reported Scarlet Thread damage is too low; awakened extra thread must be fixed at 150%.
	# Boundary: levels are 50/100/150%, while the extra target stays 150% at every level.
	for level: int in [1, 2, 3]:
		var origin := _target_at(Vector2.ZERO)
		var target := _target_at(Vector2(20.0, 0.0))
		var effect: RefCounted = ScarletThreadScript.new()
		effect.call("set_level", level)
		effect.call("on_damage_dealt", origin, _crit_packet())
		assert_eq(target.packets.size(), 1, "Lv%d finds the nearby enemy" % level)
		assert_eq(target.packets[0].base, [50.0, 100.0, 150.0][level - 1])
		origin.remove_from_group("enemies")
		target.remove_from_group("enemies")

	for level: int in [1, 2, 3]:
		var awakened_origin := _target_at(Vector2.ZERO)
		var first := _target_at(Vector2(10.0, 0.0))
		var second := _target_at(Vector2(20.0, 0.0))
		var awakened: RefCounted = ScarletThreadScript.new()
		awakened.call("set_level", level)
		awakened.call("set_awakened", true)
		awakened.call("on_damage_dealt", awakened_origin, _crit_packet())
		assert_eq(first.packets.size(), 1, "awakened Lv%d hits the nearest target" % level)
		assert_eq(second.packets.size(), 1, "awakened Lv%d hits the second target" % level)
		assert_eq(first.packets[0].base, [50.0, 100.0, 150.0][level - 1], "primary thread keeps its level value")
		assert_eq(second.packets[0].base, 150.0, "awakened extra thread stays at 150%")
		awakened_origin.remove_from_group("enemies")
		first.remove_from_group("enemies")
		second.remove_from_group("enemies")


func test_whetstone_preserves_its_relative_tolerance_growth_from_the_new_base() -> void:
	# Source: the larger base tolerance must not make Whetstone's growth curve regress.
	# Boundary: levels override to 23/26/29 degrees, preserving the old +3/+6/+9 offsets.
	for level: int in [1, 2, 3]:
		_stat_system.remove_modifiers_by_source("marble_chain", "relic:assassins_whetstone")
		var effect: RefCounted = WhetstoneScript.new()
		effect.call("set_level", level)
		assert_eq(_stat_system.get_stat("weak_point_tolerance_deg", "marble_chain"), [23.0, 26.0, 29.0][level - 1])


func _target_at(position: Vector2) -> DamageTarget:
	var target := DamageTarget.new()
	target.global_position = position
	add_child_autofree(target)
	target.add_to_group("enemies")
	return target


func _crit_packet() -> DamagePacket:
	var packet := DamagePacket.new(&"marble_head", 100.0)
	packet.is_crit = true
	return packet
