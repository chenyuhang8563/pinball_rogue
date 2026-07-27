extends Panel
class_name ActiveSkillSlot

const ItemTooltipScene: PackedScene = preload("res://UI/shared/item_tooltip.tscn")

signal skill_pressed
signal skill_released

@onready var _icon: TextureRect = $Icon
@onready var _charge_label: Label = $ChargeLabel
@onready var _cooldown_progress: TextureProgressBar = $CooldownProgress

var _controller: Node = null
var _item: Item = null
var _battle_active: bool = false
var _blocked_by_panel: bool = false


func bind_controller(controller: Node) -> void:
	_controller = controller
	if _controller == null:
		return
	if not _controller.skill_changed.is_connected(_on_skill_changed):
		_controller.skill_changed.connect(_on_skill_changed)
	if not _controller.runtime_changed.is_connected(_on_runtime_changed):
		_controller.runtime_changed.connect(_on_runtime_changed)
	_on_skill_changed(_controller.equipped_item)
	_on_runtime_changed(
		_controller.get_current_charges(),
		_controller.get_max_charges(),
		_controller.get_recharge_progress()
	)


func present_battle_started(_token: RunFlowToken, _plan: BattlePlan) -> void:
	_battle_active = true
	_refresh_visibility()


func present_battle_completed(
	_token: RunFlowToken,
	_battle_id: StringName,
	_plan: BattlePlan
) -> void:
	_battle_active = false
	_refresh_visibility()


func present_run_terminal(_token: RunFlowToken) -> void:
	_battle_active = false
	_refresh_visibility()


func set_blocked_by_panel(blocked: bool) -> void:
	_blocked_by_panel = blocked
	_refresh_visibility()


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		skill_pressed.emit()
	else:
		skill_released.emit()
	accept_event()


func _on_skill_changed(item: Item) -> void:
	_item = item
	_icon.texture = item.icon if item != null else null


func _make_custom_tooltip(_for_text: String) -> Control:
	if _item == null:
		return null
	var tooltip: ItemTooltip = ItemTooltipScene.instantiate() as ItemTooltip
	tooltip.set_item(_item, _current_skill_level())
	return tooltip


func _current_skill_level() -> int:
	if _controller == null or not _controller.has_method("get_item_level"):
		return 1
	return maxi(1, int(_controller.call("get_item_level", _item)))


func _on_runtime_changed(current: int, maximum: int, progress: float) -> void:
	_charge_label.text = "%d/%d" % [current, maximum]
	_cooldown_progress.value = progress * 100.0


func _play_visibility(should_show: bool) -> void:
	var player := get_node_or_null("VisibilityPlayer") as AnimationPlayer
	if player == null:
		return
	player.play(&"show" if should_show else &"hide")
	player.advance(0.0)


func _refresh_visibility() -> void:
	_play_visibility(_battle_active and not _blocked_by_panel)
