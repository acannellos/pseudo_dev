class_name TorchFlicker
extends OmniLight3D
## Cheap torch/candle flicker: two detuned sine waves modulate the light's
## energy, phase-seeded per instance so neighbouring torches never sync.
## Stepped on twos to match the project's stop-motion aesthetic.

const FRAME := 1.0 / 12.0

@export var base_energy := 2.2
## Peak-to-peak flicker as a fraction of [member base_energy].
@export_range(0.0, 1.0) var flicker_amount := 0.22
@export var flicker_speed := 9.0

var _time := 0.0
var _step_timer := 0.0
var _phase := 0.0


func _ready() -> void:
	_phase = randf() * TAU
	light_energy = base_energy


func _process(delta: float) -> void:
	_time += delta
	_step_timer += delta
	if _step_timer < FRAME:
		return
	_step_timer = 0.0
	var wave := sin(_time * flicker_speed + _phase) * 0.6 \
			+ sin(_time * flicker_speed * 2.33 + _phase * 1.7) * 0.4
	light_energy = base_energy * (1.0 + wave * flicker_amount)
