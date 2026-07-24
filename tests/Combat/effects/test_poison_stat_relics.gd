extends GutTest

const ENTITY_ID: String = "marble_chain"
func after_each() -> void:
	var stats := _stat_system()
	if stats == null:
		return
	for modifier_id: String in [
		"relic_upgrade:venom_knife",
		"relic_upgrade:scorpion_tail",
		"relic_upgrade:witch_hat",
	]:
		stats.call("remove_modifier", ENTITY_ID, modifier_id)


func test_venom_knife_increases_poison_stacks_without_fly_state() -> void:
	var effect := VenomKnifeEffect.new()
	effect.set_level(1)
	assert_eq(_stat("poison_stacks_per_hit"), 2)
	effect.set_level(2)
	assert_eq(_stat("poison_stacks_per_hit"), 3)
	effect.set_level(3)
	assert_eq(_stat("poison_stacks_per_hit"), 4)
	effect.set_awakened(true)
	assert_eq(_stat("poison_stacks_per_hit"), 5)
	effect.dispose()


func test_scorpion_tail_increases_each_poison_layer_damage() -> void:
	var effect := ScorpionTailEffect.new()
	effect.set_level(2)
	assert_eq(_stat("poison_damage_per_layer"), 3.0)
	effect.set_awakened(true)
	assert_eq(_stat("poison_damage_per_layer"), 4.0)
	effect.dispose()


func test_witch_hat_preserves_an_awakening_gain_below_the_stack_cap() -> void:
	var effect := WitchHatEffect.new()
	effect.set_level(1)
	assert_eq(_stat("poison_max_stacks"), 12)
	effect.set_level(2)
	assert_eq(_stat("poison_max_stacks"), 14)
	effect.set_level(3)
	assert_eq(_stat("poison_max_stacks"), 17)
	effect.set_awakened(true)
	assert_eq(_stat("poison_max_stacks"), 27)
	assert_eq(PoisonDebuff.MAX_POISON_STACKS, 30)
	effect.dispose()


func _stat(stat_id: String) -> Variant:
	var stats := _stat_system()
	assert_not_null(stats)
	return stats.call("get_stat", stat_id, ENTITY_ID)


func _stat_system() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("StatSystem") if tree != null else null
