extends GutTest

const MarbleChainScript: GDScript = preload("res://Combat/marbles/marble_chain.gd")


func test_first_equipped_marble_defines_head_type() -> void:
	# 问题来源：卖出黑色弹珠后，战斗链首颗非默认弹珠仍被创建为黑色 Head。
	# 修复方式与边界：Head 必须采用装备序列首项的类型；单颗非默认弹珠也必须保持其类型。
	var chain: MarbleChain = MarbleChainScript.new()
	add_child_autofree(chain)
	var only_bomb := _marble("only_bomb", Marble.MARBLE_TYPE.BOMB)

	chain.build_chain([only_bomb], [Vector2(56, 96)])

	assert_not_null(chain.head)
	assert_eq(chain.head.marble_type, Marble.MARBLE_TYPE.BOMB)
	assert_eq(chain.body.size(), 0)


func _marble(id: String, marble_type: Marble.MARBLE_TYPE) -> Item:
	var item := Item.new()
	item.id = id
	item.type = Item.ItemType.MARBLE
	item.marble_type = marble_type
	return item
