extends Control

@export var shop_slot_node: PackedScene = preload("res://Items/slot.tscn")
@export var shop_items: Array[Item] = []
@export var shop_container: GridContainer
var gold: int = 0:
	set(value):
		gold = value
		$UI/Coins.text = "Gold: " + str(value)

enum MODE {
	ON,
	OFF
}

var mode: MODE = MODE.OFF:
	set(value):
		mode = value
		if value == MODE.ON:
			$UI.show()
			get_tree().paused = true
			#if inventory
			#Inventory.grid.show()
		elif value == MODE.OFF:
			$UI.hide()
			get_tree().paused = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$UI.hide()
	set_initial_gold()
	load_shop_inventory()

func _input(event) -> void:
	if event is InputEventKey and event.is_pressed():
		if event.keycode == KEY_U:
			if mode == MODE.ON:
				mode = MODE.OFF
			elif mode == MODE.OFF:
				mode = MODE.ON

func sell_item(item: Item) -> void:
	if item == null:
		return
	gold += item.price

func buy_item(item: Item) -> bool:
	if item == null:
		return false

	if item.price > gold:
		return false
	
	gold -= item.price
	return true

func free_previous_slots():
	for slot in shop_container.get_children():
		slot.free()

func load_shop_inventory():
	for item in shop_items:
		var shop_slot = shop_slot_node.instantiate() as Panel
		shop_container.add_child(shop_slot)
		shop_slot.item = item

func set_shop_inventory(list: Array[Item]):
	free_previous_slots()
	shop_items = list
	load_shop_inventory()

func set_initial_gold():
	gold = 100
