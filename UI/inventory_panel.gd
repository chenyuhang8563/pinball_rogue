extends Control
class_name InventoryPanel

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const LevelBadgeScript: GDScript = preload("res://UI/level_badge.gd")
const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")

@export var toggle_action: StringName = &"toggle_inventory"
@export var skill_slot_count: int = 3
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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layout_direction = Control.LAYOUT_DIRECTION_LOCALE
	_ensure_toggle_action()
	_apply_text()
	_apply_button_label_settings()
	_ensure_skill_slots()
	_connect_inventory()
	refresh_inventory()
	mode = MODE.OFF


func _input(event: InputEvent) -> void:
	if not _is_toggle_event(event):
		return

	mode = MODE.OFF if mode == MODE.ON else MODE.ON
	get_viewport().set_input_as_handled()


func is_open() -> bool:
	var ui_layer: CanvasLayer = get_node_or_null("UI") as CanvasLayer
	return mode == MODE.ON and ui_layer != null and ui_layer.visible


func close_inventory() -> void:
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


func _apply_text() -> void:
	var title_label: Label = get_node_or_null("UI/Panel/MarginContainer/Layout/Header/TitleLabel") as Label
	if title_label != null:
		title_label.text = tr("Inventory")

	var skill_label: Label = get_node_or_null("UI/Panel/MarginContainer/Layout/Content/SkillLabel") as Label
	if skill_label != null:
		skill_label.text = tr("Skills")

	var exit_button: Button = get_node_or_null("UI/Panel/MarginContainer/Layout/Header/ExitButton") as Button
	if exit_button != null:
		exit_button.text = tr("Exit")
		if not exit_button.pressed.is_connected(close_inventory):
			exit_button.pressed.connect(close_inventory)


func _apply_button_label_settings() -> void:
	var exit_button: Button = get_node_or_null("UI/Panel/MarginContainer/Layout/Header/ExitButton") as Button
	if exit_button == null:
		return
	if UI_LABEL_SETTINGS.font != null:
		exit_button.add_theme_font_override("font", UI_LABEL_SETTINGS.font)
	exit_button.add_theme_font_size_override("font_size", UI_LABEL_SETTINGS.font_size)


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
		var slot_control: Control = slot as Control
		var icon := slot.get_node_or_null("Icon") as TextureRect
		if icon == null:
			continue

		if slot.has_meta("item"):
			slot.remove_meta("item")
		icon.texture = null
		LevelBadgeScript.clear_badge(slot_control)

		if index >= collection_items.size():
			continue
		var item: Item = collection_items[index] as Item
		if item == null:
			continue
		slot.set_meta("item", item)
		icon.texture = item.icon
		LevelBadgeScript.update_badge(slot_control, ItemLevelResolverScript.get_inventory_level(item))


func _ensure_skill_slots() -> void:
	if skill_bar_container == null:
		return
	while skill_bar_container.get_child_count() < skill_slot_count:
		skill_bar_container.add_child(_make_skill_slot(skill_bar_container.get_child_count() + 1))


func _make_skill_slot(index: int) -> Panel:
	var slot := Panel.new()
	slot.name = "SkillSlot%d" % index
	slot.custom_minimum_size = Vector2(32, 32)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)
	return slot


func _update_skill_slots() -> void:
	if skill_bar_container == null:
		return

	var skill_sources: Array[Dictionary] = _get_skill_slot_sources()
	for index: int in range(skill_bar_container.get_child_count()):
		var slot := skill_bar_container.get_child(index)
		var icon := slot.get_node_or_null("Icon") as TextureRect
		if icon == null:
			continue
		icon.texture = null
		LevelBadgeScript.clear_badge(slot as Control)
		if slot.has_meta("skill_source"):
			slot.remove_meta("skill_source")
		if index >= skill_sources.size():
			continue
		var source: Dictionary = skill_sources[index]
		icon.texture = source.get("icon") as Texture2D
		if source.has("source_path"):
			slot.set_meta("skill_source", source["source_path"])


func _get_skill_slot_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	var tree: SceneTree = get_tree()
	if tree == null or tree.current_scene == null:
		return sources

	var skill_slot: Node = tree.current_scene.get_node_or_null("CrtLayer/SkillSlot")
	if skill_slot == null:
		return sources

	var icon: TextureRect = skill_slot.get_node_or_null("Icon") as TextureRect
	sources.append({
		"icon": icon.texture if icon != null else null,
		"source_path": str(skill_slot.get_path()),
	})
	return sources


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
