extends Panel

const SHOP_MODE_ON := 0
const ItemTooltipScene: PackedScene = preload("res://UI/item_tooltip.tscn")

var _tooltip: Control

@export var item: Item = null:
	set(value):
		item = value

		if value == null:
			$Icon.texture = null
			return

		$Icon.texture = value.icon
		$Price.text = "$ " + str(value.price)


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

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


func _on_mouse_entered() -> void:
	if item == null:
		return
	var tooltip: Control = _get_or_create_tooltip()
	if tooltip.has_method("show_item_for_control"):
		tooltip.call("show_item_for_control", item, self)


func _on_mouse_exited() -> void:
	if _tooltip != null:
		if _tooltip.has_method("hide_tooltip"):
			_tooltip.call("hide_tooltip")


func _get_or_create_tooltip() -> Control:
	if _tooltip != null and is_instance_valid(_tooltip):
		return _tooltip

	_tooltip = ItemTooltipScene.instantiate() as Control
	_tooltip.name = "ItemTooltip"
	var tooltip_parent: Node = _get_tooltip_parent()
	tooltip_parent.add_child(_tooltip)
	return _tooltip


func _get_tooltip_parent() -> Node:
	var crt_layer: Node = _get_scene_crt_layer()
	if crt_layer != null:
		return crt_layer

	var node: Node = self
	while node != null:
		if node is CanvasLayer:
			return node
		node = node.get_parent()
	return get_tree().root


func _get_scene_crt_layer() -> Node:
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("CrtLayer")
