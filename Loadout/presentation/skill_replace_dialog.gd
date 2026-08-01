extends Control
class_name SkillReplaceDialog

const ItemTooltipScript: GDScript = preload("res://UI/shared/item_tooltip.gd")

signal confirmed(new_skill: Item)
signal cancelled
signal upgrade_confirmed(item: Item)
signal upgrade_compensation_confirmed

@onready var _message_label: Label = $Center/Panel/Margin/Layout/Message
@onready var _confirm_button: Button = $Center/Panel/Margin/Layout/Buttons/Confirm
@onready var _cancel_button: Button = $Center/Panel/Margin/Layout/Buttons/Cancel
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _content_mode_player: AnimationPlayer = $ContentModePlayer
@onready var _current_icon: ItemIconView = \
	$Center/Panel/Margin/Layout/UpgradeComparison/CardsRow/CurrentCard/Icon as ItemIconView
@onready var _upgraded_icon: ItemIconView = \
	$Center/Panel/Margin/Layout/UpgradeComparison/CardsRow/UpgradedCard/Icon as ItemIconView
@onready var _current_description: RichTextLabel = \
	$Center/Panel/Margin/Layout/UpgradeComparison/DescriptionsRow/CurrentDescriptionPanel/Margin/Description
@onready var _upgraded_description: RichTextLabel = \
	$Center/Panel/Margin/Layout/UpgradeComparison/DescriptionsRow/UpgradedDescriptionPanel/Margin/Description

var _pending_skill: Item = null
var _pending_upgrade: Item = null
var _upgrade_notice_active: bool = false
var _compensation_gold: int = 0


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	_show_content_mode(&"message")


func request_replace(current_skill: Item, new_skill: Item) -> void:
	_pending_skill = new_skill
	_show_content_mode(&"message")
	var current_name := _item_title(current_skill)
	var next_name := _item_title(new_skill)
	_message_label.text = tr("UI_REPLACE_SKILL_CONFIRM") % [current_name, next_name]
	_confirm_button.text = tr("UI_CONFIRM")
	_cancel_button.text = tr("UI_CANCEL")
	_animation_player.play("show_dialog")
	_confirm_button.grab_focus()


func request_relic_replace(new_relic: Item) -> void:
	_pending_skill = new_relic
	_show_content_mode(&"message")
	_message_label.text = tr("UI_RELIC_REPLACEMENT_CONFIRM")
	_confirm_button.text = tr("UI_CONFIRM")
	_cancel_button.text = tr("UI_CANCEL")
	_animation_player.play("show_dialog")
	_confirm_button.grab_focus()


func is_request_pending() -> bool:
	return _pending_skill != null


func reset_pending() -> void:
	_pending_skill = null
	_pending_upgrade = null
	_upgrade_notice_active = false
	_compensation_gold = 0
	_show_content_mode(&"message")
	_clear_upgrade_comparison()
	if _animation_player != null:
		_animation_player.play(&"hide_dialog")
		_animation_player.advance(0.0)
	else:
		hide()


func cancel_replace_request() -> void:
	if _pending_skill == null:
		return
	_pending_skill = null
	_animation_player.play("hide_dialog")
	_animation_player.advance(0.0)
	cancelled.emit()


func request_upgrade(item: Item, current_level: int = 1, upgraded_level: int = 2) -> void:
	_pending_upgrade = item
	_upgrade_notice_active = false
	_set_upgrade_comparison(item, current_level, upgraded_level)
	_show_content_mode(&"upgrade")
	_confirm_button.text = tr("UI_CONFIRM")
	_cancel_button.text = tr("UI_CANCEL")
	_animation_player.play("show_dialog")
	_confirm_button.grab_focus()


func request_upgrade_compensation(gold_amount: int) -> void:
	_pending_upgrade = null
	_upgrade_notice_active = true
	_compensation_gold = gold_amount
	_show_content_mode(&"message")
	_message_label.text = tr("UI_UPGRADE_ALL_MAX_COMPENSATION") % [gold_amount]
	_confirm_button.text = tr("UI_CONFIRM")
	_cancel_button.text = tr("UI_CANCEL")
	_animation_player.play("show_dialog")
	_confirm_button.grab_focus()


func _on_confirm_pressed() -> void:
	if _upgrade_notice_active:
		_upgrade_notice_active = false
		_compensation_gold = 0
		_animation_player.play("hide_dialog")
		_animation_player.advance(0.0)
		upgrade_compensation_confirmed.emit()
		return
	if _pending_upgrade != null:
		var upgrade_item := _pending_upgrade
		_pending_upgrade = null
		_animation_player.play("hide_dialog")
		_animation_player.advance(0.0)
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
	if _upgrade_notice_active:
		_upgrade_notice_active = false
		_compensation_gold = 0
		_animation_player.play("hide_dialog")
		_animation_player.advance(0.0)
		return
	if _pending_upgrade != null:
		_pending_upgrade = null
		_animation_player.play("hide_dialog")
		_animation_player.advance(0.0)
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


func _set_upgrade_comparison(item: Item, current_level: int, upgraded_level: int) -> void:
	var safe_current_level := clampi(current_level, 1, 4)
	var safe_upgraded_level := clampi(upgraded_level, safe_current_level, 4)
	_current_icon.set_texture(item.icon if item != null else null)
	_current_icon.set_level(safe_current_level)
	_current_icon.set_level_visible(false)
	_upgraded_icon.set_texture(item.icon if item != null else null)
	_upgraded_icon.set_level(safe_upgraded_level)
	_current_description.text = ItemTooltipScript.format_description(
		_translated_level_description(item, safe_current_level)
	)
	_upgraded_description.text = ItemTooltipScript.format_description(
		_translated_level_description(item, safe_upgraded_level)
	)


func _clear_upgrade_comparison() -> void:
	if _current_icon != null:
		_current_icon.clear()
	if _upgraded_icon != null:
		_upgraded_icon.clear()
	if _current_description != null:
		_current_description.text = ""
	if _upgraded_description != null:
		_upgraded_description.text = ""


func _translated_level_description(item: Item, level: int) -> String:
	if item == null:
		return ""
	if item.id.is_empty():
		return tr(item.description)
	var key := "ITEM_%s_DESC_LV%d" % [item.id.to_upper(), level]
	var translated := tr(key)
	if translated != key:
		return translated
	var fallback_key := "ITEM_%s_DESC" % item.id.to_upper()
	var fallback := tr(fallback_key)
	return fallback if fallback != fallback_key else tr(item.description)


func _show_content_mode(mode: StringName) -> void:
	if _content_mode_player == null or not _content_mode_player.has_animation(mode):
		return
	_content_mode_player.play(mode)
	_content_mode_player.advance(0.0)
