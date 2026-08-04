# ProducedMarbleSpawner —— 产出独立弹珠的可复用服务（如高爆弹头的小炸弹）。
#
# 职责：
#   - 实例化到当前关卡（battle_gateway.active_level_scene）父节点
#   - 按 group 实时计数，场上同时最多 max_active 个
#   - 战斗开始清场（battle_started → reset_for_battle，防御性清理旧台面残留）
#
# 物理回调安全：产出常在物理碰撞回调链（body_entered → 爆炸 → on_explosion_resolved）
# 中同步触发，而 Godot 禁止在 physics flushing queries 阶段 add_child 带碰撞体的
# body（会报 "Can't change this state while flushing queries"）。因此挂载统一用
# call_deferred 延迟到物理刷新之后；未挂载实例计入 _pending，保证 active_count
# 实时正确、上限不破，且无负数计数路径。未入场景树（组合测试等）时同步挂载。
#
# 跨战斗正确性：计数用 group 实时查询 + _pending 补充（不用 tree_exited 自维护）。
# 旧台面小炸弹挂在 active_level_scene 下，BattleGateway 换台时 queue_free 整个场景
# 自动带离，group 随之清空；active_count 过滤已排入删除的节点，清场/换台计数即时归零。

extends Node
class_name ProducedMarbleSpawner

const FIELD_GROUP: StringName = &"produced_marbles"

## 已实例化但尚未挂载进场景树的弹珠（add_child 被 call_deferred 延迟）。
var _pending: Array[Node2D] = []

## 返回当前关卡父节点（main.gd 注入 Callable(self, "_current_level_scene")）。
var _level_provider: Callable = Callable()


func configure(level_provider: Callable) -> void:
	_level_provider = level_provider


## 实例化产出弹珠到当前关卡。达场上上限 / 关卡缺失 / 场景无效时返回 null（调用方跳过）。
## 返回的实例已设置好导出属性，但挂载可能被延迟到物理刷新之后（见文件头注释）。
func spawn(scene: PackedScene, position: Vector2, max_active: int) -> Node2D:
	if scene == null:
		return null
	if active_count() >= max_active:
		return null
	var parent: Node = _level_provider.call() if _level_provider.is_valid() else null
	if parent == null or not is_instance_valid(parent):
		return null
	var instance: Node2D = scene.instantiate() as Node2D
	if instance == null:
		return null
	_pending.append(instance)
	if is_inside_tree():
		# 正常游戏：deferred 挂载，避开物理查询刷新阶段改物理状态。
		# _attach_deferred 是本服务的方法，用 call_deferred 在 self 上延迟调用。
		call_deferred("_attach_deferred", parent, instance, position)
	else:
		# 未入场景树（组合测试等）：无物理刷新冲突，同步挂载。
		parent.add_child(instance)
		instance.global_position = position
		_pending.erase(instance)
	return instance


## deferred 挂载：物理刷新结束后同步执行 add_child 与位置设置。parent 已销毁时丢弃实例。
func _attach_deferred(parent: Node, instance: Node2D, position: Vector2) -> void:
	if parent == null or not is_instance_valid(parent) or parent.is_queued_for_deletion():
		_pending.erase(instance)
		if is_instance_valid(instance) and not instance.is_queued_for_deletion():
			instance.queue_free()
		return
	parent.add_child(instance)
	instance.global_position = position
	_pending.erase(instance)


## 场上现存产出弹珠数 = 未挂载 _pending + 场景树内 group 实存。
## 过滤已排入删除的节点：queue_free 后立即不计，换台/清场时计数即时归零，无负数。
func active_count() -> int:
	var count: int = 0
	for node: Node2D in _pending:
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			count += 1
	if not is_inside_tree():
		return count
	for node: Node in get_tree().get_nodes_in_group(FIELD_GROUP):
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion() \
				and not _pending.has(node):
			count += 1
	return count


## 遍历 group 清场（战斗开始防御性清场），未挂载 _pending 一并丢弃。
func clear_field() -> void:
	for node: Node2D in _pending:
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()
	_pending.clear()
	if not is_inside_tree():
		return
	for node: Node in get_tree().get_nodes_in_group(FIELD_GROUP).duplicate():
		if node != null and is_instance_valid(node) and not node.is_queued_for_deletion():
			node.queue_free()


## 直接连接 battle_started（信号 2 参：token, plan），多余参数忽略。
func reset_for_battle(_token: Variant = null, _plan: Variant = null) -> void:
	clear_field()
