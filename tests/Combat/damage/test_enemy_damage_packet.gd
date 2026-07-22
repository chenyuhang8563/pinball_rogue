extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")

class RecordingEffect:
	extends RefCounted
	var order: Array[StringName] = []
	var packets: Array[DamagePacket] = []

	func on_damage_dealt(_enemy: Node2D, packet: DamagePacket) -> void:
		order.append(&"damage")
		packets.append(packet)

	func on_enemy_defeated(_enemy: Node2D, packet: DamagePacket) -> void:
		order.append(&"enemy_defeated")
		packets.append(packet)

var _effect_manager: Node


func before_each() -> void:
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	_effect_manager.set("_active_effects", {})


func after_each() -> void:
	if _effect_manager != null and is_instance_valid(_effect_manager):
		_effect_manager.set("_active_effects", {})


func test_marble_packet_uses_multiplier_but_untyped_packet_does_not() -> void:
	var enemy: Enemy = _enemy()
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	stat_system.add_modifier(
		"marble_chain",
		StatModifierScript.new("packet_mult", "damage_multiplier", StatModifier.ModOp.OVERRIDE, 1.5, "packet_test")
	)

	enemy.apply_damage_packet(DamagePacket.new(&"marble_head", 5.0))
	assert_eq(enemy.health, 92, "round(5 * 1.5) then armor")
	enemy.apply_damage_packet(DamagePacket.new(&"untyped", 5.0))
	assert_eq(enemy.health, 87, "untyped compatibility packet must not consume damage_multiplier")
	stat_system.remove_modifiers_by_source("marble_chain", "packet_test")


func test_damage_and_death_hooks_share_the_resolved_packet_in_order() -> void:
	var recorder := RecordingEffect.new()
	_effect_manager.set("_active_effects", {&"recording": recorder})
	var enemy: Enemy = _enemy()
	var order: Array[StringName] = recorder.order
	enemy.defeated.connect(func(_defeated_enemy: Enemy, _cause: StringName) -> void:
		order.append(&"defeated")
	)

	var packet := DamagePacket.new(&"untyped", 100.0)
	packet.generation = 4
	enemy.apply_damage_packet(packet)

	assert_eq(order, [&"damage", &"defeated", &"enemy_defeated"])
	assert_eq(recorder.packets.size(), 2)
	assert_eq(recorder.packets[0], packet)
	assert_eq(recorder.packets[1], packet)
	assert_eq(packet.final_amount, 100)
	assert_eq(packet.generation, 4)


func _enemy() -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	return enemy
