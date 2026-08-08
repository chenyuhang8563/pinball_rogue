extends GutTest

## 数值联动：技能享受炸弹 stat 加成——explosion_radius 超过基线 75 的增量并入
## 技能半径（放大大范围）；不吃 explosion_damage（伤害用技能自带 base_damage）；
## modify_explosion 类数值遗物（背水/倾泻）改写伤害/半径；packet.is_skill=true。

const BombScene: PackedScene = preload("res://Combat/skills/DemolitionCharge/demolition_charge_bomb.tscn")
const Definition: Resource = preload("res://Combat/skills/DemolitionCharge/demolition_charge_skill_definition.tres")
const StatModifierScript: GDScript = preload("res://Core/stats/stat_modifier.gd")
const ExplosionContextScript: GDScript = preload("res://Combat/explosion/explosion_context.gd")

const TEST_SOURCE: String = "dc_relic_test"


class DamageableEnemy extends Node2D:
	var packets: Array[DamagePacket] = []

	func apply_damage_packet(packet: DamagePacket) -> void:
		packets.append(packet)


## 数值类 modify_explosion 遗物替身：+3 伤害、×2 半径（背水/倾泻同构）。
class FlatAndRadiusEffectManager extends Node:
	func modify_explosion(context: ExplosionContext) -> void:
		context.add_flat_damage(3)
		context.multiply_radius(2.0)


func before_each() -> void:
	Engine.time_scale = 1.0


func after_each() -> void:
	Engine.time_scale = 1.0
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	if stat_system != null and stat_system.has_method("remove_modifiers_by_source"):
		stat_system.call("remove_modifiers_by_source", "marble_chain", TEST_SOURCE)


func _definition_with() -> SkillDefinition:
	var def: SkillDefinition = (Definition as SkillDefinition).duplicate()
	def.base_damage = 12
	def.blast_radius = 70.0
	def.fuse_time = 0.3
	def.flight_duration = 0.1
	return def


func _bomb_in_tree(effect_manager: Node = null) -> DemolitionChargeBomb:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var bomb: DemolitionChargeBomb = BombScene.instantiate() as DemolitionChargeBomb
	parent.add_child(bomb)
	bomb.global_position = Vector2(60, 60)
	if effect_manager != null:
		bomb._effect_manager = effect_manager
	var def: SkillDefinition = _definition_with()
	bomb.launch(Vector2(60, 60), def)
	return bomb


func test_radius_stat_bonus_expands_blast_without_touching_damage_stat() -> void:
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	assert_not_null(stat_system, "StatSystem autoload 存在")
	# explosion_radius：基线 75 → 90（+15 增量并入技能半径）。
	stat_system.call("add_modifier", "marble_chain",
		StatModifierScript.new(TEST_SOURCE, "explosion_radius", StatModifierScript.ModOp.ADD, 15.0, TEST_SOURCE))
	# explosion_damage：推到 99 —— 技能应不吃（伤害 = 自带 base_damage）。
	stat_system.call("add_modifier", "marble_chain",
		StatModifierScript.new(TEST_SOURCE, "explosion_damage", StatModifierScript.ModOp.ADD, 95.0, TEST_SOURCE))

	var near_enemy := DamageableEnemy.new()
	add_child_autofree(near_enemy)
	near_enemy.add_to_group(&"enemies")
	near_enemy.global_position = Vector2(60, 60)
	# 80px 处：基础半径 70 打不到；并入 +15 后半径 85 打得到。
	var far_enemy := DamageableEnemy.new()
	add_child_autofree(far_enemy)
	far_enemy.add_to_group(&"enemies")
	far_enemy.global_position = Vector2(60 + 80, 60)

	_bomb_in_tree(null)
	await wait_seconds(0.5)

	assert_eq(int(near_enemy.packets[0].base), 12, "不吃 explosion_damage stat（仍是技能 base_damage）")
	assert_true(near_enemy.packets[0].is_skill, "packet 标记 is_skill")
	assert_eq(far_enemy.packets.size(), 1, "explosion_radius 增量并入技能半径 → 80px 敌人被打中")


func test_modify_explosion_relic_shapes_damage_and_radius() -> void:
	var effect_manager := FlatAndRadiusEffectManager.new()
	add_child_autofree(effect_manager)
	var near_enemy := DamageableEnemy.new()
	add_child_autofree(near_enemy)
	near_enemy.add_to_group(&"enemies")
	near_enemy.global_position = Vector2(60, 60)
	# 130px 处：×2 半径 = 140 打得到；基础半径 70 打不到。
	var far_enemy := DamageableEnemy.new()
	add_child_autofree(far_enemy)
	far_enemy.add_to_group(&"enemies")
	far_enemy.global_position = Vector2(60 + 130, 60)

	_bomb_in_tree(effect_manager)
	await wait_seconds(0.5)

	assert_eq(int(near_enemy.packets[0].base), 15, "add_flat_damage(3) → 12 + 3 = 15")
	assert_true(near_enemy.packets[0].is_skill)
	assert_eq(far_enemy.packets.size(), 1, "multiply_radius(2.0) → 70×2=140，130px 敌人被打中")
