extends GutTest

const BuffHostScript: GDScript = preload("res://Buffs/buff_host.gd")
const FireDebuffScript: GDScript = preload("res://Buffs/buffs/fire_burn_debuff.gd")
const FireMarbleScript: GDScript = preload("res://Marbles/fire_marble.gd")
const FloatDamageTextPoolScript: GDScript = preload("res://UI/float_damage_text_pool.gd")
const BurnFloatingTextScene: PackedScene = preload("res://UI/burn_floating_text.tscn")
const EnemyScene: PackedScene = preload("res://Enemies/enemy.tscn")
const MarbleChainScript: GDScript = preload("res://Marbles/marble_chain.gd")
const ChainSegmentScene: PackedScene = preload("res://Marbles/chain_segment.tscn")

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


class FireDurationStatSystem extends Node:
	func get_stat(stat_id: String, _entity_id: String, _context: Variant = null) -> float:
		return 5.0 if stat_id == "fire_burn_duration" else 0.0


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


# 回归来源：觉醒火焰弹珠只结算 5、4、3，Buff 在固定 3 秒后提前移除。
# 修复目标：Buff 的实际时长与升级后的 5 次燃烧结算一致，覆盖最后的 2、1 伤害边界。
# 首次 tick 在碰撞瞬间由 on_apply 立即结算，后续 4 次 tick 在每秒开始时结算。
func test_awakened_burn_lasts_five_seconds_and_deals_all_five_ticks() -> void:
	var root := get_tree().root
	var previous_stat_system := root.get_node_or_null("StatSystem")
	if previous_stat_system != null:
		previous_stat_system.name = "PreviousStatSystemForFireDurationTest"
	var stat_system := FireDurationStatSystem.new()
	stat_system.name = "StatSystem"
	root.add_child(stat_system)

	var enemy := DummyEnemy.new()
	add_child_autofree(enemy)
	var host: BuffHost = BuffHostScript.new()
	enemy.add_child(host)
	await get_tree().process_frame
	var burn: BuffDef = FireDebuffScript.new()
	host.add_buff(burn)
	# on_apply already consumed the first tick (5 damage), so 4 remaining
	# ticks fire at the start of each subsequent second via on_process.
	for _index: int in range(5):
		host._process(1.0)

	assert_eq(burn.duration, 5.0)
	# First tick (5) dealt immediately on collision; remaining ticks (4, 3, 2, 1)
	# at the start of seconds 1–4. The 5th process frame expires the buff with
	# no additional tick.
	assert_eq(enemy.damage_events, [5, 4, 3, 2, 1])
	assert_false(host.has_buff("fire_burn_debuff"))
	root.remove_child(stat_system)
	stat_system.free()
	if previous_stat_system != null:
		previous_stat_system.name = "StatSystem"


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


# Manual state setup bypasses on_apply, so pending_ticks must reflect the
# post-immediate-tick value (original duration minus the first tick consumed
# by on_apply). A "4-tick burn" has 3 remaining after the instant first tick.
func test_burn_duration_stat_supports_four_and_five_ticks() -> void:
	var enemy := DummyEnemy.new()
	var burn: BuffDef = FireDebuffScript.new()
	# 4-tick burn: on_apply would consume the first tick (4), leaving 3.
	var state: Dictionary = {"pending_ticks": 3, "tick_accumulator": 0.0}
	for _index: int in range(3):
		burn.on_process(enemy, state, 1.0)
	assert_eq(enemy.damage_events, [3, 2, 1])
	enemy.damage_events.clear()
	# 5-tick burn: on_apply would consume the first tick (5), leaving 4.
	state = {"pending_ticks": 4, "tick_accumulator": 0.0}
	for _index: int in range(4):
		burn.on_process(enemy, state, 1.0)
	assert_eq(enemy.damage_events, [4, 3, 2, 1])
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


func test_burn_damage_uses_red_floating_text_scene() -> void:
	var pool: Node = FloatDamageTextPoolScript.new()
	pool.burn_floating_text_scene = BurnFloatingTextScene
	add_child_autofree(pool)
	var text: Node2D = pool.show_damage(3, Vector2.ZERO, &"burn")
	assert_eq(text.get_node("Label").get_theme_color("font_color"), Color(1.0, 0.2, 0.15, 1.0))


# on_apply now consumes the first tick immediately, so a configured 3-tick burn
# has 2 pending ticks remaining at the moment of death (spread = 2, not 3).
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
	# First tick consumed by on_apply; spread carries the remaining 2 ticks.
	assert_eq(destination.received_buffs[0].params.get("pending_ticks"), 2)
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


# on_apply consumes the first tick immediately, so a 3-tick burn starts with
# pending_ticks=2. Appending 20s capped at 10s yields applied_duration=7, so
# pending_ticks becomes 2+7=9 (one less than the cap due to the instant tick).
func test_death_propagation_appends_and_caps_existing_burn_at_nine_ticks() -> void:
	var enemy := DummyEnemy.new()
	add_child_autofree(enemy)
	var host: BuffHost = BuffHostScript.new()
	enemy.add_child(host)
	var burn: BuffDef = FireDebuffScript.new()
	host.add_buff(burn)
	host.append_buff_duration("fire_burn_debuff", 20.0, 10.0)
	assert_eq(host.get_buff_pending_ticks("fire_burn_debuff"), 9)
