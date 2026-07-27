class_name MarbleChainRegistry
extends Node

var _chains_by_head_id: Dictionary[int, MarbleChain] = {}


func register_chain(chain: MarbleChain) -> bool:
	if chain == null or chain.head == null or not is_instance_valid(chain.head):
		return false
	_chains_by_head_id[chain.head.get_instance_id()] = chain
	return true


func unregister_chain(chain: MarbleChain) -> void:
	if chain == null:
		return
	for head_id: int in _chains_by_head_id.keys():
		if _chains_by_head_id[head_id] == chain:
			_chains_by_head_id.erase(head_id)


func find_chain_for_head(head: Marble) -> MarbleChain:
	if head == null or not is_instance_valid(head):
		return null
	var chain: MarbleChain = _chains_by_head_id.get(head.get_instance_id())
	return chain if is_instance_valid(chain) else null
