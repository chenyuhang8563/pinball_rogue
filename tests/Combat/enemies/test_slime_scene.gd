extends GutTest

const SLIME_SCENE: PackedScene = preload("res://Combat/battle/enemies/slime.tscn")


func test_slime_sprite_sheet_uses_32_pixel_frames() -> void:
	var slime := SLIME_SCENE.instantiate() as Enemy
	add_child_autofree(slime)
	var sprite := slime.get_node("Sprite2D") as Sprite2D

	assert_not_null(sprite.texture)
	assert_eq(sprite.texture.resource_path, "res://Assets/Monsters/Slime.png")
	assert_eq(sprite.hframes, 16)
	assert_eq(sprite.vframes, 16)
	assert_true(sprite.region_enabled)
	assert_eq(sprite.region_rect, Rect2(0.0, 0.0, 512.0, 256.0))


func test_slime_animation_player_exposes_complete_green_slime_clips() -> void:
	var slime := SLIME_SCENE.instantiate() as Enemy
	add_child_autofree(slime)
	var player := slime.get_node("AnimationPlayer") as AnimationPlayer

	assert_eq(player.autoplay, &"idle")
	assert_eq(_frames(player, &"RESET"), [0])
	assert_eq(_frames(player, &"idle"), [0, 1, 2, 1])
	assert_eq(_frames(player, &"jump"), [16, 17, 18, 19, 20, 19, 18, 17, 16])
	assert_eq(_frames(player, &"attack_left"), [72, 73, 74, 75, 76, 77, 78, 79])
	assert_eq(_frames(player, &"attack_right"), [56, 57, 58, 59, 60, 61, 62, 63])
	assert_eq(_frames(player, &"death"), [32, 33, 34, 35, 36, 37, 38, 39])
	assert_eq(player.get_animation(&"idle").loop_mode, Animation.LOOP_LINEAR)
	assert_eq(player.get_animation(&"jump").loop_mode, Animation.LOOP_NONE)
	assert_eq(player.get_animation(&"death").loop_mode, Animation.LOOP_NONE)


func test_slime_exposes_attack_warning_module() -> void:
	var slime := SLIME_SCENE.instantiate() as Enemy
	add_child_autofree(slime)

	var attack_warning: Node = slime.get_node_or_null("AttackWarning")
	assert_not_null(attack_warning)
	if attack_warning == null:
		return
	assert_true(attack_warning.has_method(&"configure"))
	assert_true(attack_warning.has_signal(&"player_damage_requested"))


func _frames(player: AnimationPlayer, animation_name: StringName) -> Array[int]:
	assert_true(player.has_animation(animation_name))
	var animation: Animation = player.get_animation(animation_name)
	assert_eq(animation.track_get_path(0), ^"Sprite2D:frame")
	var frames: Array[int] = []
	for key_index: int in range(animation.track_get_key_count(0)):
		frames.append(int(animation.track_get_key_value(0, key_index)))
	return frames
