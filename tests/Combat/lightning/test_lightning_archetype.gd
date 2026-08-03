extends GutTest

const EnemyScene: PackedScene = preload("res://Combat/battle/enemies/enemy.tscn")
const LightningChainEffectScene: PackedScene = preload("res://Combat/effects/lightning_effect/lightning_effect.tscn")
const LoadoutScript: GDScript = preload("res://Loadout/domain/loadout.gd")
const ProgressionScript: GDScript = preload("res://Loadout/application/item_progression.gd")

var _effect_manager: Node = null


func before_each() -> void:
	_effect_manager = get_node_or_null("/root/EffectManager")
	assert_not_null(_effect_manager)
	var empty_loadout: RefCounted = LoadoutScript.new()
	assert_true(_effect_manager.call("configure", empty_loadout, ProgressionScript.new(empty_loadout)))
	var manager_runtime: Variant = _effect_manager.get("_lightning_runtime")
	if manager_runtime != null:
		manager_runtime.call("set_visuals_enabled", false)


func test_enemy_marble_chain_integration_applies_base_hit_before_discharge() -> void:
	var enemy := _enemy(100)
	var chain := MarbleChain.new()
	add_child_autofree(chain)
	var item := Item.new()
	item.id = "lightning_marble"
	item.type = Item.ItemType.MARBLE
	item.marble_type = Marble.MARBLE_TYPE.LIGHTNING
	item.marble_segment_damage = 1
	chain.build_chain([item], [Vector2.ZERO])

	enemy._on_body_entered(chain.head)
	assert_eq(enemy.health, 99, "first contact resolves one physical damage")
	assert_eq(enemy.get_buff_stacks(ArcDebuff.ARC_ID), 1, "Arc is attached after the physical hit")
	enemy._on_body_entered(chain.head)
	assert_eq(enemy.health, 96, "second contact resolves 1 physical then 2 discharge damage")
	assert_eq(enemy.get_buff_stacks(ArcDebuff.ARC_ID), 2)


func test_lightning_chain_effect_restores_the_original_seven_frame_animation() -> void:
	var effect: AnimatedSprite2D = LightningChainEffectScene.instantiate() as AnimatedSprite2D
	assert_not_null(effect)
	add_child_autofree(effect)
	assert_not_null(effect.sprite_frames)
	assert_eq(effect.sprite_frames.get_frame_count(&"default"), 7)
	assert_eq(effect.sprite_frames.get_animation_speed(&"default"), 15.0)
	assert_false(effect.sprite_frames.get_animation_loop(&"default"))


func test_first_hit_charges_then_repeat_hits_discharge_and_cap_at_three() -> void:
	var runtime := _runtime({})
	var enemy := _enemy(100)

	_resolve_direct_hit(runtime, enemy)
	assert_eq(enemy.health, 100, "first lightning hit only charges Arc after base damage")
	assert_eq(enemy.get_buff_stacks(ArcDebuff.ARC_ID), 1)
	enemy.buff_host._process(2.0)
	var shortened: float = enemy.buff_host.get_buff_remaining_time(ArcDebuff.ARC_ID)

	_resolve_direct_hit(runtime, enemy)
	assert_eq(enemy.health, 98, "one stored Arc deals 1 x 2 discharge damage")
	assert_eq(enemy.get_buff_stacks(ArcDebuff.ARC_ID), 2)
	assert_gt(enemy.buff_host.get_buff_remaining_time(ArcDebuff.ARC_ID), shortened)
	_resolve_direct_hit(runtime, enemy)
	assert_eq(enemy.health, 94, "two stored Arc deal 2 x 2 discharge damage")
	assert_eq(enemy.get_buff_stacks(ArcDebuff.ARC_ID), 3)
	_resolve_direct_hit(runtime, enemy)
	assert_eq(enemy.health, 88, "three stored Arc remain the stable capped payoff")
	assert_eq(enemy.get_buff_stacks(ArcDebuff.ARC_ID), 3)


func test_awakened_lightning_marble_adds_two_arc_only_after_repeat() -> void:
	var runtime := _runtime({})
	_set_marble_stat("lightning_repeat_arc_stacks", 2.0)
	var enemy := _enemy(100)
	_resolve_direct_hit(runtime, enemy)
	assert_eq(enemy.get_buff_stacks(ArcDebuff.ARC_ID), 1, "first charge remains one stack")
	_resolve_direct_hit(runtime, enemy)
	assert_eq(enemy.get_buff_stacks(ArcDebuff.ARC_ID), 3, "repeat discharge reapplies two stacks")
	_clear_marble_stat("lightning_repeat_arc_stacks")


func test_leyden_jar_awakened_breakthrough_uses_snapshot_then_resets() -> void:
	var leyden := LeydenJarEffect.new()
	leyden.set_level(3)
	leyden.set_awakened(true)
	var runtime := _runtime({&"leyden_jar": leyden})
	var enemy := _enemy(100)
	enemy.add_buff(ArcDebuff.new(), 6)

	_resolve_direct_hit(runtime, enemy)
	assert_eq(enemy.health, 82, "6 x 2 discharge is multiplied to 18 before clearing")
	assert_eq(enemy.get_buff_stacks(ArcDebuff.ARC_ID), 1, "breakthrough clears then reapplies this hit")


func test_lightning_chain_prefers_uncharged_targets_and_never_hits_source() -> void:
	var chain := LightningEffect.new()
	chain.set_level(2)
	var runtime := _runtime({&"lightning": chain})
	var source := _enemy(100, Vector2.ZERO)
	var charged_near := _enemy(100, Vector2(10.0, 0.0))
	var uncharged_near := _enemy(100, Vector2(20.0, 0.0))
	var uncharged_far := _enemy(100, Vector2(30.0, 0.0))
	charged_near.add_buff(ArcDebuff.new(), 2)
	_resolve_direct_hit(runtime, source)
	_resolve_direct_hit(runtime, source)

	assert_eq(source.health, 98, "source only takes its direct discharge")
	assert_eq(charged_near.health, 100, "charged target loses priority to both uncharged targets")
	assert_eq(uncharged_near.health, 97)
	assert_eq(uncharged_far.health, 97)
	assert_eq(uncharged_near.get_buff_stacks(ArcDebuff.ARC_ID), 1)
	assert_eq(uncharged_far.get_buff_stacks(ArcDebuff.ARC_ID), 1)


func test_arc_relay_copies_to_two_targets_and_relay_source_cannot_recurse() -> void:
	var relay := ArcRelayEffect.new()
	relay.set_level(3)
	relay.set_awakened(true)
	var runtime := _runtime({&"arc_relay": relay})
	var source := _enemy(100, Vector2.ZERO)
	var first := _enemy(100, Vector2(20.0, 0.0))
	var second := _enemy(100, Vector2(40.0, 0.0))
	source.add_buff(ArcDebuff.new(), 3)
	var killing_packet := DamagePacket.new(&"lightning_discharge", 100.0, &"lightning")
	runtime.on_enemy_defeated(source, killing_packet)

	assert_eq(first.health, 92)
	assert_eq(second.health, 92)
	assert_eq(first.get_buff_stacks(ArcDebuff.ARC_ID), 3)
	assert_eq(second.get_buff_stacks(ArcDebuff.ARC_ID), 3)
	var relay_packet := DamagePacket.new(&"relic_arc_relay", 8.0, &"lightning")
	runtime.on_enemy_defeated(first, relay_packet)
	assert_eq(second.health, 92, "relay-created deaths are source-filtered")


func test_thunderstorm_triggers_once_per_shot_and_resets_on_ball_lost() -> void:
	var storm := ThunderstormEffect.new()
	storm.set_level(3)
	var runtime := _runtime({&"thunderstorm": storm})
	var source := _enemy(1000, Vector2.ZERO)
	var target := _enemy(1000, Vector2(20.0, 0.0))
	target.add_buff(ArcDebuff.new(), 1)
	_resolve_direct_hit(runtime, source)
	for _index: int in range(4):
		_resolve_direct_hit(runtime, source)
	assert_true(runtime.has_triggered_thunderstorm())
	assert_eq(runtime.get_direct_discharge_count(), 4)
	var health_after_storm: int = target.health
	_resolve_direct_hit(runtime, source)
	assert_eq(target.health, health_after_storm, "the same shot cannot trigger a second storm")

	runtime.reset_shot()
	assert_false(runtime.has_triggered_thunderstorm())
	assert_eq(runtime.get_direct_discharge_count(), 0)


func test_all_lightning_relics_require_the_lightning_marble_tag() -> void:
	for item_id: String in ["lightning", "leyden_jar", "arc_relay", "thunderstorm"]:
		var item: Item = load("res://Content/data/%s.tres" % item_id) as Item
		assert_not_null(item, item_id)
		assert_true(item.requires_tags.has(&"lightning_marble"), item_id)
	var marble: Item = load("res://Content/data/lightning_marble.tres") as Item
	assert_not_null(marble)
	assert_true(marble.tags.has(&"lightning_marble"))
	assert_eq(marble.marble_type, Marble.MARBLE_TYPE.LIGHTNING)


func _runtime(effects: Dictionary) -> LightningArchetypeRuntime:
	var runtime := LightningArchetypeRuntime.new()
	runtime.configure(func(effect_id: StringName) -> Variant: return effects.get(effect_id, null))
	runtime.set_visuals_enabled(false)
	return runtime


func _resolve_direct_hit(runtime: LightningArchetypeRuntime, enemy: Enemy) -> void:
	var packet := DamagePacket.new(&"marble_head", 1.0)
	packet.is_marble = true
	packet.target = enemy
	LightningMarble.prepare_direct_hit(enemy, packet)
	packet.metadata[LightningMarble.META_ORIGIN_POSITION] = Vector2.ZERO
	runtime.on_enemy_hit_resolved(enemy, packet)


func _enemy(hit_points: int, position: Vector2 = Vector2.ZERO) -> Enemy:
	var enemy: Enemy = EnemyScene.instantiate() as Enemy
	enemy.health = hit_points
	add_child_autofree(enemy)
	enemy.global_position = position
	return enemy


func _set_marble_stat(stat_id: String, value: float) -> void:
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	assert_not_null(stat_system)
	stat_system.call(
		"add_modifier",
		"marble_chain",
		StatModifier.new("lightning_test:%s" % stat_id, stat_id, StatModifier.ModOp.OVERRIDE, value, "lightning_test")
	)


func _clear_marble_stat(_stat_id: String) -> void:
	var stat_system: Node = get_node_or_null("/root/StatSystem")
	if stat_system != null:
		stat_system.call("remove_modifiers_by_source", "marble_chain", "lightning_test")
