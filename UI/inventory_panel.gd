extends Control
class_name InventoryPanel

const UI_LABEL_SETTINGS: LabelSettings = preload("res://Themes/new_label_settings.tres")
const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")
const InventoryIconSlotScene: PackedScene = preload("res://UI/inventory_icon_slot.tscn")

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
	_connect_localization()
	_apply_text()
	_setup_language_button()
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
		title_label.text = tr("UI_INVENTORY_TITLE")

	var skill_label: Label = get_node_or_null("UI/Panel/MarginContainer/Layout/Content/SkillLabel") as Label
	if skill_label != null:
		skill_label.text = tr("UI_SKILLS_TITLE")

	var exit_button: Button = get_node_or_null("UI/Panel/MarginContainer/Layout/Header/ExitButton") as Button
	if exit_button != null:
		exit_button.text = tr("UI_EXIT")
		if not exit_button.pressed.is_connected(close_inventory):
			exit_button.pressed.connect(close_inventory)


func _setup_language_button() -> void:
	var language_button: OptionButton = get_node_or_null("UI/Panel/MarginContainer/Layout/Header/LanguageButton") as OptionButton
	if language_button == null:
		return
	language_button.clear()
	var locales := _get_supported_locales()
	for locale: Dictionary in locales:
		language_button.add_item(String(locale.get("name", locale.get("code", ""))))
	var callback := Callable(self, "_on_language_selected")
	if not language_button.item_selected.is_connected(callback):
		language_button.item_selected.connect(callback)
	_sync_language_button()
	language_button.add_theme_font_size_override(&"font_size", 12)
	language_button.get_popup().add_theme_font_size_override(&"font_size", 12)


func _on_language_selected(index: int) -> void:
	var locales := _get_supported_locales()
	if index < 0 or index >= locales.size():
		return
	var localization := _get_localization()
	var locale_code := String(locales[index].get("code", "zh_CN"))
	if localization != null and localization.has_method("set_locale"):
		localization.call("set_locale", locale_code)
	else:
		TranslationServer.set_locale(locale_code)
		_apply_text()


func _sync_language_button() -> void:
	var language_button: OptionButton = get_node_or_null("UI/Panel/MarginContainer/Layout/Header/LanguageButton") as OptionButton
	if language_button == null:
		return
	var locales := _get_supported_locales()
	var current_locale := _current_locale()
	for index: int in range(locales.size()):
		if String(locales[index].get("code", "")) == current_locale:
			language_button.select(index)
			return


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
		_set_icon_view_texture(icon_view, item.icon)
		_set_icon_view_level(icon_view, ItemLevelResolverScript.get_inventory_level(item))


func _ensure_skill_slots() -> void:
	if skill_bar_container == null:
		return
	while skill_bar_container.get_child_count() < skill_slot_count:
		skill_bar_container.add_child(_make_skill_slot(skill_bar_container.get_child_count() + 1))


func _make_skill_slot(index: int) -> Panel:
	var slot := InventoryIconSlotScene.instantiate() as Panel
	slot.name = "SkillSlot%d" % index
	return slot


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
		if slot.has_meta("skill_source"):
			slot.remove_meta("skill_source")
		if index >= skill_sources.size():
			continue
		var source: Dictionary = skill_sources[index]
		_set_icon_view_texture(icon_view, source.get("icon") as Texture2D)
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

	var icon: Node = skill_slot.get_node_or_null("Icon")
	sources.append({
		"icon": _get_icon_view_texture(icon),
		"source_path": str(skill_slot.get_path()),
	})
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
	var localization := _get_localization()
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback := Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	_apply_text()
	_sync_language_button()
	refresh_inventory()


func _get_supported_locales() -> Array[Dictionary]:
	var localization := _get_localization()
	if localization != null and localization.has_method("get_supported_locales"):
		var locales: Variant = localization.call("get_supported_locales")
		if locales is Array:
			var typed_locales: Array[Dictionary] = []
			for locale: Variant in locales:
				if locale is Dictionary:
					typed_locales.append(locale)
			return typed_locales
	return [
		{"code": "zh_CN", "name": "中文"},
		{"code": "en", "name": "English"},
	]


func _current_locale() -> String:
	var localization := _get_localization()
	if localization != null and localization.has_method("get_locale"):
		return String(localization.call("get_locale"))
	return "en" if TranslationServer.get_locale() == "en" else "zh_CN"


func _get_localization() -> Node:
	return _get_autoload_node(&"Localization")
