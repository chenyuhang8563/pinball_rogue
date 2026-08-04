extends GutTest

## 炸弹爆炸流水线：弹药扣减、0 弹药停爆与 1 伤兜底、基础 4 伤、
## resolved 参数驱动伤害/半径、event_id 共享、删除中敌人排除、
## ExplosionContext 固定组合层。

const MarbleChainScript: GDScript = preload("res://Combat/marbles/marble_chain.gd")
const AmmoStateScript: GDScript = preload("res://Combat/ammo/ammo_state.gd")
const ExplosionContextScript: GDScript = preload("res://Combat/explosion/explosion_context.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")


class DamageableEnemy extends Node2D:
	var packets: Array[DamagePacket] = []
	var take_damage_calls: int = 0


	func apply_damage_packet(packet: DamagePacket) -> void:
		packets.append(packet)


	func take_damage(_amount: int) -> void:
		take_damage_calls += 1


class FakeLifecycle extends Node:
	signal battle_started(token, plan)


func _chain_with_bomb(ammo: Node) -> MarbleChain:
	var chain: MarbleChain = MarbleChainScript.new()
	add_child_autofree(chain)
	var bomb := _marble("only_bomb", Marble.MARBLE_TYPE.BOMB)
	chain.build_chain([bomb], [Vector2(56, 96)])
	chain.set_ammo_state(ammo)
	return chain


func _ammo_with(count: int) -> Node:
	var stats: Node = autofree(FakeStatSystemScript.new())
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.configure(stats, FakeLifecycle.new())
	ammo.consume(ammo.get_ammo() - count)
	return ammo


func _marble(id: String, marble_type: Marble.MARBLE_TYPE) -> Item:
	var item := Item.new()
	item.id = id
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	if marble_type == Marble.MARBLE_TYPE.BOMB:
		item.marble_segment_damage = 0
	return item


func test_explosion_consumes_one_ammo_and_deals_base_four_damage() -> void:
	var ammo := _ammo_with(5)
	var chain := _chain_with_bomb(ammo)
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.global_position = chain.get("head").global_position
	enemy.add_to_group("enemies")

	chain.call("_on_head_body_entered", enemy)

	assert_eq(ammo.get_ammo(), 4, "爆炸消耗 1 发")
	assert_eq(enemy.packets.size(), 1)
	assert_eq(int(enemy.packets[0].base), 4, "基础爆炸伤害 4")
	assert_true(enemy.packets[0].is_marble)


func test_zero_ammo_does_not_explode_no_vfx_no_damage() -> void:
	var ammo := _ammo_with(0)
	var chain := _chain_with_bomb(ammo)
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.global_position = chain.get("head").global_position
	enemy.add_to_group("enemies")
	# 爆炸流水线未进入：_try_trigger_bomb 直接返回 false，_execute_explosion
	# （含 VFX 生成）根本不会执行；GUT 中 current_scene 为 null，_spawn_explosion_effect
	# 也有 null 保护，因此 VFX 在本测试环境不可观察，由 exploded==false 证明。

	var exploded: bool = bool(chain.call("_try_trigger_bomb"))

	assert_false(exploded, "0 弹药不爆炸")
	assert_eq(enemy.packets.size(), 0, "无爆炸伤害")
	assert_eq(enemy.take_damage_calls, 0)
	assert_eq(ammo.get_ammo(), 0, "弹药不变化")


func test_dry_bomb_contact_damage_is_one_at_zero_ammo_only_for_enemies() -> void:
	var ammo := _ammo_with(0)
	var chain := _chain_with_bomb(ammo)
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.add_to_group("enemies")
	var wall := StaticBody2D.new()
	add_child_autofree(wall)
	var packet := DamagePacket.new(&"marble_head", 0.0)

	assert_eq(chain.get_total_damage(enemy, packet), 1, "0 弹药普通碰撞补 1 伤")
	assert_true(packet.metadata.get("dry_bomb", false), "packet 打 dry_bomb 标记")
	assert_eq(chain.get_total_damage(enemy), 1, "每次碰撞都补 1 伤（非一次性）")
	assert_eq(chain.get_total_damage(wall), 0, "非敌目标不补")


func test_dry_bomb_only_once_with_multiple_bomb_segments() -> void:
	var ammo := _ammo_with(0)
	var chain: MarbleChain = MarbleChainScript.new()
	add_child_autofree(chain)
	chain.build_chain([
		_marble("head_bomb", Marble.MARBLE_TYPE.BOMB),
		_marble("body_bomb", Marble.MARBLE_TYPE.BOMB),
	], [Vector2(56, 96), Vector2(56, 72)])
	chain.set_ammo_state(ammo)
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.add_to_group("enemies")

	assert_eq(chain.get_total_damage(enemy), 1, "多个炸弹段也只补 1 次")


func test_ammo_above_zero_uses_explosion_not_dry_damage() -> void:
	var ammo := _ammo_with(3)
	var chain := _chain_with_bomb(ammo)
	var enemy := DamageableEnemy.new()
	add_child_autofree(enemy)
	enemy.add_to_group("enemies")

	assert_eq(chain.get_total_damage(enemy), 0, "弹药>0 时碰撞伤害由爆炸负责")


func test_resolved_radius_filters_targets() -> void:
	var ammo := _ammo_with(5)
	var chain := _chain_with_bomb(ammo)
	var near_enemy := DamageableEnemy.new()
	var far_enemy := DamageableEnemy.new()
	add_child_autofree(near_enemy)
	add_child_autofree(far_enemy)
	near_enemy.global_position = chain.get("head").global_position
	far_enemy.global_position = chain.get("head").global_position + Vector2(120, 0)
	near_enemy.add_to_group("enemies")
	far_enemy.add_to_group("enemies")

	chain.call("_on_head_body_entered", near_enemy)

	assert_eq(near_enemy.packets.size(), 1, "半径内目标受伤")
	assert_eq(far_enemy.packets.size(), 0, "半径外目标不受伤")


func test_all_targets_share_one_event_id_with_main_target() -> void:
	var ammo := _ammo_with(5)
	var chain := _chain_with_bomb(ammo)
	var first := DamageableEnemy.new()
	var second := DamageableEnemy.new()
	add_child_autofree(first)
	add_child_autofree(second)
	var center: Vector2 = chain.get("head").global_position
	first.global_position = center
	second.global_position = center + Vector2(10, 0)
	first.add_to_group("enemies")
	second.add_to_group("enemies")

	chain.call("_on_head_body_entered", first)

	assert_eq(first.packets.size(), 1)
	assert_eq(second.packets.size(), 1)
	assert_eq(first.packets[0].event_id, second.packets[0].event_id, "同一次爆炸共享 event_id")
	assert_true(first.packets[0].is_event_main, "最近目标为主目标")


func test_queued_for_deletion_enemies_are_excluded() -> void:
	var ammo := _ammo_with(5)
	var chain := _chain_with_bomb(ammo)
	var doomed := DamageableEnemy.new()
	var alive := DamageableEnemy.new()
	add_child_autofree(doomed)
	add_child_autofree(alive)
	doomed.global_position = chain.get("head").global_position
	alive.global_position = chain.get("head").global_position
	doomed.add_to_group("enemies")
	alive.add_to_group("enemies")
	doomed.queue_free()

	chain.call("_on_head_body_entered", alive)

	assert_eq(alive.packets.size(), 1, "存活敌人正常受伤")
	assert_eq(doomed.packets.size(), 0, "已排入删除的敌人被排除")


func test_context_finalize_fixed_composition_layers() -> void:
	var ctx: ExplosionContext = ExplosionContextScript.new() as ExplosionContext
	ctx.base_damage = 4
	ctx.base_radius = 75.0
	ctx.ammo_before = 3
	ctx.request_extra_ammo(1)
	ctx.add_flat_damage(3)
	ctx.multiply_damage(1.5)
	ctx.multiply_radius(2.0)
	var resolved: Dictionary = ctx.finalize()

	assert_eq(int(resolved["damage"]), 11, "base + flat：(4 + 3) × 1.5 = 10.5 → 11")
	assert_eq(float(resolved["radius"]), 150.0)
	assert_eq(int(resolved["ammo_cost"]), 2, "min(ammo_before, 1 + extra)")


func test_context_finalize_is_idempotent() -> void:
	var ctx: ExplosionContext = ExplosionContextScript.new() as ExplosionContext
	ctx.base_damage = 4
	ctx.base_radius = 75.0
	ctx.ammo_before = 4
	var first_resolved: Dictionary = ctx.finalize()
	ctx.add_flat_damage(99)
	var second_resolved: Dictionary = ctx.finalize()

	assert_eq(first_resolved, second_resolved, "finalize 只结算一次")
