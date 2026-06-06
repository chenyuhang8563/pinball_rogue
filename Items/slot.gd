extends Panel

@export var item: Item = null:
	set(value):
		item = value

		if value == null:
			$Icon.texture = null
			return

		$Icon.texture = value.icon
		$Price.text = "$ " + str(value.price)

func _on_gui_input(event) -> void:
	if event is InputEventMouseButton and Shop.mode == Shop.MODE.ON:
		if event.is_pressed() and event.button_index == MOUSE_BUTTON_LEFT:
			if Shop.buy_item(item):
				print("Bought " + item.title)
				Inventory.add_item(item)