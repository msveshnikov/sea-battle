extends OmniLight3D
## Fire light flicker.

var _base := -1.0
var _t := randf() * 10.0


func _process(delta: float) -> void:
	if _base < 0.0:
		_base = light_energy
	_t += delta * 9.0
	light_energy = _base * (0.75 + 0.25 * sin(_t) * sin(_t * 1.7 + 1.3) + randf() * 0.1)
