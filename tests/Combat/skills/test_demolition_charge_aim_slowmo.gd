extends GutTest

## 抛射炸弹瞄准：点按技能键进入慢镜头（Engine.time_scale = aiming_time_scale）、
## 鼠标定位落点（set_manual_target 注入绕过鼠标）、落点钳制到 aim_max_distance、
## 方向 = Head→落点单位向量、取消还原时间尺度并销毁指示器。

const ExecutorScript: GDScript = preload("res://Combat/skills/DemolitionCharge/demolition_charge_skill_executor.gd")
const Definition: Resource = preload("res://Combat/skills/DemolitionCharge/demolition_charge_skill_definition.tres")


class FakeController extends Node:
	var head: Node2D = null
	var spawn: Node2D = null

	func _init() -> void:
		spawn = Node2D.new()
		add_child(spawn)

	func get_active_head() -> Node:
		return head

	func get_projectile_parent() -> Node:
		return spawn


func before_each() -> void:
	Engine.time_scale = 1.0


func after_each() -> void:
	Engine.time_scale = 1.0


func _setup() -> Dictionary:
	var executor: Node = ExecutorScript.new()
	add_child_autofree(executor)
	var controller := FakeController.new()
	add_child_autofree(controller)
	var head := StaticBody2D.new()
	controller.add_child(head)
	head.global_position = Vector2(100, 200)
	controller.head = head
	return {"executor": executor, "controller": controller, "head": head, "definition": Definition}


func test_begin_aim_enters_slow_mo_and_has_valid_target() -> void:
	var setup: Dictionary = _setup()
	var executor: Node = setup["executor"]
	var definition: SkillDefinition = setup["definition"]

	assert_true(bool(executor.call("begin_aim", setup["controller"], definition)), "begin_aim 应成功")
	assert_true(bool(executor.call("is_aiming")), "进入瞄准态")
	assert_true(bool(executor.call("has_valid_aim_target")), "Head 有效即有瞄准目标")
	assert_almost_eq(
		Engine.time_scale,
		definition.aiming_time_scale,
		0.0001,
		"点按技能键进入慢镜头"
	)


func test_manual_target_sets_direction_and_clamps_distance() -> void:
	var setup: Dictionary = _setup()
	var executor: Node = setup["executor"]
	var definition: SkillDefinition = setup["definition"]
	var head_pos: Vector2 = (setup["head"] as Node2D).global_position

	assert_true(bool(executor.call("begin_aim", setup["controller"], definition)))
	var indicator: Node = executor.get("_indicator") as Node
	assert_not_null(indicator, "瞄准期间持有指示器")

	# 落点在 max_distance 之外 → 钳制到 max_distance，方向朝右。
	indicator.call("set_manual_target", head_pos + Vector2(500, 0))
	var target: Vector2 = indicator.call("get_aim_target")
	assert_almost_eq(target.distance_to(head_pos), definition.aim_max_distance, 0.0001, "落点钳制到最大距离")

	var direction: Vector2 = executor.call("get_aim_direction")
	assert_almost_eq(direction.angle(), 0.0, 0.0001, "方向 = Head→落点单位向量")


func test_cancel_aim_restores_time_scale_and_drops_indicator() -> void:
	var setup: Dictionary = _setup()
	var executor: Node = setup["executor"]
	var definition: SkillDefinition = setup["definition"]

	executor.call("begin_aim", setup["controller"], definition)
	var indicator: Node = executor.get("_indicator") as Node
	assert_not_null(indicator)

	executor.call("cancel_aim")

	assert_false(bool(executor.call("is_aiming")), "取消后退出瞄准态")
	assert_eq(executor.get("_indicator"), null, "取消销毁指示器")
	assert_almost_eq(Engine.time_scale, 1.0, 0.0001, "取消还原时间尺度")


func test_release_aim_spawns_bomb_at_head_and_restores_slow_mo() -> void:
	var setup: Dictionary = _setup()
	var executor: Node = setup["executor"]
	var definition: SkillDefinition = setup["definition"]
	var head_pos: Vector2 = (setup["head"] as Node2D).global_position

	assert_true(bool(executor.call("begin_aim", setup["controller"], definition)))
	var indicator: Node = executor.get("_indicator") as Node
	indicator.call("set_manual_target", head_pos + Vector2(150, 0))

	var released: bool = bool(executor.call("release_aim", setup["controller"], definition))
	assert_true(released, "松手抛射成功")
	assert_false(bool(executor.call("is_aiming")), "抛射后退出瞄准态")
	assert_almost_eq(Engine.time_scale, 1.0, 0.0001, "抛射还原时间尺度")

	var bomb: Node = null
	for child: Node in (setup["controller"] as Node).get("spawn").get_children():
		if child.is_in_group(&"skill_projectiles"):
			bomb = child
			break
	assert_not_null(bomb, "抛射生成一颗炸弹实体")
	assert_almost_eq((bomb as Node2D).global_position.x, head_pos.x, 0.0001, "炸弹从 Head 位置抛射")
