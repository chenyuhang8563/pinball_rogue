extends Panel

const SHOP_MODE_ON := 0

@export var item: Item = null:
	set(value):
		item = value

		if value == null:
			$Icon.texture = null
			return

		$Icon.texture = value.icon
		$Price.text = "$ " + str(value.price)

func _on_gui_input(event) -> void:
	if not event is InputEventMouseButton:
		return
	if not event.is_pressed() or event.button_index != MOUSE_BUTTON_LEFT:
		return

	var shop: Node = _get_autoload_node(&"Shop")
	if shop == null or shop.get("mode") != SHOP_MODE_ON:
		return

	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null:
		return

	if shop.has_method("purchase_item"):
		if shop.call("purchase_item", item):
			print("Bought " + item.title)
		return


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))
