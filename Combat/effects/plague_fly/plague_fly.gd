extends Node2D
class_name PlagueFly

## Friendly plague fly released when an infected enemy dies.
##
## The fly is a non-physical ally: it homes toward the nearest living enemy and
## bites it on a fixed cadence, dealing flat damage. Bites also broadcast through
## the EffectManager so the parasite relic can layer poison. The fly retargets
## every frame, so if its current target dies it simply moves on to the next
## nearest enemy; with no enemies left it idles until its lifetime expires.

const DamagePacketScript: GDScript = preload("res://Combat/damage/damage_packet.gd")

@export var bite_damage: int = 1
@export var bite_interval: float = 0.5
@export var lifetime: float = 5.0
@export var move_speed: float = 130.0
@export var bite_range: float = 16.0

var _bite_accumulator: float = 0.0


func _ready() -> void:
	add_to_group(&"plague_flies")
	z_index = 5


func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	var target: Node2D = _nearest_living_enemy()
	if target == null:
		return
	var to_target: Vector2 = target.global_position - global_position
	var distance: float = to_target.length()
	if distance > bite_range:
		global_position += to_target.normalized() * move_speed * delta
		_bite_accumulator = 0.0
		return
	_bite(target)


## Bites on a fixed cadence while in range. Each bite applies a flat damage packet
## and notifies the effect domain so parasite can spread poison.
func _bite(target: Node2D) -> void:
	_bite_accumulator += get_process_delta_time()
	if _bite_accumulator < bite_interval:
		return
	_bite_accumulator -= bite_interval
	if not is_instance_valid(target) or (target.has_method("is_alive") and not bool(target.call("is_alive"))):
		return
	var packet: DamagePacket = DamagePacketScript.new(&"fly_bite", float(bite_damage), &"poison")
	packet.target = target
	if target.has_method("apply_damage_packet"):
		target.call("apply_damage_packet", packet)
	var effect_manager: Node = _get_effect_manager()
	if effect_manager != null and effect_manager.has_method("on_fly_bite"):
		effect_manager.call("on_fly_bite", target, packet)


func _nearest_living_enemy() -> Node2D:
	var best: Node2D = null
	var best_distance_sq: float = INF
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		if not node is Node2D or not is_instance_valid(node):
			continue
		if node.has_method("is_alive") and not bool(node.call("is_alive")):
			continue
		var distance_sq: float = global_position.distance_squared_to((node as Node2D).global_position)
		if distance_sq < best_distance_sq:
			best_distance_sq = distance_sq
			best = node as Node2D
	return best


func _get_effect_manager() -> Node:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.root.get_node_or_null("EffectManager")
