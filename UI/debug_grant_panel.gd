class_name DebugGrantPanel
extends Control

signal skip_battle_requested
signal grant_requested(item_id: StringName)

const DEBUG_PANEL_ACTION: StringName = &"toggle_debug_cheats"
const DebugGrantServiceScript: GDScript = preload("res://Debug/debug_grant_service.gd")

@onready var _category_option: OptionButton = $Center/Panel/Margin/Layout/CategoryRow/CategoryOption
@onready var _item_option: OptionButton = $Center/Panel/Margin/Layout/ItemRow/ItemOption
@onready var _status_label: Label = $Center/Panel/Margin/Layout/StatusLabel
@onready var _visibility_player: AnimationPlayer = $VisibilityPlayer

var _item_ids: PackedStringArray = []


func _ready() -> void:
	if not OS.is_debug_build():
		return
	_bind_signals()


func _unhandled_input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event.is_action_pressed(DEBUG_PANEL_ACTION) and not event.is_echo():
		toggle()
		get_viewport().set_input_as_handled()


func configure_items(item_ids: PackedStringArray) -> void:
	_item_ids = item_ids
	_refresh_item_options()


func toggle() -> void:
	_visibility_player.play(&"hide" if visible else &"show")


func present_result(message: String) -> void:
	_status_label.text = message


func _bind_signals() -> void:
	if not _category_option.item_selected.is_connected(_on_category_selected):
		_category_option.item_selected.connect(_on_category_selected)
	var grant_button: Button = $Center/Panel/Margin/Layout/GrantButton
	if not grant_button.pressed.is_connected(_on_grant_pressed):
		grant_button.pressed.connect(_on_grant_pressed)
	var skip_button: Button = $Center/Panel/Margin/Layout/SkipBattleButton
	if not skip_button.pressed.is_connected(skip_battle_requested.emit):
		skip_button.pressed.connect(skip_battle_requested.emit)


func _on_category_selected(_index: int) -> void:
	_refresh_item_options()


func _on_grant_pressed() -> void:
	if _item_option.selected < 0:
		return
	grant_requested.emit(StringName(_item_option.get_item_metadata(_item_option.selected)))


func _refresh_item_options() -> void:
	_item_option.clear()
	var selected_type: int = _category_option.get_selected_id()
	for item_id: String in _item_ids:
		var item := _item_from_id(item_id)
		if item != null and int(item.type) == selected_type:
			_item_option.add_item(item_id)
			_item_option.set_item_metadata(_item_option.item_count - 1, item_id)
	if _item_option.item_count > 0:
		_item_option.select(0)


func _item_from_id(item_id: String) -> Item:
	for path: String in DebugGrantServiceScript.ITEM_PATHS:
		var item := load(path) as Item
		if item != null and item.id == item_id:
			return item
	return null
