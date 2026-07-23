extends GutTest

const EnemyScript: GDScript = preload("res://Combat/battle/enemies/enemy.gd")
const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")


func _packet(source: StringName, element: StringName, style: StringName = &"default") -> DamagePacket:
	var packet: DamagePacket = DamagePacketScript.new(source, 1.0, element)
	packet.floating_style = style
	return packet


func test_element_packets_map_to_element_styles() -> void:
	assert_eq(EnemyScript.resolve_floating_style(_packet(&"dot_poison", &"poison")), &"poison")
	assert_eq(EnemyScript.resolve_floating_style(_packet(&"relic_ice", &"frost")), &"frost")
	assert_eq(EnemyScript.resolve_floating_style(_packet(&"relic_lightning", &"lightning")), &"lightning")
	assert_eq(EnemyScript.resolve_floating_style(_packet(&"relic_thermal_shock", &"fire")), &"burn")


func test_bomb_source_maps_to_explosion_style() -> void:
	assert_eq(EnemyScript.resolve_floating_style(_packet(&"bomb", &"physical")), &"explosion")


func test_plain_physical_damage_stays_default() -> void:
	assert_eq(EnemyScript.resolve_floating_style(_packet(&"marble_head", &"physical")), &"default")


func test_explicit_style_wins_over_element_mapping() -> void:
	assert_eq(EnemyScript.resolve_floating_style(_packet(&"relic_ice", &"frost", &"crit")), &"crit")
	assert_eq(EnemyScript.resolve_floating_style(_packet(&"dot_burn", &"fire", &"burn")), &"burn")
	assert_eq(EnemyScript.resolve_floating_style(_packet(&"weak_point_prism", &"physical", &"perfect")), &"perfect")
