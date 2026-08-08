extends GutTest

## 导火索爆炸结算：倒计时结束走 ExplosionContext 事务管线——modify_explosion
## 分发一次、RadialDamage 以 base_damage 造伤、on_explosion 分发一次、
## 【不扣弹药】【跳过 on_explosion_resolved】；ammo_before 读真实弹药快照。

const BombScene: PackedScene = preload("res://Combat/skills/DemolitionCharge/demolition_charge_bomb.tscn")
const Definition: Resource = preload("res://Combat/skills/DemolitionCharge/demolition_charge_skill_definition.tres")
const AmmoStateScript: GDScript = preload("res://Combat/ammo/ammo_state.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")
const ExplosionContextScript: GDScript = preload("res://Combat/explosion/explosion_context.gd")


class DamageableEnemy extends Node2D:
	var packets: Array[DamagePacket] = []

	func apply_damage_packet(packet: DamagePacket) -> void:
		packets.append(packet)


class FakeLifecycle extends Node:
	signal battle_started(token, plan)


class FakeEffectManager extends Node:
	var modify_calls: int = 0
	var on_explosion_calls: int = 0
	var on_explosion_resolved_calls: int = 0
	var last_context: ExplosionContext = null

	func modify_explosion(context: ExplosionContext) -> void:
		modify_calls += 1
		last_context = context

	func on_explosion(_center: Vector2, _radius: float) -> void:
		on_explosion_calls += 1

	func on_explosion_resolved(_context: ExplosionContext) -> void:
		on_explosion_resolved_calls += 1


func after_each() -> void:
	Engine.time_scale = 1.0


func _ammo_with(count: int) -> Node:
	var stats: Node = autofree(FakeStatSystemScript.new())
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.configure(stats, autofree(FakeLifecycle.new()))
	ammo.consume(ammo.get_ammo() - count)
	return ammo


func _definition_with() -> SkillDefinition:
	var def: SkillDefinition = (Definition as SkillDefinition).duplicate()
	def.base_damage = 12
	def.blast_radius = 70.0
	def.fuse_time = 0.3
	def.flight_duration = 0.1
	return def


func _armed_bomb(ammo: Node, effect_manager: Node) -> DemolitionChargeBomb:
	var parent := Node2D.new()
	add_child_autofree(parent)
	var bomb: DemolitionChargeBomb = BombScene.instantiate() as DemolitionChargeBomb
	parent.add_child(bomb)
	bomb.global_position = Vector2(60, 60)
	bomb.set_ammo_state(ammo)
	if effect_manager != null:
		bomb._effect_manager = effect_manager
	var def: SkillDefinition = _definition_with()
	bomb.launch(Vector2(60, 60), def)
	return bomb


func test_fuse_explodes_damages_enemy_without_consuming_ammo() -> void:
	var ammo := _ammo_with(5)
	var fake_effect := FakeEffectManager.new()
	add_child_autofree(fake_effect)
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.add_to_group(&"enemies")
	enemy.global_position = Vector2(60, 60)

	var bomb: DemolitionChargeBomb = _armed_bomb(ammo, fake_effect)
	await wait_seconds(0.5)

	assert_eq(enemy.packets.size(), 1, "导火索结束爆炸命中敌人")
	assert_eq(int(enemy.packets[0].base), 12, "伤害 = 技能 base_damage")
	assert_true(enemy.packets[0].is_skill, "packet 标记 is_skill")
	assert_true(enemy.packets[0].is_marble, "保持 is_marble 语义")
	assert_false(enemy.packets[0].is_relic, "非遗物爆炸")
	assert_eq(ammo.get_ammo(), 5, "技能不吃弹药：扣弹前/后都是 5")
	assert_eq(fake_effect.modify_calls, 1, "modify_explosion 分发一次（背水/倾泻可用）")
	assert_eq(fake_effect.on_explosion_calls, 1, "on_explosion 分发一次（VFX 同步）")
	assert_eq(fake_effect.on_explosion_resolved_calls, 0, "跳过 on_explosion_resolved（高爆/回收器不触发）")
	assert_eq(fake_effect.last_context.ammo_before, 5, "ammo_before 读真实弹药快照")
	assert_false(is_instance_valid(bomb), "爆炸后销毁")


func test_zero_ammo_still_explodes_with_skill_damage() -> void:
	# 技能不吃弹药：0 弹药也照常爆炸（与炸弹弹珠的"0 弹药不炸"相反）。
	var ammo := _ammo_with(0)
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.add_to_group(&"enemies")
	enemy.global_position = Vector2(60, 60)

	var bomb: DemolitionChargeBomb = _armed_bomb(ammo, null)
	await wait_seconds(0.5)

	assert_eq(enemy.packets.size(), 1, "0 弹药仍爆炸")
	assert_eq(int(enemy.packets[0].base), 12, "伤害 = 技能 base_damage")
	assert_eq(ammo.get_ammo(), 0, "弹药保持 0，不扣不减")


func test_bomb_uses_real_effect_manager_when_none_injected() -> void:
	# 不注入假 EffectManager：走真实 autoload（无遗物时 dispatch 为空操作）。
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.add_to_group(&"enemies")
	enemy.global_position = Vector2(60, 60)

	var bomb: DemolitionChargeBomb = _armed_bomb(null, null)
	await wait_seconds(0.5)

	assert_eq(enemy.packets.size(), 1, "真实 EffectManager 下照常爆炸")
	assert_eq(int(enemy.packets[0].base), 12)
	assert_true(enemy.packets[0].is_skill)
