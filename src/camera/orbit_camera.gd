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

@export_group("Z-Targeting")
## How quickly the rig swings behind the player when a lock engages (OoT
## style: camera on the player–enemy line, both in frame).
@export var lock_turn_speed := 6.0
## Downward arm pitch held while locked.
@export var lock_pitch_degrees := -14.0

@export_group("Focus Aim")
## Sideways pivot shift during no-target focus (over the right shoulder).
@export var focus_shoulder_offset := 0.65
## Arm length while aiming over the shoulder.
@export var focus_arm_length := 2.6
## Blend speed into/out of the shoulder view.
@export var focus_ease_speed := 7.0
@export var focus_pitch_degrees := -6.0

@export_group("Speed Feedback")
## FOV rests here and kicks out toward [member fov_max] with speed.
@export var fov_base := 75.0
@export var fov_max := 94.0
## Horizontal speed where the FOV kick starts / where it saturates.
@export var fov_speed_min := 9.0
@export var fov_speed_max := 28.0
@export var fov_ease_speed := 5.0

## Z-lock focus, mirrored from the player's TargetingSystem via signals.
var _lock: Node3D = null
var _targeting: TargetingSystem = null
## 0→1 blend into the over-the-shoulder focus view.
var _shoulder := 0.0
var _base_arm_length := 6.0

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _camera: Camera3D = $SpringArm3D/Camera3D


func _ready() -> void:
	add_to_group(&"camera_rig")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_base_arm_length = _arm.spring_length
	if target != null:
		global_position = target.global_position + Vector3.UP * pivot_height
		_targeting = target.get_node_or_null("TargetingSystem") as TargetingSystem
		if _targeting != null:
			_targeting.target_acquired.connect(func(node: Node3D) -> void:
				_lock = node)
			_targeting.target_released.connect(func() -> void:
				_lock = null)


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
	if _lock != null and not is_instance_valid(_lock):
		_lock = null
	var focusing := _targeting != null and _targeting.is_focusing()
	if _lock != null:
		_update_lock_view(delta)
	elif focusing:
		_update_focus_view(delta)
	else:
		var stick := Input.get_vector(
				&"camera_left", &"camera_right", &"camera_up", &"camera_down")
		if stick != Vector2.ZERO:
			_rotate_view(-stick.x * stick_sensitivity * delta,
					-stick.y * stick_sensitivity * delta)
	# Ease the shoulder offset and arm length in/out of focus aim.
	var focus_blend := 1.0 - exp(-focus_ease_speed * delta)
	_shoulder = lerpf(_shoulder, 1.0 if focusing else 0.0, focus_blend)
	_arm.spring_length = lerpf(_base_arm_length, focus_arm_length, _shoulder)
	if target != null:
		var goal := target.global_position + Vector3.UP * pivot_height \
				+ global_basis.x * focus_shoulder_offset * _shoulder
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	_update_speed_feedback(delta)


## Focus aim: ease behind the direction the player squared up in and settle
## over the right shoulder (offset applied in the follow goal above).
func _update_focus_view(delta: float) -> void:
	var dir := _targeting.focus_dir
	var desired_yaw := atan2(-dir.x, -dir.z)
	var blend := 1.0 - exp(-focus_ease_speed * delta)
	rotation.y = lerp_angle(rotation.y, desired_yaw, blend)
	_arm.rotation.x = lerpf(_arm.rotation.x, deg_to_rad(focus_pitch_degrees), blend)


## Locked: swing the rig onto the enemy→player line so the camera sits
## behind the player looking at the enemy (both in frame), and hold a mild
## downward pitch. Manual orbit is suspended; the rig still only yaws, so
## stick-forward keeps meaning "toward the enemy".
func _update_lock_view(delta: float) -> void:
	var to_lock := _lock.global_position - target.global_position
	to_lock.y = 0.0
	if to_lock.length() < 0.5:
		return
	var desired_yaw := atan2(-to_lock.x, -to_lock.z)
	var blend := 1.0 - exp(-lock_turn_speed * delta)
	rotation.y = lerp_angle(rotation.y, desired_yaw, blend)
	_arm.rotation.x = lerpf(_arm.rotation.x, deg_to_rad(lock_pitch_degrees), blend)


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
