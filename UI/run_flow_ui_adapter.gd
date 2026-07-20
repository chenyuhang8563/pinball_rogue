extends RefCounted
class_name RunFlowUIAdapter

## Owns presentation/intent wiring only. Every command crosses the typed
## RunFlowController boundary with the stable identity supplied by the active
## presentation; no phase, reward, event, upgrade, or completion rule lives
## here.

var _controller: RunFlowController = null
var _node_choice_panel: NodeChoicePanel = null
var _reward_panel: DraftRewardPanel = null
var _event_panel: RunEventPanel = null
var _inventory_panel: InventoryPanel = null
var _normal_shop: Node = null
var _devil_shop: DevilShop = null
var _failure_panel: RunFailurePanel = null
var _health_hud: BattleHealthHud = null
var _floor_hud: FloorHud = null
var _skill_slot: ActiveSkillSlot = null
var _connections: Array[Dictionary] = []
var _configured: bool = false


func configure(
	controller: RunFlowController,
	node_choice_panel: NodeChoicePanel,
	reward_panel: DraftRewardPanel,
	event_panel: RunEventPanel,
	inventory_panel: InventoryPanel,
	normal_shop: Node,
	devil_shop: DevilShop,
	failure_panel: RunFailurePanel,
	health_hud: BattleHealthHud,
	floor_hud: FloorHud,
	skill_slot: ActiveSkillSlot
) -> bool:
	dispose()
	if controller == null or not is_instance_valid(controller) \
			or node_choice_panel == null or reward_panel == null or event_panel == null \
			or inventory_panel == null or normal_shop == null or devil_shop == null \
			or failure_panel == null or health_hud == null or floor_hud == null \
			or skill_slot == null:
		return false
	_controller = controller
	_node_choice_panel = node_choice_panel
	_reward_panel = reward_panel
	_event_panel = event_panel
	_inventory_panel = inventory_panel
	_normal_shop = normal_shop
	_devil_shop = devil_shop
	_failure_panel = failure_panel
	_health_hud = health_hud
	_floor_hud = floor_hud
	_skill_slot = skill_slot

	var wired: bool = _wire_controller_presentations() and _wire_ui_intents()
	if not wired:
		dispose()
		return false
	_configured = true
	return true


func dispose() -> void:
	for index: int in range(_connections.size() - 1, -1, -1):
		var connection: Dictionary = _connections[index]
		var source: Object = connection.get(&"source")
		var signal_name: StringName = StringName(connection.get(&"signal", &""))
		var callable: Callable = connection.get(&"callable", Callable())
		if source != null and is_instance_valid(source) and source.has_signal(signal_name) \
				and source.is_connected(signal_name, callable):
			source.disconnect(signal_name, callable)
	_connections.clear()
	_clear_presentations()
	_controller = null
	_node_choice_panel = null
	_reward_panel = null
	_event_panel = null
	_inventory_panel = null
	_normal_shop = null
	_devil_shop = null
	_failure_panel = null
	_health_hud = null
	_floor_hud = null
	_skill_slot = null
	_configured = false


func is_configured() -> bool:
	return _configured


func _wire_controller_presentations() -> bool:
	return _connect(_controller, &"node_options_presented", _on_node_options_presented) \
		and _connect(_controller, &"reward_presented", _on_reward_presented) \
		and _connect(_controller, &"reward_resolved", _on_reward_resolved) \
		and _connect(
			_controller,
			&"reward_replacement_requested",
			_on_reward_replacement_requested
		) \
		and _connect(_controller, &"event_presented", _on_event_presented) \
		and _connect(_controller, &"event_resolved", _on_event_resolved) \
		and _connect(_controller, &"upgrade_presented", _on_upgrade_presented) \
		and _connect(_controller, &"upgrade_resolved", _on_upgrade_resolved) \
		and _connect(_controller, &"shop_opened", _on_shop_opened) \
		and _connect(_controller, &"shop_closed", _on_shop_closed) \
		and _connect(_controller, &"health_changed", _on_health_changed) \
		and _connect(_controller, &"floor_changed", _on_floor_changed) \
		and _connect(_controller, &"battle_started", _on_battle_started) \
		and _connect(_controller, &"battle_completed", _on_battle_completed) \
		and _connect(_controller, &"run_failed", _on_run_failed) \
		and _connect(_controller, &"run_completed", _on_run_completed)


func _wire_ui_intents() -> bool:
	return _connect(_node_choice_panel, &"node_choice_intent", _on_node_choice_intent) \
		and _connect(
			_node_choice_panel,
			&"terminal_acknowledge_intent",
			_on_terminal_acknowledge_intent
		) \
		and _connect(_reward_panel, &"reward_intent", _on_reward_intent) \
		and _connect(
			_reward_panel,
			&"reward_replacement_intent",
			_on_reward_replacement_intent
		) \
		and _connect(_event_panel, &"event_intent", _on_event_intent) \
		and _connect(_inventory_panel, &"upgrade_intent", _on_upgrade_intent) \
		and _connect(
			_inventory_panel,
			&"upgrade_unavailable_intent",
			_on_upgrade_unavailable_intent
		) \
		and _connect(_normal_shop, &"shop_close_intent", _on_shop_close_intent) \
		and _connect(_devil_shop, &"shop_close_intent", _on_shop_close_intent) \
		and _connect(_failure_panel, &"restart_intent", _on_restart_intent)


func _connect(source: Object, signal_name: StringName, callable: Callable) -> bool:
	if source == null or not is_instance_valid(source) or not source.has_signal(signal_name) \
			or not callable.is_valid():
		return false
	if not source.is_connected(signal_name, callable):
		if source.connect(signal_name, callable) != OK:
			return false
	_connections.append({
		&"source": source,
		&"signal": signal_name,
		&"callable": callable,
	})
	return true


func _on_node_options_presented(offer: RunNodeOffer) -> void:
	_node_choice_panel.present_offer(offer)


func _on_reward_presented(offer: RewardOffer) -> void:
	_reward_panel.present_offer(offer)


func _on_reward_resolved(result: RewardResult) -> void:
	_reward_panel.apply_result(result, _controller.current_reward_offer())


func _on_reward_replacement_requested(result: RewardResult) -> void:
	_reward_panel.present_replacement(result)


func _on_event_presented(presentation: EventPresentation) -> void:
	_event_panel.present_event(presentation)


func _on_event_resolved(resolution: EventResolution) -> void:
	_event_panel.apply_resolution(resolution)


func _on_upgrade_presented(offer: UpgradeOffer) -> void:
	_inventory_panel.present_upgrade_offer(offer)


func _on_upgrade_resolved(_result: UpgradeResult) -> void:
	_inventory_panel.finish_upgrade_selection()


func _on_shop_opened(token: RunFlowToken, shop_kind: StringName) -> void:
	if shop_kind == &"shop":
		_normal_shop.call("present_shop", token, shop_kind)
	elif shop_kind == &"devil_shop":
		_devil_shop.present_shop(token, shop_kind)


func _on_shop_closed(token: RunFlowToken, shop_kind: StringName) -> void:
	if shop_kind == &"shop":
		_normal_shop.call("dismiss_shop", token, shop_kind)
	elif shop_kind == &"devil_shop":
		_devil_shop.dismiss_shop(token, shop_kind)


func _on_health_changed(value: int) -> void:
	_health_hud.set_health(value)


func _on_floor_changed(floor_number: int) -> void:
	_floor_hud.set_floor(floor_number)


func _on_battle_started(token: RunFlowToken, plan: BattlePlan) -> void:
	_skill_slot.present_battle_started(token, plan)


func _on_battle_completed(
	token: RunFlowToken,
	battle_id: StringName,
	plan: BattlePlan
) -> void:
	_skill_slot.present_battle_completed(token, battle_id, plan)


func _on_run_failed(token: RunFlowToken, reason: StringName) -> void:
	_clear_transient_presentations()
	_skill_slot.present_run_terminal(token)
	_failure_panel.present_failure(token, reason)


func _on_run_completed(token: RunFlowToken) -> void:
	_clear_transient_presentations()
	_skill_slot.present_run_terminal(token)
	_node_choice_panel.present_terminal(token)


func _on_node_choice_intent(
	token: RunFlowToken,
	offer_id: StringName,
	option_id: StringName
) -> void:
	_controller.select_node(token, offer_id, option_id)


func _on_terminal_acknowledge_intent(token: RunFlowToken) -> void:
	_controller.acknowledge_terminal(token)


func _on_reward_intent(
	token: RunFlowToken,
	draft_id: StringName,
	offer_id: StringName
) -> void:
	_controller.select_reward(token, draft_id, offer_id)


func _on_reward_replacement_intent(
	token: RunFlowToken,
	replacement_token: StringName,
	confirmed: bool
) -> void:
	if confirmed:
		_controller.confirm_reward_replacement(token, replacement_token)
	else:
		_controller.cancel_reward_replacement(token, replacement_token)


func _on_event_intent(
	token: RunFlowToken,
	event_id: StringName,
	option_id: StringName,
	intent: EventResolver.EventIntent
) -> void:
	if intent == EventResolver.EventIntent.ACKNOWLEDGE_RESULT:
		_controller.acknowledge_event_result(token, event_id, option_id)
	else:
		_controller.submit_event_intent(token, event_id, option_id, intent)


func _on_upgrade_intent(
	token: RunFlowToken,
	offer_id: StringName,
	candidate_id: StringName
) -> void:
	_controller.select_upgrade(token, offer_id, candidate_id)


func _on_upgrade_unavailable_intent(token: RunFlowToken, offer_id: StringName) -> void:
	_controller.acknowledge_upgrade_unavailable(token, offer_id)


func _on_shop_close_intent(token: RunFlowToken, shop_kind: StringName) -> void:
	_controller.close_shop(token, shop_kind)


func _on_restart_intent(token: RunFlowToken) -> void:
	if _controller.restart_run(token):
		_failure_panel.clear_presentation()


func _clear_presentations() -> void:
	if _node_choice_panel != null and is_instance_valid(_node_choice_panel):
		_node_choice_panel.clear_presentation()
	if _reward_panel != null and is_instance_valid(_reward_panel):
		_reward_panel.clear_presentation()
	if _event_panel != null and is_instance_valid(_event_panel):
		_event_panel.clear_presentation()
	if _inventory_panel != null and is_instance_valid(_inventory_panel):
		_inventory_panel.finish_upgrade_selection()
	if _normal_shop != null and is_instance_valid(_normal_shop) \
			and _normal_shop.has_method(&"clear_run_presentation"):
		_normal_shop.call("clear_run_presentation")
	if _devil_shop != null and is_instance_valid(_devil_shop):
		_devil_shop.clear_run_presentation()
	if _failure_panel != null and is_instance_valid(_failure_panel):
		_failure_panel.clear_presentation()


func _clear_transient_presentations() -> void:
	_node_choice_panel.clear_presentation()
	_reward_panel.clear_presentation()
	_event_panel.clear_presentation()
	_inventory_panel.finish_upgrade_selection()
	if _normal_shop.has_method(&"clear_run_presentation"):
		_normal_shop.call("clear_run_presentation")
	_devil_shop.clear_run_presentation()
