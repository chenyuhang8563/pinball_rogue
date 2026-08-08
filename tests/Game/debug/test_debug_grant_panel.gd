extends GutTest

const PanelScene: PackedScene = preload("res://Game/Debug/debug_grant_panel.tscn")


func test_panel_scene_loads_with_level_and_resource_rows() -> void:
	var panel: Control = add_child_autofree(PanelScene.instantiate())
	# 场景结构：等级选择器与金币/血量行均存在。
	assert_not_null(panel.get_node_or_null("Center/Panel/Margin/Layout/LevelRow/LevelOption"))
	assert_not_null(panel.get_node_or_null("Center/Panel/Margin/Layout/GoldRow/GoldValueLabel"))
	assert_not_null(panel.get_node_or_null("Center/Panel/Margin/Layout/GoldRow/GoldAddButton"))
	assert_not_null(panel.get_node_or_null("Center/Panel/Margin/Layout/HealthRow/HealthValueLabel"))
	assert_not_null(panel.get_node_or_null("Center/Panel/Margin/Layout/HealthRow/HealthAddButton"))


func test_present_resources_reflects_gold_and_health() -> void:
	var panel: Control = add_child_autofree(PanelScene.instantiate())
	panel.call("present_resources", 1234, 56)
	assert_eq(panel.get_node("Center/Panel/Margin/Layout/GoldRow/GoldValueLabel").text, "1234")
	assert_eq(panel.get_node("Center/Panel/Margin/Layout/HealthRow/HealthValueLabel").text, "56")


func test_grant_button_emits_item_with_selected_level() -> void:
	var panel: Control = add_child_autofree(PanelScene.instantiate())
	panel.call("configure_items", PackedStringArray(["green_marble", "ice_hammer", "dash"]))
	var emitted: Array = []
	panel.connect(&"grant_requested", func(item_id: StringName, level: int) -> void:
		emitted.append([item_id, level])
	)
	var grant_button: Button = panel.get_node("Center/Panel/Margin/Layout/GrantButton")
	var level_option: OptionButton = panel.get_node("Center/Panel/Margin/Layout/LevelRow/LevelOption")
	# 弹珠类别默认选中 green_marble，等级默认 Lv1。
	grant_button.pressed.emit()
	assert_eq(emitted[0], [&"green_marble", 1])
	# 切换到等级 3（下标 2）后发放。
	level_option.select(2)
	grant_button.pressed.emit()
	assert_eq(emitted[1], [&"green_marble", 3])


func test_resource_buttons_emit_grant_amounts() -> void:
	var panel: Control = add_child_autofree(PanelScene.instantiate())
	var gold_calls: Array[int] = []
	var health_calls: Array[int] = []
	panel.connect(&"gold_requested", func(amount: int) -> void: gold_calls.append(amount))
	panel.connect(&"health_requested", func(amount: int) -> void: health_calls.append(amount))
	panel.get_node("Center/Panel/Margin/Layout/GoldRow/GoldAddButton").pressed.emit()
	panel.get_node("Center/Panel/Margin/Layout/HealthRow/HealthAddButton").pressed.emit()
	assert_eq(gold_calls, [1000])
	assert_eq(health_calls, [10])
