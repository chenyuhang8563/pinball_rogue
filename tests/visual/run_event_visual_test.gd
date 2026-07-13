extends Control

enum Scenario {
	DICE_SUCCESS,
	DICE_FAILURE,
	DICE_INSUFFICIENT,
	CROSSROADS,
}

@export var scenario: Scenario = Scenario.DICE_SUCCESS

@onready var _event_panel: RunEventPanel = $RunEventPanel


func _ready() -> void:
	var game_executor: Node = get_node_or_null("/root/GameExecutor")
	if game_executor != null:
		game_executor.process_mode = Node.PROCESS_MODE_ALWAYS
	TranslationServer.set_locale("zh_CN")
	match scenario:
		Scenario.DICE_SUCCESS:
			_event_panel.show_dice_event(100)
			_event_panel.reveal_dice_result(4, 60, 120)
		Scenario.DICE_FAILURE:
			_event_panel.show_dice_event(100)
			_event_panel.reveal_dice_result(3, -20, 0)
		Scenario.DICE_INSUFFICIENT:
			_event_panel.show_dice_event(19)
		Scenario.CROSSROADS:
			_event_panel.show_crossroads_event()
