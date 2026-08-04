extends GutTest

## 弹药行 HUD：节点结构、bomb_marble.png 图标、set_ammo 文本与三状态动画
## （隐藏/正常/0 弹药警示），以及 UI 规范——显隐与颜色只存在于 .tscn 动画，
## 脚本不写 visible/颜色。

const BattleHudScene: PackedScene = preload("res://Combat/presentation/battle_hud.tscn")
const BombMarbleTexture: Texture2D = preload("res://Assets/Marbles/bomb_marble.png")


func test_ammo_row_node_structure_icon_and_animation_states() -> void:
	var hud := add_child_autofree(BattleHudScene.instantiate()) as BattleHud
	var row := hud.get_node_or_null("ResourceRows/AmmoRow") as HBoxContainer
	assert_not_null(row, "ResourceRows 下存在 AmmoRow")
	if row == null:
		return
	var icon := row.get_node("AmmoIcon") as TextureRect
	var label := row.get_node("ValueLabel") as Label
	var animation := row.get_node("AmmoAnimation") as AnimationPlayer
	assert_not_null(icon, "AmmoIcon")
	assert_not_null(label, "ValueLabel")
	assert_not_null(animation, "AmmoAnimation")
	assert_eq(icon.texture, BombMarbleTexture, "弹药行复用 bomb_marble.png 图标")
	assert_false(row.visible, "初始隐藏（无炸弹链时）")
	assert_true(animation.has_animation(&"ammo_hidden"))
	assert_true(animation.has_animation(&"ammo_normal"))
	assert_true(animation.has_animation(&"ammo_empty"))


func test_set_ammo_writes_text_and_plays_three_discrete_states() -> void:
	var hud := add_child_autofree(BattleHudScene.instantiate()) as BattleHud
	var row := hud.get_node("ResourceRows/AmmoRow") as Control
	var label := hud.get_node("ResourceRows/AmmoRow/ValueLabel") as Label
	var animation := hud.get_node("ResourceRows/AmmoRow/AmmoAnimation") as AnimationPlayer

	# current_animation 在 play() 后同步成立；0 长度非循环动画播完即被清空，
	# 因此播放结果（visible/颜色）在帧后断言，两者结合验证三状态。
	hud.set_ammo(3, 5, true)
	assert_eq(animation.current_animation, "ammo_normal", "有弹药且链含炸弹 → 播放正常态")
	await wait_frames(1)
	assert_eq(label.text, "3/5")
	assert_true(row.visible, "正常态显示")
	assert_eq(
		label.get("theme_override_colors/font_color"), Color(1, 1, 1, 1),
		"正常态文字白色"
	)

	hud.set_ammo(0, 5, true)
	assert_eq(animation.current_animation, "ammo_empty", "0 弹药 → 播放警示态")
	await wait_frames(1)
	assert_eq(label.text, "0/5")
	assert_true(row.visible, "警示态仍显示")
	assert_eq(
		label.get("theme_override_colors/font_color"), Color(1, 0.42, 0.37, 1),
		"警示态文字警示色"
	)

	hud.set_ammo(5, 5, false)
	assert_eq(animation.current_animation, "ammo_hidden", "无炸弹链 → 播放隐藏态")
	await wait_frames(1)
	assert_eq(label.text, "5/5")
	assert_false(row.visible, "隐藏态隐藏")


func test_ammo_visibility_and_warning_color_defined_in_scene_animations() -> void:
	var hud := add_child_autofree(BattleHudScene.instantiate()) as BattleHud
	var animation := hud.get_node("ResourceRows/AmmoRow/AmmoAnimation") as AnimationPlayer
	var hidden := animation.get_animation(&"ammo_hidden") as Animation
	var normal := animation.get_animation(&"ammo_normal") as Animation
	var empty := animation.get_animation(&"ammo_empty") as Animation

	assert_false(bool(hidden.track_get_key_value(0, 0)), "隐藏态轨道 0：visible = false")
	assert_true(bool(normal.track_get_key_value(0, 0)), "正常态轨道 0：visible = true")
	assert_true(bool(empty.track_get_key_value(0, 0)), "警示态轨道 0：visible = true")
	assert_eq(empty.track_get_key_value(1, 0), Color(1, 0.42, 0.37, 1), "0 弹药警示色定义在场景动画")
	assert_eq(normal.track_get_key_value(1, 0), Color(1, 1, 1, 1), "正常色定义在场景动画")


func test_hud_script_does_not_write_visibility_or_colors() -> void:
	var source := FileAccess.get_file_as_string("res://Combat/presentation/battle_hud.gd")
	assert_false("visible" in source, "脚本不得直接写 visible")
	assert_false("font_color" in source, "脚本不得写字体颜色")
	assert_false("Color(" in source, "脚本不得出现颜色字面量")
