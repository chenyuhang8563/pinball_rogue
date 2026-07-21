extends Control
class_name NodeChoicePanel

signal node_choice_intent(
	token: RunFlowToken,
	offer_id: StringName,
	option_id: StringName
)
signal terminal_acknowledge_intent(token: RunFlowToken)

var _active_offer: RunNodeOffer = null
var _terminal_token: RunFlowToken = null
var _choices: Array[RunNodeChoice] = []
var _buttons: Array[Button] = []
var _title_label: Label = null
var _desc_label: Label = null
var _button_row: HBoxContainer = null


func _ready() -> void:
	_bind_nodes()
	_connect_localization()
	_connect_buttons()
	hide()


func present_offer(offer: RunNodeOffer) -> bool:
	_bind_nodes()
	_connect_buttons()
	if offer == null or not offer.is_valid() or offer.consumed or not _has_required_nodes():
		return false
	_active_offer = offer
	_terminal_token = null
	_choices = offer.choices()
	_render_offer()
	show()
	_set_tree_paused(true)
	_focus_first_button()
	return true


func present_terminal(
	token: RunFlowToken,
	title: String = "RUN_COMPLETED_TITLE",
	description: String = "RUN_COMPLETED_DESC"
) -> bool:
	_bind_nodes()
	_connect_buttons()
	if token == null or not token.is_valid() or not _has_required_nodes():
		return false
	_active_offer = null
	_terminal_token = token
	_choices.clear()
	_title_label.text = tr(title)
	if _desc_label != null:
		_desc_label.text = tr(description)
		_desc_label.show()
	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		button.text = tr("UI_OK") if index == 0 else ""
		button.disabled = false
		if index == 0:
			button.show()
		else:
			button.hide()
	show()
	_set_tree_paused(true)
	_focus_first_button()
	return true


func clear_presentation() -> void:
	_active_offer = null
	_terminal_token = null
	_choices.clear()
	hide()
	_set_tree_paused(false)


func _on_button_pressed(index: int) -> void:
	if _terminal_token != null:
		var terminal_token: RunFlowToken = _terminal_token
		clear_presentation()
		terminal_acknowledge_intent.emit(terminal_token)
		return
	if _active_offer == null or _active_offer.consumed \
			or index < 0 or index >= _choices.size():
		return
	var offer: RunNodeOffer = _active_offer
	var choice: RunNodeChoice = _choices[index]
	if choice == null or not choice.is_valid():
		return
	clear_presentation()
	node_choice_intent.emit(offer.token, offer.offer_id, choice.option_id)


func _render_offer() -> void:
	_title_label.text = tr("UI_CHOOSE_NEXT_NODE_TITLE")
	if _desc_label != null:
		_desc_label.hide()
	for index: int in range(_buttons.size()):
		var button: Button = _buttons[index]
		if index < _choices.size():
			var choice: RunNodeChoice = _choices[index]
			button.text = tr(choice.title)
			button.disabled = false
			button.show()
		else:
			button.hide()


func _bind_nodes() -> void:
	if _button_row != null:
		return
	_title_label = get_node_or_null("Center/Panel/MarginContainer/Layout/TitleLabel") as Label
	_desc_label = get_node_or_null("Center/Panel/MarginContainer/Layout/DescriptionLabel") as Label
	_button_row = get_node_or_null("Center/Panel/MarginContainer/Layout/ButtonRow") as HBoxContainer
	_buttons.clear()
	if _button_row == null:
		return
	for child: Node in _button_row.get_children():
		if child is Button:
			var button: Button = child as Button
			_buttons.append(button)


func _connect_buttons() -> void:
	for index: int in range(_buttons.size()):
		var callback: Callable = Callable(self, "_on_button_pressed").bind(index)
		if not _buttons[index].pressed.is_connected(callback):
			_buttons[index].pressed.connect(callback)


func _has_required_nodes() -> bool:
	return _title_label != null and _button_row != null and not _buttons.is_empty()


func _set_tree_paused(paused: bool) -> void:
	if is_inside_tree():
		get_tree().paused = paused


func _focus_first_button() -> void:
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


func _connect_localization() -> void:
	var localization: Node = _get_autoload_node(&"Localization")
	if localization == null or not localization.has_signal(&"locale_changed"):
		return
	var callback: Callable = Callable(self, "_on_locale_changed")
	if not localization.is_connected(&"locale_changed", callback):
		localization.connect(&"locale_changed", callback)


func _on_locale_changed(_locale_code: String) -> void:
	if not visible:
		return
	if _active_offer != null:
		_render_offer()
	elif _terminal_token != null:
		present_terminal(_terminal_token)


func _get_autoload_node(node_name: StringName) -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null(NodePath(node_name))
