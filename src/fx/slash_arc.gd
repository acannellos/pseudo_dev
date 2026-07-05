class_name SlashArc
extends MeshInstance3D
## One-shot anime-style slash: a low-poly arc fan flashed in front of the
## character, roughly tracing the swing hitbox. Rolls one way for combo hit
## 1, the other for hit 2, and flies flat and larger for hit 3. Expands and
## fades over a few stepped frames, then frees itself.

const FRAME := 1.0 / 12.0
const ARC_DEGREES := 140.0
const SEGMENTS := 6
const INNER_RADIUS := 0.5
## Roll of the arc plane around the facing axis, alternating per swing.
const ROLL := 0.3

@export var lifetime := 0.22

var _age := 0.0
var _step_timer := 0.0
var _material := StandardMaterial3D.new()


## Flashes an arc at [param origin] sweeping across [param facing].
## [param radius] should match the attack range so the visual is the hitbox.
static func spawn(parent: Node, origin: Vector3, facing: Vector3,
		combo_index: int, radius: float) -> void:
	var arc := SlashArc.new()
	arc.mesh = _build_fan(radius)
	parent.add_child(arc)
	var basis := Basis.looking_at(facing, Vector3.UP)
	var extra_scale := 1.0
	match combo_index:
		1:
			basis = basis.rotated(facing.normalized(), ROLL)
		2:
			basis = basis.rotated(facing.normalized(), -ROLL)
		_:
			extra_scale = 1.15
	arc.global_transform = Transform3D(basis, origin)
	arc.scale = Vector3.ONE * extra_scale


func _ready() -> void:
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material.albedo_color = Color(0.85, 0.93, 1.0, 0.85)
	material_override = _material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_step_timer += delta
	if _step_timer < FRAME:
		return
	_step_timer = 0.0
	scale *= 1.08
	_material.albedo_color.a = 0.85 * (1.0 - _age / lifetime)


## Flat triangle fan between an inner and outer arc, forward = -Z.
static func _build_fan(radius: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var half := deg_to_rad(ARC_DEGREES) * 0.5
	for i in SEGMENTS:
		var a0 := -half + deg_to_rad(ARC_DEGREES) * i / SEGMENTS
		var a1 := -half + deg_to_rad(ARC_DEGREES) * (i + 1) / SEGMENTS
		var dir0 := Vector3(sin(a0), 0.0, -cos(a0))
		var dir1 := Vector3(sin(a1), 0.0, -cos(a1))
		surface.add_vertex(dir0 * INNER_RADIUS)
		surface.add_vertex(dir0 * radius)
		surface.add_vertex(dir1 * radius)
		surface.add_vertex(dir0 * INNER_RADIUS)
		surface.add_vertex(dir1 * radius)
		surface.add_vertex(dir1 * INNER_RADIUS)
	return surface.commit()
