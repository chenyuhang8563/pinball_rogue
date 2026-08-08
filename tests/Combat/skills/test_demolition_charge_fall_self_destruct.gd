extends GutTest

## 掉出台自毁：炸弹落地后若位于 TableBase/KillZone 判定范围（contained），
## 立即销毁【不爆炸】——范围内敌人不受伤、不产生爆炸（不构造 ExplosionContext）。

const BombScene: PackedScene = preload("res://Combat/skills/DemolitionCharge/demolition_charge_bomb.tscn")
const Definition: Resource = preload("res://Combat/skills/DemolitionCharge/demolition_charge_skill_definition.tres")


class FakeKillZone extends Node:
	var contained: bool = true

	func contains_global_point(_point: Vector2) -> bool:
		return contained


class DamageableEnemy extends Node2D:
	var packets: Array[DamagePacket] = []

	func apply_damage_packet(packet: DamagePacket) -> void:
		packets.append(packet)


func after_each() -> void:
	Engine.time_scale = 1.0


func _definition_with() -> SkillDefinition:
	var def: SkillDefinition = (Definition as SkillDefinition).duplicate()
	def.base_damage = 12
	def.blast_radius = 70.0
	def.fuse_time = 5.0
	def.flight_duration = 0.15
	return def


func _table_with_kill_zone() -> Node2D:
	var table := Node2D.new()
	add_child_autofree(table)
	var table_base := Node2D.new()
	table_base.name = "TableBase"
	table.add_child(table_base)
	var kill_zone := FakeKillZone.new()
	kill_zone.name = "KillZone"
	table_base.add_child(kill_zone)
	return table


func test_kill_zone_contained_self_destructs_without_damage() -> void:
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.add_to_group(&"enemies")
	enemy.global_position = Vector2(60, 60)

	var table: Node2D = _table_with_kill_zone()
	var bomb: DemolitionChargeBomb = BombScene.instantiate() as DemolitionChargeBomb
	table.add_child(bomb)
	bomb.global_position = Vector2(60, 60)

	var def: SkillDefinition = _definition_with()
	bomb.launch(Vector2(60, 60), def)

	await wait_seconds(def.flight_duration + 0.05)
	await wait_physics_frames(2)

	assert_false(is_instance_valid(bomb), "掉出台自毁销毁（不爆炸）")
	assert_eq(enemy.packets.size(), 0, "范围内敌人不受伤害——未爆炸")


func test_kill_zone_outside_keeps_bomb_alive() -> void:
	var table: Node2D = _table_with_kill_zone()
	var kill_zone: FakeKillZone = (table.get_node("TableBase/KillZone") as FakeKillZone)
	kill_zone.contained = false

	var bomb: DemolitionChargeBomb = BombScene.instantiate() as DemolitionChargeBomb
	table.add_child(bomb)
	bomb.global_position = Vector2(60, 60)

	var def: SkillDefinition = _definition_with()
	bomb.launch(Vector2(60, 60), def)

	await wait_seconds(def.flight_duration + 0.05)
	await wait_physics_frames(2)

	assert_true(is_instance_valid(bomb), "不在 KillZone 判定范围则不销毁")
	assert_true(bool(bomb.get("_landed")), "仍保持落地状态")
