extends GutTest

## End-to-end core loop on the real enemy.tscn: with an assassin weak point present, a
## marble hitting from the marked side crits (x2 + crit float style + base source),
## the opposite side does not, and a crit relocates the weak point.

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")

const TEST_SOURCE: String = "assassin_it_test"


class FakeMarble:
	extends Node2D
	var hit_damage: int = 10

	func get_hit_damage(_target: Node, _packet: DamagePacket = null) -> int:
		return hit_damage


class RecordingEffect:
	extends RefCounted
	var last_packet: DamagePacket = null

	func on_damage_dealt(_enemy: Node2D, packet: DamagePacket) -> void:
		last_packet = packet


var _effect_manager: Node
var _stat_system: Node


func before_each() -> void:
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	_effect_manager.set("_active_effects", {})
	_stat_system = get_node_or_null("/root/StatSystem")
	assert_not_null(_stat_system)


func after_each() -> void:
	if _effect_manager != null and is_instance_valid(_effect_manager):
		_effect_manager.set("_active_effects", {})
	if _stat_system != null and is_instance_valid(_stat_system):
		_stat_system.remove_modifiers_by_source("marble_chain", TEST_SOURCE)


func _set_assassin_count(count: int) -> void:
	_stat_system.add_modifier(
		"marble_chain",
		StatModifier.new(
			"%s:count" % TEST_SOURCE, "assassin_weak_point_count",
			StatModifier.ModOp.OVERRIDE, float(count), TEST_SOURCE
		)
	)


func _lock_damage_multiplier_one() -> void:
	_stat_system.add_modifier(
		"marble_chain",
		StatModifier.new(
			"%s:mult" % TEST_SOURCE, "damage_multiplier",
			StatModifier.ModOp.OVERRIDE, 1.0, TEST_SOURCE
		)
	)


func _spawn_enemy_with_assassin() -> Enemy:
	_lock_damage_multiplier_one()
	_set_assassin_count(1)
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	enemy.global_position = Vector2(200, 200)
	return enemy


func _host_of(enemy: Enemy) -> WeakPointHost:
	return enemy.get_node("WeakPointHost") as WeakPointHost


func _weak_point_direction(enemy: Enemy) -> int:
	var host: WeakPointHost = _host_of(enemy)
	assert_eq(host.weak_points.size(), 1, "one base weak point expected")
	return int((host.weak_points[0] as WeakPoint).direction)


func _direction_vector(direction: int) -> Vector2:
	var angle_deg: float = float(WeakPoint.CENTER_ANGLE_DEG[direction])
	return Vector2.RIGHT.rotated(deg_to_rad(angle_deg))


func _marble_at(enemy: Enemy, offset: Vector2) -> Node2D:
	var marble := FakeMarble.new()
	add_child_autofree(marble)
	marble.add_to_group("marbles")
	marble.global_position = enemy.global_position + offset
	return marble


func _install_recorder() -> RecordingEffect:
	var recorder := RecordingEffect.new()
	_effect_manager.set("_active_effects", {&"recording": recorder})
	return recorder


func test_no_assassin_means_no_weak_point_and_no_crit() -> void:
	_lock_damage_multiplier_one()
	_set_assassin_count(0)
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	add_child_autofree(enemy)
	enemy.global_position = Vector2(200, 200)
	assert_eq(_host_of(enemy).weak_points.size(), 0, "no assassin -> no weak points")

	var recorder := _install_recorder()
	var marble := _marble_at(enemy, Vector2(24, 0))
	enemy._on_body_entered(marble)
	assert_not_null(recorder.last_packet)
	assert_false(recorder.last_packet.is_crit)


func test_assassin_present_reveals_one_weak_point() -> void:
	var enemy := _spawn_enemy_with_assassin()
	var host: WeakPointHost = _host_of(enemy)
	assert_eq(host.weak_points.size(), 1)
	assert_eq((host.weak_points[0] as WeakPoint).kind, WeakPoint.Kind.BASE)


func test_hit_from_marked_side_crits() -> void:
	var enemy := _spawn_enemy_with_assassin()
	var direction := _weak_point_direction(enemy)
	var recorder := _install_recorder()

	var marble := _marble_at(enemy, _direction_vector(direction) * 24.0)
	enemy._on_body_entered(marble)

	assert_not_null(recorder.last_packet)
	assert_true(recorder.last_packet.is_crit)
	assert_eq(recorder.last_packet.crit_multiplier, 2.0)
	assert_eq(recorder.last_packet.crit_source, &"weak_point_base")
	assert_eq(recorder.last_packet.floating_style, &"crit")
	# base 10 x damage_multiplier 1.0 = 10, crit x2 = 20.
	assert_eq(recorder.last_packet.final_amount, 20)
	assert_eq(enemy.health, 80)


func test_hit_from_wrong_side_does_not_crit() -> void:
	var enemy := _spawn_enemy_with_assassin()
	var direction := _weak_point_direction(enemy)
	var recorder := _install_recorder()

	var perpendicular := _direction_vector(direction).rotated(deg_to_rad(90.0))
	var marble := _marble_at(enemy, perpendicular * 24.0)
	enemy._on_body_entered(marble)

	assert_not_null(recorder.last_packet)
	assert_false(recorder.last_packet.is_crit)
	assert_eq(recorder.last_packet.floating_style, &"default")
	assert_eq(recorder.last_packet.final_amount, 10)
	assert_eq(enemy.health, 90)


func test_crit_relocates_weak_point_away_from_hit_side() -> void:
	var enemy := _spawn_enemy_with_assassin()
	var before := _weak_point_direction(enemy)
	_install_recorder()

	var marble := _marble_at(enemy, _direction_vector(before) * 24.0)
	enemy._on_body_entered(marble)

	var after := _weak_point_direction(enemy)
	assert_ne(after, before, "weak point must move off the side that was just critted")
