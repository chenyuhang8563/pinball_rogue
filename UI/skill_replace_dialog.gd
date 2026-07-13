extends Control
class_name SkillReplaceDialog

signal confirmed(new_skill: Item)
signal cancelled
signal upgrade_confirmed(item: Item)
signal upgrade_notice_dismissed

@onready var _message_label: Label = $Center/Panel/Margin/Layout/Message
@onready var _confirm_button: Button = $Center/Panel/Margin/Layout/Buttons/Confirm
@onready var _cancel_button: Button = $Center/Panel/Margin/Layout/Buttons/Cancel
@onready var _animation_player: AnimationPlayer = $AnimationPlayer

var _pending_skill: Item = null
var _pending_upgrade: Item = null
var _upgrade_notice_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)


func request_replace(current_skill: Item, new_skill: Item) -> void:
	_pending_skill = new_skill
	var current_name := _item_title(current_skill)
	var next_name := _item_title(new_skill)
	_message_label.text = tr("UI_REPLACE_SKILL_CONFIRM") % [current_name, next_name]
	_confirm_button.text = tr("UI_CONFIRM")
	_cancel_button.text = tr("UI_CANCEL")
	_animation_player.play("show_dialog")
	_confirm_button.grab_focus()


func is_request_pending() -> bool:
	return _pending_skill != null


func request_upgrade(item: Item) -> void:
	_pending_upgrade = item
	_upgrade_notice_active = false
	_message_label.text = tr("UI_UPGRADE_ITEM_CONFIRM") % [_item_title(item)]
	_confirm_button.text = tr("UI_CONFIRM")
	_cancel_button.text = tr("UI_CANCEL")
	_animation_player.play("show_dialog")
	_confirm_button.grab_focus()


func request_upgrade_unavailable(item: Item) -> void:
	_pending_upgrade = item
	_upgrade_notice_active = true
	_message_label.text = tr("UI_UPGRADE_ITEM_UNAVAILABLE") % [_item_title(item)]
	_confirm_button.text = tr("UI_OK")
	_cancel_button.text = tr("UI_CANCEL")
	_animation_player.play("show_dialog")
	_confirm_button.grab_focus()


func _on_confirm_pressed() -> void:
	if _pending_upgrade != null:
		var upgrade_item := _pending_upgrade
		var was_notice := _upgrade_notice_active
		_pending_upgrade = null
		_upgrade_notice_active = false
		_animation_player.play("hide_dialog")
		_animation_player.advance(0.0)
		if was_notice:
			upgrade_notice_dismissed.emit()
		else:
			upgrade_confirmed.emit(upgrade_item)
		return
	if _pending_skill == null:
		return
	var selected := _pending_skill
	_pending_skill = null
	_animation_player.play("hide_dialog")
	_animation_player.advance(0.0)
	confirmed.emit(selected)


func _on_cancel_pressed() -> void:
	if _pending_upgrade != null:
		var was_notice := _upgrade_notice_active
		_pending_upgrade = null
		_upgrade_notice_active = false
		_animation_player.play("hide_dialog")
		_animation_player.advance(0.0)
		if was_notice:
			upgrade_notice_dismissed.emit()
		return
	if _pending_skill == null:
		return
	_pending_skill = null
	_animation_player.play("hide_dialog")
	_animation_player.advance(0.0)
	cancelled.emit()


func _item_title(item: Item) -> String:
	if item == null:
		return tr("UI_EMPTY")
	if item.skill_definition != null:
		return tr(String(item.skill_definition.get("name_key")))
	return tr(item.title)
