extends Control
class_name InventoryPanel

signal upgrade_intent(
	token: RunFlowToken,
	offer_id: StringName,
	candidate_id: StringName
)
signal upgrade_unavailable_intent(token: RunFlowToken, offer_id: StringName)

const ItemLevelResolverScript: GDScript = preload("res://UI/item_level_resolver.gd")

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
var _upgrade_intent_sent: bool = false
var _active_upgrade_offer: UpgradeOffer = null
var _upgrade_dialog: SkillReplaceDialog = null
var _loadout: RefCounted = null
var _progression: RefCounted = null


func configure(loadout: RefCounted, progression: RefCounted) -> bool:
	unconfigure()
	if not _has_port_api(loadout, [&"marbles", &"relics", &"skills"]) \
			or not _has_port_api(progression, [&"level_of"]):
		return false
	_loadout = loadout
	_progression = progression
	_connect_port_signals()
	refresh_inventory()
	return true


func unconfigure() -> void:
	_disconnect_port_signals()
	_reset_upgrade_dialog()
	_active_upgrade_offer = null
	_upgrade_intent_sent = false
	_upgrade_selection_active = false
	_loadout = null
	_progression = null
	mode = MODE.OFF
	refresh_inventory()


func _ready() -> void:
	_ensure_toggle_action()
	_connect_localization()
	_apply_text()
	_setup_upgrade_dialog()
	_connect_port_signals()
	refresh_inventory()
	mode = MODE.OFF


func _exit_tree() -> void:
	_disconnect_port_signals()


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
		if _active_upgrade_offer != null and _active_upgrade_offer.unavailable \
				and not _upgrade_intent_sent:
			_upgrade_intent_sent = true
			upgrade_unavailable_intent.emit(
				_active_upgrade_offer.token,
				_active_upgrade_offer.offer_id
			)
		return
	mode = MODE.OFF


func present_upgrade_offer(offer: UpgradeOffer) -> bool:
	if offer == null or not offer.is_valid() or offer.consumed:
		return false
	_active_upgrade_offer = offer
	_upgrade_intent_sent = false
	_upgrade_selection_active = true
	mode = MODE.ON
	_set_upgrade_title()
	return true


func finish_upgrade_selection() -> void:
	_reset_upgrade_dialog()
	_active_upgrade_offer = null
	_upgrade_intent_sent = false
	_upgrade_selection_active = false
	mode = MODE.OFF


func refresh_inventory() -> void:
	if _loadout == null or not is_instance_valid(_loadout):
		_update_collection_icons(marble_box_container, [])
		_update_collection_icons(relic_bar_container, [])
		_update_skill_slots()
		return

	var marble_items: Array = _loadout.call("marbles") as Array
	var relic_items: Array = _loadout.call("relics") as Array
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
		if is_inside_tree():
			get_tree().paused = true
	else:
		ui_layer.hide()
		if is_inside_tree():
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
		_set_icon_view_level(icon_view, ItemLevelResolverScript.get_inventory_level(item, _progression))


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
			_set_icon_view_level(icon_view, ItemLevelResolverScript.get_inventory_level(item, _progression))
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
	var item: Item = slot.get_meta("item") as Item
	var candidate: UpgradeCandidate = _candidate_for_item(item)
	if item == null or candidate == null or _upgrade_intent_sent:
		return
	get_viewport().set_input_as_handled()
	if _upgrade_dialog != null:
		_upgrade_dialog.request_upgrade(item)


func _setup_upgrade_dialog() -> void:
	_upgrade_dialog = get_node_or_null("UI/SkillReplaceDialog") as SkillReplaceDialog
	if _upgrade_dialog != null and not _upgrade_dialog.upgrade_confirmed.is_connected(_on_upgrade_confirmed):
		_upgrade_dialog.upgrade_confirmed.connect(_on_upgrade_confirmed)


func _reset_upgrade_dialog() -> void:
	if _upgrade_dialog == null or not is_instance_valid(_upgrade_dialog):
		_setup_upgrade_dialog()
	if _upgrade_dialog != null:
		_upgrade_dialog.reset_pending()


func _on_upgrade_confirmed(item: Item) -> void:
	var candidate: UpgradeCandidate = _candidate_for_item(item)
	if candidate == null or _active_upgrade_offer == null or _upgrade_intent_sent:
		return
	_upgrade_intent_sent = true
	upgrade_intent.emit(
		_active_upgrade_offer.token,
		_active_upgrade_offer.offer_id,
		candidate.candidate_id
	)


func _candidate_for_item(item: Item) -> UpgradeCandidate:
	if item == null or _active_upgrade_offer == null or _active_upgrade_offer.consumed:
		return null
	var instance_id: int = item.get_instance_id()
	for candidate: UpgradeCandidate in _active_upgrade_offer.candidates():
		if candidate != null and candidate.owned_instance_id == instance_id:
			return candidate
	return null


func _set_upgrade_title() -> void:
	var title_label := get_node_or_null("UI/Panel/MarginContainer/Layout/Header/TitleLabel") as Label
	if title_label != null:
		title_label.text = tr("UI_UPGRADE_INVENTORY_TITLE")


func _get_skill_slot_sources() -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	if _loadout == null or not is_instance_valid(_loadout):
		return sources
	for value: Variant in _loadout.call("skills") as Array:
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


func _connect_port_signals() -> void:
	var refresh_callback := Callable(self, "refresh_inventory")
	if _loadout != null and is_instance_valid(_loadout) and _loadout.has_signal(&"changed") \
			and not _loadout.is_connected(&"changed", refresh_callback):
		_loadout.connect(&"changed", refresh_callback)
	var item_callback := Callable(self, "_on_item_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"item_progressed") \
			and not _progression.is_connected(&"item_progressed", item_callback):
		_progression.connect(&"item_progressed", item_callback)
	var skill_callback := Callable(self, "_on_skill_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"skill_progressed") \
			and not _progression.is_connected(&"skill_progressed", skill_callback):
		_progression.connect(&"skill_progressed", skill_callback)


func _disconnect_port_signals() -> void:
	var refresh_callback := Callable(self, "refresh_inventory")
	if _loadout != null and is_instance_valid(_loadout) and _loadout.has_signal(&"changed") \
			and _loadout.is_connected(&"changed", refresh_callback):
		_loadout.disconnect(&"changed", refresh_callback)
	var item_callback := Callable(self, "_on_item_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"item_progressed") \
			and _progression.is_connected(&"item_progressed", item_callback):
		_progression.disconnect(&"item_progressed", item_callback)
	var skill_callback := Callable(self, "_on_skill_progressed")
	if _progression != null and is_instance_valid(_progression) \
			and _progression.has_signal(&"skill_progressed") \
			and _progression.is_connected(&"skill_progressed", skill_callback):
		_progression.disconnect(&"skill_progressed", skill_callback)


func _on_item_progressed(_item: Item, _level: int, _awakened: bool) -> void:
	refresh_inventory()


func _on_skill_progressed(_skill_id: String, _level: int) -> void:
	refresh_inventory()


func _has_port_api(port: RefCounted, methods: Array[StringName]) -> bool:
	if port == null or not is_instance_valid(port):
		return false
	for method: StringName in methods:
		if not port.has_method(method):
			return false
	return true


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
