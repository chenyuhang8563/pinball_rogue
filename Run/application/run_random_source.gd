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


func range_float(minimum: float, maximum: float) -> float:
	if minimum > maximum:
		return minimum
	return _rng.randf_range(minimum, maximum)


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


## Float weights remain floats end-to-end; no rarity weight is rounded away.
func weighted_index_float(weights: PackedFloat64Array) -> int:
	var total: float = 0.0
	var last_positive: int = -1
	for index: int in range(weights.size()):
		var weight := maxf(0.0, weights[index])
		if is_nan(weight) or is_inf(weight):
			continue
		total += weight
		if weight > 0.0:
			last_positive = index
	if total <= 0.0 or last_positive < 0:
		return -1
	var roll := range_float(0.0, total)
	for index: int in range(weights.size()):
		var weight := maxf(0.0, weights[index])
		if is_nan(weight) or is_inf(weight) or weight <= 0.0:
			continue
		if roll < weight:
			return index
		roll -= weight
	return last_positive


## Deterministic in-place Fisher-Yates. The same seed and input order always
## produce the same permutation without touching Godot's global RNG.
func shuffle(values: Array) -> Array:
	for index: int in range(values.size() - 1, 0, -1):
		var swap_index := range_int(0, index)
		if swap_index != index:
			var value: Variant = values[index]
			values[index] = values[swap_index]
			values[swap_index] = value
	return values
