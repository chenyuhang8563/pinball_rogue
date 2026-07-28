class_name LootSettlementGate
extends RefCounted

## 战利品结算门槛。它只描述当前战斗的未解决掉落数量，
## 不拥有场景、钱包或战斗完成流程。
signal settled

var _pending_count: int = 0


func reset(initially_settled: bool = true) -> void:
	_pending_count = 0 if initially_settled else 1


func open_pending() -> void:
	_pending_count += 1


func resolve_pending() -> void:
	if _pending_count <= 0:
		return
	_pending_count -= 1
	if _pending_count == 0:
		settled.emit()


func force_settled() -> void:
	if _pending_count <= 0:
		return
	_pending_count = 0
	settled.emit()


func is_settled() -> bool:
	return _pending_count == 0


func pending_count() -> int:
	return _pending_count
