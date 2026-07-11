extends GutTest

const BuffHostScript: GDScript = preload("res://Buffs/buff_host.gd")
const FireDebuffScript: GDScript = preload("res://Buffs/buffs/fire_burn_debuff.gd")
const FireMarbleScript: GDScript = preload("res://Marbles/fire_marble.gd")
const FloatDamageTextPoolScript: GDScript = preload("res://UI/float_damage_text_pool.gd")
const BurnFloatingTextScene: PackedScene = preload("res://UI/burn_floating_text.tscn")
const EnemyScene: PackedScene = preload("res://Enemies/enemy.tscn")
const MarbleChainScript: GDScript = preload("res://Marbles/marble_chain.gd")
const ChainSegmentScene: PackedScene = preload("res://Marbles/chain_segment.tscn")
const MarbleUpgradeSystemScript: GDScript = preload("res://Run/marble_upgrade_system.gd")
const DefaultBattleRewardConfig: Resource = preload("res://Run/default_battle_reward_config.tres")


class DummyEnemy extends Node2D:
	var damage_events: Array[int] = []
	var received_buffs: Array[BuffDef] = []
	var alive: bool = true

	func take_damage(amount: int, _flash_color: Color = Color.WHITE, _floating_style: StringName = &"default") -> void:
		damage_events.append(amount)

	func add_buff(buff: BuffDef, _stacks: int = 1) -> void:
		received_buffs.append(buff)

	func is_alive() -> bool:
		return alive


class DummyInventory extends Node:
	var marble_items: Array[Item] = []


func test_burn_ticks_decrease_from_three_to_one() -> void:
	var enemy := DummyEnemy.new()
	var burn: BuffDef = FireDebuffScript.new()
	var state: Dictionary = {}
	burn.on_apply(enemy, state)
	burn.on_process(enemy, state, 1.0)
	burn.on_process(enemy, state, 1.0)
	burn.on_process(enemy, state, 1.0)
	assert_eq(enemy.damage_events, [3, 2, 1])
	enemy.free()


func test_reapplying_burn_keeps_original_remaining_time() -> void:
	var enemy := DummyEnemy.new()
	add_child_autofree(enemy)
	var host: BuffHost = BuffHostScript.new()
	enemy.add_child(host)
	var burn: BuffDef = FireDebuffScript.new()
	host.add_buff(burn)
	host._process(1.0)
	var remaining_before: float = host.get_buff_remaining_time("fire_burn_debuff")
	host.add_buff(FireDebuffScript.new())
	assert_eq(host.get_buff_remaining_time("fire_burn_debuff"), remaining_before)


func test_burn_duration_stat_supports_four_and_five_ticks() -> void:
	var enemy := DummyEnemy.new()
	var burn: BuffDef = FireDebuffScript.new()
	var state: Dictionary = {"pending_ticks": 4, "tick_accumulator": 0.0}
	for _index: int in range(4):
		burn.on_process(enemy, state, 1.0)
	assert_eq(enemy.damage_events, [4, 3, 2, 1])
	enemy.damage_events.clear()
	state = {"pending_ticks": 5, "tick_accumulator": 0.0}
	for _index: int in range(5):
		burn.on_process(enemy, state, 1.0)
	assert_eq(enemy.damage_events, [5, 4, 3, 2, 1])
	enemy.free()


func test_fire_marble_applies_burn_on_hit() -> void:
	var enemy := DummyEnemy.new()
	FireMarbleScript.apply_burn_to_enemy(enemy)
	assert_eq(enemy.received_buffs.size(), 1)
	assert_eq(enemy.received_buffs[0].id, "fire_burn_debuff")
	enemy.free()


func test_fire_chain_segment_applies_burn_and_keeps_contact_damage() -> void:
	var target := DummyEnemy.new()
	var chain: MarbleChain = MarbleChainScript.new()
	var segment: ChainSegment = ChainSegmentScene.instantiate() as ChainSegment
	segment.segment_type = Marble.MARBLE_TYPE.FIRE
	segment.damage = 1
	chain.body.append(segment)
	var contact_damage: int = chain.get_total_damage(target)
	assert_eq(target.received_buffs.size(), 1)
	assert_eq(contact_damage, 1)
	segment.free()
	chain.free()
	target.free()


func test_fire_reward_and_upgrade_options_expose_four_and_five_second_burn() -> void:
	assert_has(DefaultBattleRewardConfig.marble_item_paths, "res://Resources/fire_marble.tres")
	var inventory := DummyInventory.new()
	inventory.marble_items.append(load("res://Resources/fire_marble.tres") as Item)
	var upgrades: MarbleUpgradeSystem = MarbleUpgradeSystemScript.new()
	var first_option: Dictionary = upgrades.get_upgrade_options(inventory, 1)[0]
	assert_eq(first_option.description, "UPGRADE_FIRE_DURATION_4_DESC")
	upgrades.upgrade_marble(Marble.MARBLE_TYPE.FIRE)
	var second_option: Dictionary = upgrades.get_upgrade_options(inventory, 1)[0]
	assert_eq(second_option.description, "UPGRADE_FIRE_DURATION_5_DESC")
	inventory.free()
	upgrades.free()


func test_burn_damage_uses_red_floating_text_scene() -> void:
	var pool: Node = FloatDamageTextPoolScript.new()
	pool.burn_floating_text_scene = BurnFloatingTextScene
	add_child_autofree(pool)
	var text: Node2D = pool.show_damage(3, Vector2.ZERO, &"burn")
	assert_eq(text.get_node("Label").get_theme_color("font_color"), Color(1.0, 0.2, 0.15, 1.0))


func test_death_propagates_pending_ticks_to_nearest_unburned_enemy() -> void:
	var source := DummyEnemy.new()
	var destination := DummyEnemy.new()
	var farther := DummyEnemy.new()
	source.global_position = Vector2.ZERO
	destination.global_position = Vector2(10, 0)
	farther.global_position = Vector2(20, 0)
	for enemy: DummyEnemy in [source, destination, farther]:
		enemy.add_to_group("enemies")
		add_child_autofree(enemy)
	var host: BuffHost = BuffHostScript.new()
	source.add_child(host)
	var burn: BuffDef = FireDebuffScript.new()
	burn.params["ember_spread_enabled"] = true
	burn.params["pending_ticks"] = 3
	host.add_buff(burn)
	host.notify_host_death()
	assert_eq(destination.received_buffs.size(), 1)
	assert_eq(destination.received_buffs[0].params.get("pending_ticks"), 3)
	assert_eq(farther.received_buffs.size(), 0)


func test_real_enemy_death_spreads_burn_to_nearest_enemy() -> void:
	var source: Node = EnemyScene.instantiate()
	var target: Node = EnemyScene.instantiate()
	source.global_position = Vector2.ZERO
	target.global_position = Vector2(10.0, 0.0)
	add_child_autofree(source)
	add_child_autofree(target)
	await get_tree().process_frame

	var burn: BuffDef = FireDebuffScript.new()
	burn.params["ember_spread_enabled"] = true
	source.call("add_buff", burn)
	source.call("take_damage", 100)
	await get_tree().process_frame

	assert_true(bool(target.call("has_buff", "fire_burn_debuff")))


func test_death_propagation_appends_and_caps_existing_burn_at_ten_ticks() -> void:
	var enemy := DummyEnemy.new()
	add_child_autofree(enemy)
	var host: BuffHost = BuffHostScript.new()
	enemy.add_child(host)
	var burn: BuffDef = FireDebuffScript.new()
	host.add_buff(burn)
	host.append_buff_duration("fire_burn_debuff", 20.0, 10.0)
	assert_eq(host.get_buff_pending_ticks("fire_burn_debuff"), 10)
