class_name CompanionOrb
extends Node3D
## Navi-style companion: a small glowing omnisphere that hovers by the
## player's shoulder, deliberately under-damped so it trails behind during
## fast movement and catches up when you settle. On a Z-target lock it
## flies to hover above the target (and turns gold, like Navi over an
## enemy); on release it drifts home and back to cyan.
##
## Runs as `top_level` so the smoothing happens in world space — parenting
## it to the player would make the lag invisible.

const HOME_COLOR := Color(0.55, 0.9, 1.0)
const LOCK_COLOR := Color(1.0, 0.85, 0.35)

@export var player: Player
@export var targeting: TargetingSystem
## Follow stiffness at the shoulder — low enough to trail during a dash.
@export var follow_speed := 4.5
## Follow stiffness while flying to / holding on a target.
@export var travel_speed := 9.0
## Hover height above a locked target's point.
@export var lock_height := 0.7

var _time := 0.0
var _core_material := StandardMaterial3D.new()
var _glow_material := StandardMaterial3D.new()

@onready var _bobber: Node3D = Node3D.new()


func _ready() -> void:
	top_level = true
	add_child(_bobber)
	_core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.09
	core_mesh.height = 0.18
	core_mesh.radial_segments = 10
	core_mesh.rings = 5
	core.mesh = core_mesh
	core.material_override = _core_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bobber.add_child(core)
	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.17
	glow_mesh.height = 0.34
	glow_mesh.radial_segments = 10
	glow_mesh.rings = 5
	glow.mesh = glow_mesh
	glow.material_override = _glow_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bobber.add_child(glow)
	_apply_color(HOME_COLOR)
	global_position = _home_point()
	targeting.target_acquired.connect(func(_t: Node3D) -> void:
		_apply_color(LOCK_COLOR))
	targeting.target_released.connect(func() -> void:
		_apply_color(HOME_COLOR))


func _process(delta: float) -> void:
	_time += delta
	var locked := targeting.is_active()
	var goal := targeting.target_point() + Vector3.UP * lock_height if locked \
			else _home_point()
	var stiffness := travel_speed if locked else follow_speed
	global_position = global_position.lerp(goal, 1.0 - exp(-stiffness * delta))
	_bobber.position.y = sin(_time * 2.6) * 0.07


## Behind the player's off shoulder, out of the camera's way.
func _home_point() -> Vector3:
	var side := player.facing.cross(Vector3.UP)
	return player.global_position + Vector3.UP * 1.9 \
			- player.facing * 0.35 + side * 0.4


func _apply_color(color: Color) -> void:
	_core_material.albedo_color = color.lightened(0.35)
	_glow_material.albedo_color = Color(color.r, color.g, color.b, 0.3)
