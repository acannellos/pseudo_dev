class_name OrbitCamera
extends Node3D
## Deliberately simple third-person orbit/follow camera.
##
## The rig node only ever yaws (so it can be used directly as the movement
## reference frame); pitch lives on the SpringArm3D child. Mouse look while
## captured, right stick on gamepad, Esc toggles mouse capture.

@export var target: Node3D
@export var mouse_sensitivity := 0.003
@export var stick_sensitivity := 2.8
@export var follow_speed := 14.0
## Height above the target the camera pivots around.
@export var pivot_height := 1.7
@export_range(-89.0, 0.0) var pitch_min_degrees := -70.0
@export_range(0.0, 89.0) var pitch_max_degrees := 35.0

@export_group("Speed Feedback")
## FOV rests here and kicks out toward [member fov_max] with speed.
@export var fov_base := 75.0
@export var fov_max := 94.0
## Horizontal speed where the FOV kick starts / where it saturates.
@export var fov_speed_min := 9.0
@export var fov_speed_max := 28.0
@export var fov_ease_speed := 5.0

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	add_to_group(&"camera_rig")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if target != null:
		global_position = target.global_position + Vector3.UP * pivot_height


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		_rotate_view(-motion.relative.x * mouse_sensitivity,
				-motion.relative.y * mouse_sensitivity)
	elif event.is_action_pressed(&"ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseButton and event.is_pressed() \
			and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	var stick := Input.get_vector(
			&"camera_left", &"camera_right", &"camera_up", &"camera_down")
	if stick != Vector2.ZERO:
		_rotate_view(-stick.x * stick_sensitivity * delta,
				-stick.y * stick_sensitivity * delta)
	if target != null:
		var goal := target.global_position + Vector3.UP * pivot_height
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	_update_speed_feedback(delta)


## Speed-reactive feedback: FOV kicks out as horizontal speed builds.
func _update_speed_feedback(delta: float) -> void:
	var body := target as CharacterBody3D
	if body == null or delta <= 0.0:
		return
	var flat := body.velocity
	flat.y = 0.0
	var speed := flat.length()
	var kick := clampf(
			(speed - fov_speed_min) / maxf(fov_speed_max - fov_speed_min, 0.01),
			0.0, 1.0)
	_camera.fov = lerpf(_camera.fov, lerpf(fov_base, fov_max, kick),
			1.0 - exp(-fov_ease_speed * delta))


func _rotate_view(yaw_delta: float, pitch_delta: float) -> void:
	rotate_y(yaw_delta)
	_arm.rotation.x = clampf(
			_arm.rotation.x + pitch_delta,
			deg_to_rad(pitch_min_degrees),
			deg_to_rad(pitch_max_degrees))
