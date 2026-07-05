class_name DamageNumber
extends Label3D
## Lightweight floating damage number: one billboarded [Label3D] that pops
## at the hit point, drifts up with a little random lean, and fades —
## stepped on twos like the rest of the FX. Spawned by whoever actually
## applies damage (enemies, dummies, tower, breakables), so melee, lunge,
## and arrows all get numbers for free through the take_hit contract.

const FRAME := 1.0 / 12.0

@export var lifetime := 0.7
@export var rise_speed := 1.6

var _age := 0.0
var _step_timer := 0.0
var _drift := Vector3.ZERO


static func spawn(parent: Node, position: Vector3, amount: int) -> void:
	var number := DamageNumber.new()
	number.text = str(amount)
	parent.add_child(number)
	number.global_position = position \
			+ Vector3(randf_range(-0.2, 0.2), 0.0, randf_range(-0.2, 0.2))
	number._drift = Vector3(randf_range(-0.5, 0.5), 0.0, randf_range(-0.5, 0.5))


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	fixed_size = false
	pixel_size = 0.012
	font_size = 48
	outline_size = 14
	modulate = Color(1.0, 0.92, 0.5)
	outline_modulate = Color(0.1, 0.07, 0.05)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_step_timer += delta
	if _step_timer < FRAME:
		return
	_step_timer = 0.0
	# Stepped rise + fade, on twos.
	global_position += (Vector3.UP * rise_speed + _drift) * FRAME
	var t := _age / lifetime
	modulate.a = 1.0 - t * t
	outline_modulate.a = modulate.a
