extends GutTest

## 回响弹珠场景契约测试：挡板外轮廓（echo_flipper_outline.gdshader，复用
## marble_outline 外轮廓算法 + 黄/红双色进度）与 set_echo_charge 入口均来自
## .tscn/脚本契约，控制器预置于 table_base.tscn，脚本不组装视觉结构。

const FlipperScene: PackedScene = preload("res://Combat/battle/table/flipper/flipper.tscn")
const TableBaseScene: PackedScene = preload("res://Combat/levels/table_base.tscn")
const EchoOutlineShader: Shader = preload(
	"res://Combat/battle/table/flipper/echo_flipper_outline.gdshader"
)
const EchoControllerScript: GDScript = preload(
	"res://Combat/battle/table/flipper/echo_flipper_charge_controller.gd"
)


func test_flipper_sprite_uses_echo_outline_shader_disabled_by_default() -> void:
	var flipper: Node = FlipperScene.instantiate()
	add_child_autofree(flipper)
	var sprite := flipper.get_node_or_null("FlipperBody/Sprite2D") as Sprite2D
	assert_not_null(sprite)
	var material := sprite.material as ShaderMaterial
	assert_not_null(material, "挡板 Sprite2D 必须挂 ShaderMaterial（.tscn 定义）")
	assert_eq(material.shader, EchoOutlineShader, "必须使用回响外轮廓 shader")
	assert_eq(float(material.get_shader_parameter("yellow_progress")), 0.0, "默认无黄色蓄力")
	assert_eq(float(material.get_shader_parameter("red_progress")), 0.0, "默认无红色蓄力")


func test_set_echo_charge_drives_shader_progress_parameters() -> void:
	var flipper: Node = FlipperScene.instantiate()
	add_child_autofree(flipper)
	var sprite := flipper.get_node_or_null("FlipperBody/Sprite2D") as Sprite2D
	var material := sprite.material as ShaderMaterial

	flipper.call("set_echo_charge", 0.5)
	assert_eq(float(material.get_shader_parameter("yellow_progress")), 0.5, "半层：黄色进度 0.5")
	assert_eq(float(material.get_shader_parameter("red_progress")), 0.0, "半层：无红色")

	flipper.call("set_echo_charge", 1.5)
	assert_eq(float(material.get_shader_parameter("yellow_progress")), 1.0, "1.5 层：黄色已包裹满")
	assert_eq(float(material.get_shader_parameter("red_progress")), 0.5, "1.5 层：红色进度 0.5")

	flipper.call("set_echo_charge", 0.0)
	assert_eq(float(material.get_shader_parameter("yellow_progress")), 0.0, "清零：无蓄力轮廓")
	assert_eq(float(material.get_shader_parameter("red_progress")), 0.0)


func test_flipper_scene_exposes_launch_signal_and_charge_visual_entry() -> void:
	var flipper: Node = FlipperScene.instantiate()
	add_child_autofree(flipper)
	assert_true(flipper.has_signal(&"marble_launched"), "挡板必须暴露 marble_launched 事实信号")
	assert_true(flipper.has_method(&"set_echo_charge"), "挡板必须暴露蓄力视觉入口")


func test_table_base_presets_echo_charge_controller() -> void:
	var table: Node = TableBaseScene.instantiate()
	add_child_autofree(table)
	var controller := table.get_node_or_null("EchoCharge") as Node
	assert_not_null(controller, "EchoCharge 控制器必须预置于 table_base.tscn")
	assert_true(controller.get_script() == EchoControllerScript, "EchoCharge 必须挂回响控制器脚本")
	assert_true(controller.has_signal(&"charge_changed"), "控制器必须暴露 charge_changed 信号")
	assert_eq(controller.get_layers(), 0, "新表蓄力从 0 开始")


func test_table_base_flippers_expose_launch_signal_for_binding() -> void:
	var table: Node = TableBaseScene.instantiate()
	add_child_autofree(table)
	for flipper_name: String in ["LFlipper", "RFlipper"]:
		var flipper := table.get_node_or_null(flipper_name) as Node
		assert_not_null(flipper, "%s 必须存在于 table_base.tscn" % flipper_name)
		assert_true(flipper.has_signal(&"marble_launched"), "%s 必须暴露 marble_launched" % flipper_name)
		assert_true(flipper.has_method(&"set_echo_charge"), "%s 必须暴露 set_echo_charge" % flipper_name)
