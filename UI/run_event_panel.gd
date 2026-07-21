extends Control
class_name RunEventPanel

signal event_intent(
	token: RunFlowToken,
	event_id: StringName,
	option_id: StringName,
	intent: EventResolver.EventIntent
)

const SMALL_WAGER_COST: int = 20
const SMALL_WAGER_REWARD: int = 30
const LARGE_WAGER_COST: int = 60
const LARGE_WAGER_REWARD: int = 120

var _wallet: RefCounted = null
var _active_presentation: EventPresentation = null
var _current_gold: int = 0
var _pending_roll: int = 0
var _pending_gold_delta: int = 0
var _pending_reward: int = 0
var _showing_dice_event: bool = false

@onready var _title_label: Label = $Center/Panel/MarginContainer/Layout/TitleLabel
@onready var _description_label: Label = $Center/Panel/MarginContainer/Layout/DescriptionLabel
@onready var _gold_label: Label = $Center/Panel/MarginContainer/Layout/GoldLabel
@onready var _dice_label: Label = $Center/Panel/MarginContainer/Layout/DiceLabel
@onready var _result_label: Label = $Center/Panel/MarginContainer/Layout/ResultLabel
@onready var _small_wager_button: Button = $Center/Panel/MarginContainer/Layout/DiceChoiceRow/SmallWagerButton
@onready var _large_wager_button: Button = $Center/Panel/MarginContainer/Layout/DiceChoiceRow/LargeWagerButton
@onready var _fight_button: Button = $Center/Panel/MarginContainer/Layout/EncounterChoiceRow/FightButton
@onready var _escape_button: Button = $Center/Panel/MarginContainer/Layout/EncounterChoiceRow/EscapeButton
@onready var _continue_button: Button = $Center/Panel/MarginContainer/Layout/ContinueButton
@onready var _animation_player: AnimationPlayer = $AnimationPlayer


func configure(wallet: RefCounted) -> bool:
	unconfigure()
	if wallet == null or not is_instance_valid(wallet) or not wallet.has_method(&"balance"):
		return false
	_wallet = wallet
	return true


func unconfigure() -> void:
	clear_presentation()
	_wallet = null
	_current_gold = 0
	_pending_roll = 0
	_pending_gold_delta = 0
	_pending_reward = 0
	_showing_dice_event = false


func _ready() -> void:
	_connect_buttons()
	_connect_localization()
	_animation_player.play(&"hide")
	_animation_player.advance(0.0)


func present_event(presentation: EventPresentation) -> bool:
	if presentation == null or not presentation.is_valid() or presentation.consumed:
		return false
	_active_presentation = presentation
	if presentation.phase == EventPresentation.Phase.RESULT:
		return presentation.event_id == EventResolver.EVENT_DICE \
			and presentation.has_option(EventResolver.RESULT_CONTINUE)
	match presentation.event_id:
		EventResolver.EVENT_DICE:
			if not presentation.has_option(EventResolver.DICE_WAGER_20) \
					or not presentation.has_option(EventResolver.DICE_WAGER_60) \
					or not presentation.has_option(EventResolver.DICE_LEAVE):
				return false
			_show_dice_event(_wallet_balance())
		EventResolver.EVENT_CROSSROADS:
			if not presentation.has_option(EventResolver.CROSSROADS_FIGHT) \
					or not presentation.has_option(EventResolver.CROSSROADS_ESCAPE):
				return false
			_show_crossroads_event()
		_:
			return false
	return true


func apply_resolution(resolution: EventResolution) -> void:
	if resolution == null or not resolution.was_resolved():
		return
	if resolution.action != EventResolution.Action.SHOW_RESULT:
		dismiss()
		return
	var reward: int = 0
	if resolution.roll > 3:
		reward = LARGE_WAGER_REWARD \
			if resolution.option_id == EventResolver.DICE_WAGER_60 else SMALL_WAGER_REWARD
	_reveal_dice_result(resolution.roll, resolution.gold_delta, reward)


func clear_presentation() -> void:
	_active_presentation = null
	dismiss()


func dismiss() -> void:
	if _animation_player != null:
		_animation_player.play(&"hide")
		_animation_player.advance(0.0)
	_set_tree_paused(false)


func _show_dice_event(gold: int) -> void:
	_current_gold = maxi(0, gold)
	_pending_roll = 0
	_pending_gold_delta = 0
	_pending_reward = 0
	_showing_dice_event = true
	_refresh_dice_copy()
	_small_wager_button.disabled = _current_gold < SMALL_WAGER_COST
	_large_wager_button.disabled = _current_gold < LARGE_WAGER_COST
	_continue_button.disabled = false
	_continue_button.text = tr("EVENT_LEAVE_OPTION")
	var state_animation: StringName = &"show_dice_broke" \
		if _current_gold < SMALL_WAGER_COST else &"show_dice"
	_play_state(state_animation)
	_set_tree_paused(true)
	if is_inside_tree():
		_focus_first_affordable_wager()


func _show_crossroads_event() -> void:
	_pending_roll = 0
	_showing_dice_event = false
	_title_label.text = tr("EVENT_CROSSROADS_TITLE")
	_description_label.text = tr("EVENT_CROSSROADS_DESC")
	_fight_button.text = tr("EVENT_CROSSROADS_FIGHT_OPTION")
	_escape_button.text = tr("EVENT_CROSSROADS_ESCAPE_OPTION")
	_fight_button.disabled = false
	_escape_button.disabled = false
	_play_state(&"show_crossroads")
	_set_tree_paused(true)
	if is_inside_tree():
		_fight_button.grab_focus()


func _reveal_dice_result(roll: int, gold_delta: int, reward: int) -> void:
	_pending_roll = clampi(roll, 1, 6)
	_pending_gold_delta = gold_delta
	_pending_reward = maxi(0, reward)
	_small_wager_button.disabled = true
	_large_wager_button.disabled = true
	_animation_player.play(&"dice_roll")


func _emit_intent(option_id: StringName, intent: EventResolver.EventIntent) -> void:
	var presentation: EventPresentation = _active_presentation
	if presentation == null or presentation.consumed or not presentation.has_option(option_id):
		return
	event_intent.emit(presentation.token, presentation.event_id, option_id, intent)


func _on_small_wager_pressed() -> void:
	if _small_wager_button.disabled:
		return
	_small_wager_button.disabled = true
	_large_wager_button.disabled = true
	_emit_intent(EventResolver.DICE_WAGER_20, EventResolver.EventIntent.DICE_WAGER_SMALL)


func _on_large_wager_pressed() -> void:
	if _large_wager_button.disabled:
		return
	_small_wager_button.disabled = true
	_large_wager_button.disabled = true
	_emit_intent(EventResolver.DICE_WAGER_60, EventResolver.EventIntent.DICE_WAGER_LARGE)


func _on_fight_pressed() -> void:
	_fight_button.disabled = true
	_escape_button.disabled = true
	_emit_intent(EventResolver.CROSSROADS_FIGHT, EventResolver.EventIntent.CROSSROADS_FIGHT)


func _on_escape_pressed() -> void:
	_fight_button.disabled = true
	_escape_button.disabled = true
	_emit_intent(EventResolver.CROSSROADS_ESCAPE, EventResolver.EventIntent.CROSSROADS_ESCAPE)


func _on_continue_pressed() -> void:
	_continue_button.disabled = true
	if _active_presentation == null:
		return
	if _active_presentation.phase == EventPresentation.Phase.RESULT:
		_emit_intent(EventResolver.RESULT_CONTINUE, EventResolver.EventIntent.ACKNOWLEDGE_RESULT)
	else:
		_emit_intent(EventResolver.DICE_LEAVE, EventResolver.EventIntent.DICE_LEAVE)


func _connect_buttons() -> void:
	if not _small_wager_button.pressed.is_connected(_on_small_wager_pressed):
		_small_wager_button.pressed.connect(_on_small_wager_pressed)
	if not _large_wager_button.pressed.is_connected(_on_large_wager_pressed):
		_large_wager_button.pressed.connect(_on_large_wager_pressed)
	if not _fight_button.pressed.is_connected(_on_fight_pressed):
		_fight_button.pressed.connect(_on_fight_pressed)
	if not _escape_button.pressed.is_connected(_on_escape_pressed):
		_escape_button.pressed.connect(_on_escape_pressed)
	if not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)
	if not _animation_player.animation_finished.is_connected(_on_animation_finished):
		_animation_player.animation_finished.connect(_on_animation_finished)


func _connect_localization() -> void:
	var localization: Node = _get_autoload_node(&"Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback: Callable = Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _refresh_dice_copy() -> void:
	_title_label.text = tr("EVENT_DICE_TITLE")
	_description_label.text = tr("EVENT_DICE_DESC")
	_gold_label.text = tr("EVENT_CURRENT_GOLD") % _current_gold
	_small_wager_button.text = tr("EVENT_DICE_SMALL_OPTION") % [SMALL_WAGER_COST, SMALL_WAGER_REWARD]
	_large_wager_button.text = tr("EVENT_DICE_LARGE_OPTION") % [LARGE_WAGER_COST, LARGE_WAGER_REWARD]
	_dice_label.text = tr("EVENT_DICE_PROMPT")
	if _current_gold < SMALL_WAGER_COST:
		_result_label.text = tr("EVENT_NOT_ENOUGH_GOLD")


func _refresh_result_copy() -> void:
	_dice_label.text = str(_pending_roll)
	if _pending_reward > 0:
		_result_label.text = tr("EVENT_DICE_SUCCESS") % [
			_pending_roll,
			_pending_reward,
			_pending_gold_delta,
		]
	else:
		_result_label.text = tr("EVENT_DICE_FAILURE") % [
			_pending_roll,
			_pending_gold_delta,
		]
	_continue_button.text = tr("UI_CONTINUE")


func _play_state(animation_name: StringName) -> void:
	_animation_player.play(animation_name)
	_animation_player.advance(0.0)


func _focus_first_affordable_wager() -> void:
	if not _small_wager_button.disabled:
		_small_wager_button.grab_focus()
	elif not _large_wager_button.disabled:
		_large_wager_button.grab_focus()
	else:
		_continue_button.grab_focus()


func _on_animation_finished(animation_name: StringName) -> void:
	if animation_name != &"dice_roll":
		return
	_refresh_result_copy()
	_play_state(&"show_result")
	if is_inside_tree():
		_continue_button.disabled = false
		_continue_button.grab_focus()


func _on_locale_changed(_locale_code: String) -> void:
	if not visible:
		return
	if _pending_roll > 0:
		_refresh_result_copy()
	elif _showing_dice_event:
		_refresh_dice_copy()
	else:
		_title_label.text = tr("EVENT_CROSSROADS_TITLE")
		_description_label.text = tr("EVENT_CROSSROADS_DESC")
		_fight_button.text = tr("EVENT_CROSSROADS_FIGHT_OPTION")
		_escape_button.text = tr("EVENT_CROSSROADS_ESCAPE_OPTION")


func _wallet_balance() -> int:
	return int(_wallet.call("balance")) if _wallet != null and is_instance_valid(_wallet) else 0


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))


func _set_tree_paused(paused: bool) -> void:
	if is_inside_tree():
		get_tree().paused = paused
