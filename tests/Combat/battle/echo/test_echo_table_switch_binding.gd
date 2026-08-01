extends GutTest

## 复现：只有第一场战斗有蓄力颜色变化、后续战斗失效。
## 模拟 BattleGateway 换桌时序：旧 TableBase queue_free → 新 TableBase 实例化
## （控制器 _ready）→ reset_battle 重建链（build_chain 重新绑定控制器）。

const TableBaseScene: PackedScene = preload("res://Combat/levels/table_base.tscn")


func test_charge_driving_survives_table_switch() -> void:
	var table1: Node = TableBaseScene.instantiate()
	add_child_autofree(table1)
	var chain_a := MarbleChain.new()
	add_child_autofree(chain_a)
	chain_a.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(56, 96)])
	var controller1 := table1.get_node("EchoCharge")

	chain_a.chain_collision.emit(self, "enemy")
	assert_eq(controller1.get_progress(), 0.25, "第一场战斗：命中敌人累计 1/4 层")
	chain_a.chain_collision.emit(self, "enemy")
	assert_eq(controller1.get_progress(), 0.5, "第一场战斗：继续累计")

	# 换桌：旧表释放 + 新表实例化（同一帧，模拟 BattleGateway.start 时序）
	table1.queue_free()
	var table2: Node = TableBaseScene.instantiate()
	add_child_autofree(table2)
	# 掉球/开战重建链：旧链清理 + 新链创建并重新绑定
	chain_a.queue_free()
	var chain_b := MarbleChain.new()
	add_child_autofree(chain_b)
	chain_b.build_chain([_marble(Marble.MARBLE_TYPE.BROWN)], [Vector2(56, 96)])
	var controller2 := table2.get_node("EchoCharge")

	chain_b.chain_collision.emit(self, "enemy")
	assert_eq(controller2.get_progress(), 0.25, "第二场战斗：新控制器应收到新链的敌人碰撞充能")
	chain_b.chain_collision.emit(self, "enemy")
	assert_eq(controller2.get_progress(), 0.5, "再次命中仍充能（控制器绑定的是新链而非旧链）")


func _marble(marble_type: int) -> Item:
	var item := Item.new()
	item.id = "echo_switch_test"
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	item.marble_segment_damage = 5
	return item
