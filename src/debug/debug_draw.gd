class_name DebugDraw
extends Node3D
## Immediate-mode debug vectors, rebuilt every frame from an ImmediateMesh:
##
## - green: actual velocity (length scaled to magnitude)
## - cyan: desired velocity (input intent), same scale
## - yellow: character facing (fixed length)
## - magenta: camera look direction (fixed length)
##
## Toggle with the `toggle_debug` action (F3). Lines render with no depth
## test so momentum stays legible through level geometry.

const VELOCITY_COLOR := Color(0.25, 1.0, 0.3)
const DESIRED_COLOR := Color(0.3, 0.85, 1.0)
const FACING_COLOR := Color(1.0, 0.9, 0.2)
const CAMERA_COLOR := Color(1.0, 0.3, 0.9)
## Metres of drawn line per m/s of velocity.
const VECTOR_SCALE := 0.22
const DIRECTION_LENGTH := 1.6
const HEAD_SIZE := 0.18

var _mesh := ImmediateMesh.new()
var _mesh_instance: MeshInstance3D

@onready var _player: Player = get_parent() as Player


func _ready() -> void:
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.top_level = true
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.no_depth_test = true
	material.render_priority = 10
	_mesh_instance.material_override = material
	add_child(_mesh_instance)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug"):
		visible = not visible


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	if not visible or _player == null:
		return
	_mesh_instance.global_transform = Transform3D.IDENTITY
	var origin := _player.global_position + Vector3.UP
	_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	_draw_arrow(origin, _player.velocity * VECTOR_SCALE, VELOCITY_COLOR)
	_draw_arrow(origin, _player.desired_velocity * VECTOR_SCALE, DESIRED_COLOR)
	_draw_arrow(origin + Vector3.UP * 0.15,
			_player.facing * DIRECTION_LENGTH, FACING_COLOR)
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		_draw_arrow(origin + Vector3.UP * 0.3,
				-camera.global_basis.z * DIRECTION_LENGTH, CAMERA_COLOR)
	_mesh.surface_end()


func _draw_arrow(from: Vector3, vector: Vector3, color: Color) -> void:
	if vector.length() < 0.02:
		return
	var tip := from + vector
	_mesh.surface_set_color(color)
	_mesh.surface_add_vertex(from)
	_mesh.surface_add_vertex(tip)
	var dir := vector.normalized()
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.01:
		side = dir.cross(Vector3.RIGHT)
	side = side.normalized()
	var back := tip - dir * HEAD_SIZE
	_mesh.surface_add_vertex(tip)
	_mesh.surface_add_vertex(back + side * HEAD_SIZE * 0.6)
	_mesh.surface_add_vertex(tip)
	_mesh.surface_add_vertex(back - side * HEAD_SIZE * 0.6)
