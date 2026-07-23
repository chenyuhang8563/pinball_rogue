extends GutTest

const FloatDamageTextPoolScript: GDScript = preload("res://Combat/presentation/float_damage_text_pool.gd")

var _pool: Node


func before_each() -> void:
	_pool = FloatDamageTextPoolScript.new()
	add_child_autofree(_pool)


func test_recycled_text_is_visible_after_battle_transition_release() -> void:
	var first: Node2D = _pool.show_damage(5, Vector2(10.0, 20.0))
	assert_not_null(first)

	# Simulates the battle-transition cleanup (main.gd -> release_all_active)
	# running while a damage text is still animating.
	_pool.release_all_active()
	assert_eq(_pool.get_active_count(), 0)

	var second: Node2D = _pool.show_damage(7, Vector2(30.0, 40.0))
	assert_eq(second, first, "pool should recycle the released instance")
	assert_true(second.visible, "recycled floating text must be visible when shown again")


func test_recycled_burn_text_is_visible_after_battle_transition_release() -> void:
	var first: Node2D = _pool.show_damage(3, Vector2(10.0, 20.0), &"burn")
	assert_not_null(first)

	_pool.release_all_active()

	var second: Node2D = _pool.show_damage(4, Vector2(30.0, 40.0), &"burn")
	assert_eq(second, first, "burn pool should recycle the released instance")
	assert_true(second.visible, "recycled burn floating text must be visible when shown again")


func test_element_styles_instantiate_their_dedicated_scenes() -> void:
	var expected: Dictionary = {
		&"poison": "PoisonFloatingText",
		&"frost": "FrostFloatingText",
		&"lightning": "LightningFloatingText",
		&"explosion": "ExplosionFloatingText",
	}
	for style: StringName in expected.keys():
		var text: Node2D = _pool.show_damage(9, Vector2.ZERO, style)
		assert_not_null(text, "style %s should resolve to a scene" % style)
		if text == null:
			continue
		assert_eq(text.name, expected[style], "style %s should use its dedicated scene" % style)
		assert_true(text.visible)
		_pool.release_all_active()
		assert_eq(_pool.get_active_count(), 0)


func test_element_styles_recycle_within_their_own_pool() -> void:
	var first: Node2D = _pool.show_damage(1, Vector2(1.0, 1.0), &"poison")
	assert_not_null(first)

	_pool.release_all_active()

	var second: Node2D = _pool.show_damage(2, Vector2(2.0, 2.0), &"poison")
	assert_eq(second, first, "poison pool should recycle the released instance")
	assert_true(second.visible, "recycled poison floating text must be visible when shown again")
