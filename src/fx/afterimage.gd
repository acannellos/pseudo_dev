class_name Afterimage
extends Node3D
## One world-space snapshot of the player mesh, frozen at the pose it had on
## the spawn frame (Pseudoregalia-style dash ghost). Every visible
## [MeshInstance3D] under the source visual is copied with its world
## transform, flattened to a single unshaded color, and faded out — stepped
## on twos, matching the stop-motion animation style.

const FRAME := 1.0 / 12.0

var _fade_time := 0.35
var _age := 0.0
var _step_timer := 0.0
var _start_alpha := 0.7
var _material := StandardMaterial3D.new()


## Copies the current pose of [param source] into a self-freeing snapshot.
static func spawn(parent: Node, source: Node3D, color: Color,
		fade_time: float) -> void:
	var image := Afterimage.new()
	image._fade_time = fade_time
	image._material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	image._material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	image._material.albedo_color = Color(color.r, color.g, color.b, image._start_alpha)
	parent.add_child(image)
	image.top_level = true
	image.global_transform = Transform3D.IDENTITY
	for found in source.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance == null or not mesh_instance.visible:
			continue
		var copy := MeshInstance3D.new()
		copy.mesh = mesh_instance.mesh
		copy.material_override = image._material
		copy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		image.add_child(copy)
		copy.global_transform = mesh_instance.global_transform


func _process(delta: float) -> void:
	_age += delta
	if _age >= _fade_time:
		queue_free()
		return
	_step_timer += delta
	if _step_timer < FRAME:
		return
	_step_timer = 0.0
	_material.albedo_color.a = _start_alpha * (1.0 - _age / _fade_time)
