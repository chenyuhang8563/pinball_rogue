extends RefCounted
class_name RunRandomSource

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(seed_value: int = -1) -> void:
	if seed_value < 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value


func range_int(minimum: int, maximum: int) -> int:
	if minimum > maximum:
		return minimum
	return _rng.randi_range(minimum, maximum)


func weighted_index(weights: PackedInt32Array) -> int:
	var total: int = 0
	for weight: int in weights:
		total += maxi(0, weight)
	if total <= 0:
		return -1
	var roll: int = range_int(1, total)
	for index: int in range(weights.size()):
		roll -= maxi(0, weights[index])
		if roll <= 0:
			return index
	return -1
