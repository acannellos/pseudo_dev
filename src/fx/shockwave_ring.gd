class_name ShockwaveRing
extends MeshInstance3D
## One-shot expanding ring for pound impacts. Expansion is stepped on twos
## (matching the stop-motion animation style) and the ring frees itself.

const FRAME := 1.0 / 12.0

@export var lifetime := 0.4
@export var max_radius := 3.2

var _age := 0.0
var _step_timer := 0.0
var _material := StandardMaterial3D.new()


## Spawns a ring flat on the ground at [param position].
static func spawn(parent: Node, position: Vector3) -> void:
	var ring := ShockwaveRing.new()
	parent.add_child(ring)
	ring.global_position = position + Vector3.UP * 0.08


func _ready() -> void:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.0
	torus.rings = 3
	torus.ring_segments = 12
	mesh = torus
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.albedo_color = Color(1.0, 0.9, 0.6, 0.9)
	material_override = _material
	scale = Vector3(0.2, 0.5, 0.2)


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_step_timer += delta
	if _step_timer < FRAME:
		return
	_step_timer = 0.0
	var t := _age / lifetime
	var radius := maxf(max_radius * t, 0.2)
	scale = Vector3(radius, 0.5, radius)
	_material.albedo_color.a = 0.9 * (1.0 - t)
