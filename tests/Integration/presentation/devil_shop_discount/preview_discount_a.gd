extends Node


## 预览场景 A：恶魔商店折扣报价，原价为 2 位数（30 → 20），
## 用于截图检查 DiscountSlash 红色划线与原价数字的对齐。
func _ready() -> void:
	var executor := get_node_or_null("/root/GameExecutor")
	if executor != null:
		executor.process_mode = Node.PROCESS_MODE_ALWAYS
	await get_tree().process_frame
	var shop: Control = $DevilShop
	shop.show()
	var item := Item.new()
	item.id = "test_relic"
	item.title = "Test Relic"
	item.type = Item.ItemType.RELIC
	item.icon = load("res://Assets/Items/Coin.png")
	var offer := DevilShopOffer.new(item, 2, 20, true, 30)
	offer.offer_id = &"preview_discount_a"
	var slot := shop.get_node("OfferPan/OfferSlot")
	slot.set_offer(offer)
