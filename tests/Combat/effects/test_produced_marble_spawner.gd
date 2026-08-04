extends GutTest

## ProducedMarbleSpawner —— 可复用产出服务：实例化到当前关卡、按 group 实时计数
## （≤上限）、战斗开始清场、跨战斗交错计数正确性（无负数）、物理回调安全。
##
## 挂载统一 call_deferred（物理回调期间禁止同步 add_child），因此 spawn 返回的
## 实例可能尚未挂载；断言挂载/生命周期前 await 一帧让 deferred 执行。计数用
## group 实时查询 + _pending 补充，旧实例被 queue_free 后计数立即归零，无负数。

const ProducedMarbleSpawnerScript: GDScript = preload("res://Combat/marbles/produced_marble_spawner.gd")
const SmallBombScene: PackedScene = preload("res://Combat/marbles/small_bomb_marble.tscn")

var _spawner: Node = null
var _parent: Node2D = null


func before_each() -> void:
	_parent = Node2D.new()
	add_child_autofree(_parent)
	_spawner = ProducedMarbleSpawnerScript.new()
	_spawner.call("configure", Callable(func() -> Node: return _parent))
	add_child_autofree(_spawner)


## 连续请求 count 次产出，返回成功实例化数（达上限返回 null 不计）。
func _spawn(count: int) -> int:
	var success: int = 0
	for _i: int in range(count):
		var inst: Node2D = _spawner.call("spawn", SmallBombScene, Vector2(10, 20), 3)
		if inst != null:
			success += 1
	return success


func test_spawn_instantiates_under_level_parent() -> void:
	var inst: Node2D = _spawner.call("spawn", SmallBombScene, Vector2(10, 20), 3)
	assert_not_null(inst, "产出成功")
	await wait_frames(1)  # 挂载被 call_deferred 延迟到帧末
	assert_same(inst.get_parent(), _parent, "实例化到当前关卡父节点")
	# 小炸弹 _ready 施加随机方向初速，物理帧会轻微移动；断言接近生成点即可。
	var spawn_offset: float = inst.global_position.distance_to(Vector2(10, 20))
	assert_lt(spawn_offset, 5.0, "生成位置接近指定点（impulse 初速已轻微移动）")
	assert_eq(int(_spawner.call("active_count")), 1, "计数 = 1")
	assert_true(inst.is_in_group("produced_marbles"), "加入 produced_marbles group")
	assert_false(inst.is_in_group("marbles"), "不入 marbles group（避免 RunFlow 误扣生命）")


func test_spawn_caps_at_max_active() -> void:
	var spawned: int = _spawn(6)
	assert_eq(spawned, 3, "达上限后返回 null，只产出 3 个")
	assert_eq(int(_spawner.call("active_count")), 3, "计数封顶 3（_pending 即时计入）")
	await wait_frames(1)  # 挂载 3 个实例，避免残留 orphan
	assert_null(_spawner.call("spawn", SmallBombScene, Vector2.ZERO, 3), "再请求返回 null")
	assert_eq(int(_spawner.call("active_count")), 3, "挂载后计数仍封顶 3")


func test_spawn_returns_null_when_unconfigured() -> void:
	var orphan: Node = ProducedMarbleSpawnerScript.new()
	add_child_autofree(orphan)
	assert_null(orphan.call("spawn", SmallBombScene, Vector2.ZERO, 3), "无 level_provider 返回 null")
	assert_eq(int(orphan.call("active_count")), 0)


func test_spawn_returns_null_when_provider_gives_null() -> void:
	var bad: Node = ProducedMarbleSpawnerScript.new()
	bad.call("configure", Callable(func() -> Node: return null))
	add_child_autofree(bad)
	assert_null(bad.call("spawn", SmallBombScene, Vector2.ZERO, 3), "关卡父节点缺失返回 null")


func test_spawn_handles_null_scene() -> void:
	assert_null(_spawner.call("spawn", null, Vector2.ZERO, 3), "场景无效返回 null")


func test_active_count_reflects_queue_free_in_real_time() -> void:
	var first: Node2D = _spawner.call("spawn", SmallBombScene, Vector2(1, 1), 3)
	assert_not_null(first)
	await wait_frames(1)  # 挂载后再验证
	assert_eq(int(_spawner.call("active_count")), 1)
	first.queue_free()
	await wait_frames(1)  # 让 queue_free 真正释放
	assert_eq(int(_spawner.call("active_count")), 0, "queue_free 后计数立即归零（过滤排队删除）")


## 跨战斗交错：第一战满 3 → 清场 → 计数归零（无负数）→ 新战斗重新到 3 → 第 4 次拒绝。
func test_reset_for_battle_clears_field_and_recounts_without_negative() -> void:
	var first_wave: int = _spawn(6)
	assert_eq(first_wave, 3, "第一战满 3")
	await wait_frames(1)  # 挂载 3 个实例

	_spawner.call("reset_for_battle")
	await wait_frames(1)  # 让清场 queue_free 真正释放
	assert_eq(int(_spawner.call("active_count")), 0, "清场后计数归零（无负数）")

	var second_wave: int = 0
	for _i: int in range(3):
		var inst: Node2D = _spawner.call("spawn", SmallBombScene, Vector2(1, 1), 3)
		if inst != null:
			second_wave += 1
	assert_eq(second_wave, 3, "新战斗连续产出 3 个")
	await wait_frames(1)
	assert_null(_spawner.call("spawn", SmallBombScene, Vector2(2, 2), 3), "第 4 次返回 null")
	assert_eq(int(_spawner.call("active_count")), 3, "跨战斗后计数仍正确封顶 3")
