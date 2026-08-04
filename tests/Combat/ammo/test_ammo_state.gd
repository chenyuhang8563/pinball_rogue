extends GutTest

## AmmoState 弹药机制：默认 5、战斗开始重置、原子消耗、发射回满、
## 觉醒临时超上限、补弹不超 ceiling、绑定/解绑与跨测试隔离。

const AmmoStateScript: GDScript = preload("res://Combat/ammo/ammo_state.gd")
const FakeStatSystemScript: GDScript = preload("res://tests/Loadout/fake_stat_system.gd")


class FakeLifecycle extends Node:
	signal battle_started(token, plan)

	func emit_start() -> void:
		battle_started.emit(null, null)


class FakeLauncher extends Node:
	signal marble_launched(marble, applied_impulse)

	func launch() -> void:
		marble_launched.emit(null, Vector2.ZERO)


func test_defaults_to_five_without_stat_system() -> void:
	var ammo: Node = autofree(AmmoStateScript.new())
	assert_eq(ammo.get_ammo(), 5, "未配置时默认 5")
	assert_eq(ammo.get_max_ammo(), 5, "无 stat 系统时上限回退 5")


func test_max_ammo_reads_stat_with_fallback() -> void:
	var stats: Node = autofree(FakeStatSystemScript.new())
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.configure(stats, FakeLifecycle.new())
	assert_eq(ammo.get_max_ammo(), 5, "stat 缺失（0.0）时回退默认 5")
	stats.set("values", {"max_ammo": 8.0})
	assert_eq(ammo.get_max_ammo(), 8, "读取 max_ammo stat")


func test_battle_start_resets_ammo_to_max() -> void:
	var lifecycle := FakeLifecycle.new()
	add_child_autofree(lifecycle)
	var stats: Node = autofree(FakeStatSystemScript.new())
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.configure(stats, lifecycle)
	assert_eq(ammo.get_ammo(), 5, "configure 后即满弹药")
	assert_true(ammo.consume(2))
	assert_eq(ammo.get_ammo(), 3)
	lifecycle.emit_start()
	assert_eq(ammo.get_ammo(), 5, "战斗开始回满")


func test_consume_is_atomic() -> void:
	var ammo: Node = autofree(AmmoStateScript.new())
	assert_false(ammo.consume(6), "不足时拒绝且不部分扣减")
	assert_eq(ammo.get_ammo(), 5)
	assert_true(ammo.consume(5))
	assert_eq(ammo.get_ammo(), 0)
	assert_false(ammo.consume(1), "0 弹药不能再扣")
	assert_true(ammo.consume(0), "0 消耗视为成功")


func test_add_never_exceeds_ceiling() -> void:
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.consume(5)
	ammo.add(2)
	assert_eq(ammo.get_ammo(), 2)
	ammo.add(10)
	assert_eq(ammo.get_ammo(), 5, "补弹不超上限")
	assert_eq(ammo.add(-1), 5, "非正补弹直接返回当前值")


func test_launch_refills_ammo() -> void:
	var launcher := FakeLauncher.new()
	var root := Node2D.new()
	root.add_child(launcher)
	add_child_autofree(root)
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.configure(autofree(FakeStatSystemScript.new()), FakeLifecycle.new())
	ammo.bind_launch_sources(root)
	ammo.consume(3)
	launcher.launch()
	assert_eq(ammo.get_ammo(), 5, "挡板发射回满")


func test_double_launcher_refills_once_without_stack_overflow() -> void:
	var first := FakeLauncher.new()
	var second := FakeLauncher.new()
	var root := Node2D.new()
	root.add_child(first)
	root.add_child(second)
	add_child_autofree(root)
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.configure(autofree(FakeStatSystemScript.new()), FakeLifecycle.new())
	ammo.bind_launch_sources(root)
	ammo.consume(2)
	first.launch()
	second.launch()
	assert_eq(ammo.get_ammo(), 5, "双挡板各自回满一次，不叠加")


func test_rebind_disconnects_old_launch_sources() -> void:
	var first := FakeLauncher.new()
	var second := FakeLauncher.new()
	var first_root := Node2D.new()
	var second_root := Node2D.new()
	first_root.add_child(first)
	second_root.add_child(second)
	add_child_autofree(first_root)
	add_child_autofree(second_root)
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.configure(autofree(FakeStatSystemScript.new()), FakeLifecycle.new())
	ammo.bind_launch_sources(first_root)
	ammo.bind_launch_sources(second_root)
	ammo.consume(3)
	first.launch()
	assert_eq(ammo.get_ammo(), 2, "换台面后旧挡板连接已断开")
	second.launch()
	assert_eq(ammo.get_ammo(), 5, "新台面挡板正常回满")


func test_awakened_battle_start_bonus_then_first_launch_refills_to_base() -> void:
	var lifecycle := FakeLifecycle.new()
	add_child_autofree(lifecycle)
	var launcher := FakeLauncher.new()
	var root := Node2D.new()
	root.add_child(launcher)
	add_child_autofree(root)
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.configure(autofree(FakeStatSystemScript.new()), lifecycle)
	ammo.bind_launch_sources(root)
	ammo.set_battle_start_bonus(2)
	lifecycle.emit_start()
	assert_eq(ammo.get_ammo(), 7, "弹药袋觉醒：战斗开始弹药 = max + 2")
	ammo.consume(7)
	assert_false(ammo.consume(1), "超上限弹药扣完后不能透支")
	launcher.launch()
	assert_eq(ammo.get_ammo(), 5, "首次发射回落后恢复为 max")
	ammo.add(10)
	assert_eq(ammo.get_ammo(), 5, "回落后补弹不超 max")
	lifecycle.emit_start()
	assert_eq(ammo.get_ammo(), 7, "下一场战斗再次获得加成")


func test_unconfigure_disconnects_everything_and_resets() -> void:
	var lifecycle := FakeLifecycle.new()
	add_child_autofree(lifecycle)
	var launcher := FakeLauncher.new()
	var root := Node2D.new()
	root.add_child(launcher)
	add_child_autofree(root)
	var ammo: Node = autofree(AmmoStateScript.new())
	ammo.configure(autofree(FakeStatSystemScript.new()), lifecycle)
	ammo.bind_launch_sources(root)
	ammo.set_battle_start_bonus(2)
	ammo.consume(7)
	ammo.unconfigure()
	assert_eq(ammo.get_ammo(), 5, "unconfigure 恢复默认")
	assert_eq(ammo.get_max_ammo(), 5)
	ammo.consume(2)
	launcher.launch()
	assert_eq(ammo.get_ammo(), 3, "解绑后发射不再回满")
	lifecycle.emit_start()
	assert_eq(ammo.get_ammo(), 3, "战斗开始信号也已断开")
