extends Control
class_name InventoryPanel

signal upgrade_item_selected(item: Item)

const UIFontsScript: GDScript = preload("res://UI/fonts.gd")
const UI_FONT_SIZE: int = 12
const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")
const UpgradeDialogScene: PackedScene = preload("res://UI/skill_replace_dialog.tscn")

@export var toggle_action: StringName = &"toggle_inventory"
@export var skill_slot_count: int = 1
@export var marble_box_container: HBoxContainer
@export var relic_bar_container: HBoxContainer
@export var skill_bar_container: HBoxContainer

enum MODE {
	ON,
	OFF
}

var mode: MODE = MODE.OFF:
	set(value):
		mode = value
		_apply_mode()

var _upgrade_selection_active: bool = false
var _upgrade_dialog: SkillReplaceDialog = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layout_direction = Control.LAYOUT_DIRECTION_LOCALE
	_ensure_toggle_action()
	_connect_localization()
	_apply_text()
	_apply_button_label_settings()
	_setup_upgrade_dialog()
	_connect_inventory()
	refresh_inventory()
	mode = MODE.OFF


func _input(event: InputEvent) -> void:
	if not _is_toggle_event(event):
		return
	if _upgrade_selection_active:
		get_viewport().set_input_as_handled()
		return

	mode = MODE.OFF if mode == MODE.ON else MODE.ON
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	var ui_layer: CanvasLayer = get_node_or_null("UI") as CanvasLayer
	return mode == MODE.ON and ui_layer != null and ui_layer.visible


func close_inventory() -> void:
	if _upgrade_selection_active:
		return
	mode = MODE.OFF


func show_upgrade_selection() -> void:
	_upgrade_selection_active = true
	mode = MODE.ON
	_set_upgrade_title()


func finish_upgrade_selection() -> void:
	_upgrade_selection_active = false
	mode = MODE.OFF


func refresh_inventory() -> void:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null:
		_update_collection_icons(marble_box_container, [])
		_update_collection_icons(relic_bar_container, [])
		_update_skill_slots()
		return

	var raw_marble_items: Variant = inventory.get("marble_items")
	var raw_relic_items: Variant = inventory.get("relic_items")
	var marble_items: Array = raw_marble_items if raw_marble_items is Array else []
	var relic_items: Array = raw_relic_items if raw_relic_items is Array else []
	_update_collection_icons(marble_box_container, marble_items)
	_update_collection_icons(relic_bar_container, relic_items)
	_update_skill_slots()


func _apply_mode() -> void:
	var ui_layer: CanvasLayer = get_node_or_null("UI") as CanvasLayer
	if ui_layer == null:
		return

	if mode == MODE.ON:
		refresh_inventory()
		ui_layer.show()
		get_tree().paused = true
	else:
		ui_layer.hide()
		get_tree().paused = false
	if _upgrade_selection_active:
		_set_upgrade_title()
	else:
		_apply_text()


func _apply_text() -> void:
	var title_label: Label = get_node_or_null("UI/Panel/MarginContainer/Layout/Header/TitleLabel") as Label
	if title_label != null:
		title_label.text = tr("UI_INVENTORY_TITLE")

	var skill_label: Label = get_node_or_null("UI/Panel/MarginContainer/Layout/Content/SkillLabel") as Label
	if skill_label != null:
		skill_label.text = tr("UI_SKILLS_TITLE")

	var exit_button: Button = get_node_or_null("UI/Panel/MarginContainer/Layout/Header/ExitButton") as Button
	if exit_button != null:
		exit_button.text = tr("UI_EXIT")
		if not exit_button.pressed.is_connected(close_inventory):
			exit_button.pressed.connect(close_inventory)


func _apply_button_label_settings() -> void:
	var exit_button: Button = get_node_or_null("UI/Panel/MarginContainer/Layout/Header/ExitButton") as Button
	if exit_button == null:
		return
	UIFontsScript.apply_button_font(exit_button, UI_FONT_SIZE)


func _ensure_toggle_action() -> void:
	if not InputMap.has_action(toggle_action):
		InputMap.add_action(toggle_action)
	if _action_has_key(toggle_action, KEY_B):
		return
	var event := InputEventKey.new()
	event.physical_keycode = KEY_B
	InputMap.action_add_event(toggle_action, event)


func _action_has_key(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event: InputEventKey = event as InputEventKey
			if key_event.keycode == key or key_event.physical_keycode == key:
				return true
	return false


func _is_toggle_event(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return false
	if InputMap.has_action(toggle_action) and key_event.is_action_pressed(toggle_action):
		return true
	return key_event.keycode == KEY_B or key_event.physical_keycode == KEY_B


func _update_collection_icons(container: HBoxContainer, collection_items: Array) -> void:
	if container == null:
		return

	for index: int in range(container.get_child_count()):
		var slot := container.get_child(index)
		if not slot is Control:
			continue
		var icon_view := _get_icon_view(slot)
		if icon_view == null:
			continue

		if slot.has_meta("item"):
			slot.remove_meta("item")
		_clear_icon_view(icon_view)

		if index >= collection_items.size():
			continue
		var item: Item = collection_items[index] as Item
		if item == null:
			continue
		slot.set_meta("item", item)
		_connect_slot(slot)
		_set_icon_view_texture(icon_view, item.icon)
		_set_icon_view_level(icon_view, ItemLevelResolverScript.get_inventory_level(item))


func _update_skill_slots() -> void:
	if skill_bar_container == null:
		return

	var skill_sources: Array[Dictionary] = _get_skill_slot_sources()
	for index: int in range(skill_bar_container.get_child_count()):
		var slot := skill_bar_container.get_child(index)
		var icon_view := _get_icon_view(slot)
		if icon_view == null:
			continue
		_clear_icon_view(icon_view)
		if slot.has_meta("item"):
			slot.remove_meta("item")
		if index >= skill_sources.size():
			continue
		var source: Dictionary = skill_sources[index]
		_set_icon_view_texture(icon_view, source.get("icon") as Texture2D)
		if source.has("item"):
			var item := source["item"] as Item
			slot.set_meta("item", item)
			_set_icon_view_level(icon_view, ItemLevelResolverScript.get_inventory_level(item))
			_connect_slot(slot)


func _connect_slot(slot: Node) -> void:
	if slot == null or not slot is Control:
		return
	var callback := Callable(self, "_on_slot_gui_input").bind(slot)
	if not (slot as Control).gui_input.is_connected(callback):
		(slot as Control).gui_input.connect(callback)


func _on_slot_gui_input(event: InputEvent, slot: Node) -> void:
	if not _upgrade_selection_active or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed or not slot.has_meta("item"):
		return
	var item := slot.get_meta("item") as Item
	var system := _get_upgrade_system()
	var inventory := _get_autoload_node(&"Inventory")
	if item == null or system == null or not system.has_method("can_upgrade_item"):
		return
	if not bool(system.call("can_upgrade_item", item, inventory)):
		if _upgrade_dialog != null:
			_upgrade_dialog.request_upgrade_unavailable(item)
		return
	get_viewport().set_input_as_handled()
	if _upgrade_dialog != null:
		_upgrade_dialog.request_upgrade(item)


func _setup_upgrade_dialog() -> void:
	var ui_layer := get_node_or_null("UI") as CanvasLayer
	if ui_layer == null:
		return
	_upgrade_dialog = UpgradeDialogScene.instantiate() as SkillReplaceDialog
	if _upgrade_dialog == null:
		return
	ui_layer.add_child(_upgrade_dialog)
	_upgrade_dialog.upgrade_confirmed.connect(_on_upgrade_confirmed)


func _on_upgrade_confirmed(item: Item) -> void:
	upgrade_item_selected.emit(item)


func _set_upgrade_title() -> void:
	var title_label := get_node_or_null("UI/Panel/MarginContainer/Layout/Header/TitleLabel") as Label
	if title_label != null:
		title_label.text = tr("UI_UPGRADE_INVENTORY_TITLE")


func _get_upgrade_system() -> Node:
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	return tree.current_scene.get_node_or_null("RunController/MarbleUpgradeSystem")


func _get_skill_slot_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null:
		return sources
	var raw_skill_items: Variant = inventory.get("skill_items")
	if not raw_skill_items is Array:
		return sources
	for value: Variant in raw_skill_items:
		var item := value as Item
		if item != null:
			sources.append({"icon": item.icon, "item": item})
	return sources


func _get_icon_view(slot: Node) -> Node:
	if slot == null:
		return null
	return slot.get_node_or_null("Icon")


func _set_icon_view_texture(icon_view: Node, texture: Texture2D) -> void:
	if icon_view == null:
		return
	if icon_view.has_method("set_texture"):
		icon_view.call("set_texture", texture)
	elif icon_view is TextureRect:
		var texture_rect := icon_view as TextureRect
		texture_rect.texture = texture
		texture_rect.visible = texture != null


func _set_icon_view_level(icon_view: Node, level: int) -> void:
	if icon_view != null and icon_view.has_method("set_level"):
		icon_view.call("set_level", level)


func _clear_icon_view(icon_view: Node) -> void:
	if icon_view == null:
		return
	if icon_view.has_method("clear"):
		icon_view.call("clear")
	elif icon_view is TextureRect:
		var texture_rect := icon_view as TextureRect
		texture_rect.texture = null
		texture_rect.hide()


func _get_icon_view_texture(icon_view: Node) -> Texture2D:
	if icon_view == null:
		return null
	if icon_view.has_method("get_texture"):
		return icon_view.call("get_texture") as Texture2D
	if icon_view is TextureRect:
		return (icon_view as TextureRect).texture
	return null


func _connect_inventory() -> void:
	var inventory: Node = _get_autoload_node(&"Inventory")
	if inventory == null or not inventory.has_signal(&"inventory_changed"):
		return
	var callable := Callable(self, "refresh_inventory")
	if not inventory.is_connected(&"inventory_changed", callable):
		inventory.connect(&"inventory_changed", callable)


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _connect_localization() -> void:
	var localization := _get_autoload_node(&"Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback := Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	_apply_text()
	refresh_inventory()
