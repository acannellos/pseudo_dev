class_name Player
extends CharacterBody3D
## Momentum-driven movement-platformer controller.
##
## This script owns shared data (cached input, timers, facing, tuning stats)
## and reusable physics helpers. The actual moves live in the [PlayerState]
## nodes under [PlayerStateMachine]; states call back into the helpers here,
## which keeps individual moves small and composable.

signal landed(impact_speed: float)

const FALL_LIMIT := -40.0
const FACING_TURN_SPEED := 14.0
## Small downward velocity used to stay glued to the floor in ground states.
const GROUND_STICK_VELOCITY := -2.0

@export var stats: MovementStats
## Optional explicit path to the camera rig; falls back to the
## "camera_rig" group when empty.
@export var camera_rig_path: NodePath

## Raw 2D movement input.
var move_input := Vector2.ZERO
## Camera-relative movement direction on the XZ plane (length <= 1).
var move_dir := Vector3.ZERO
## Input-driven target velocity, exposed for the debug vector draw.
var desired_velocity := Vector3.ZERO
## Horizontal direction the character model faces.
var facing := Vector3.FORWARD
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var time_since_landed := 999.0
## Consecutive bunny hops without breaking the chain.
var hop_chain := 0
var air_dash_available := true

var _camera_rig: Node3D
var _spawn_transform: Transform3D

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var visual: Node3D = $Visual


func _ready() -> void:
	if stats == null:
		stats = MovementStats.new()
	_spawn_transform = global_transform
	floor_max_angle = deg_to_rad(stats.walkable_slope_degrees)
	floor_snap_length = 0.6
	floor_constant_speed = true
	if not camera_rig_path.is_empty():
		_camera_rig = get_node_or_null(camera_rig_path) as Node3D
	if _camera_rig == null:
		_camera_rig = get_tree().get_first_node_in_group(&"camera_rig") as Node3D
	state_machine.setup(self)


func _physics_process(delta: float) -> void:
	_update_input()
	_update_timers(delta)
	state_machine.physics_update(delta)
	_update_facing(delta)
	_check_fall_respawn()


## Horizontal (XZ) part of the current velocity.
func horizontal_velocity() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func set_horizontal_velocity(flat: Vector3) -> void:
	velocity.x = flat.x
	velocity.z = flat.z


func apply_gravity(delta: float, gravity_scale := 1.0) -> void:
	velocity.y = maxf(
			velocity.y - stats.gravity * gravity_scale * delta,
			-stats.max_fall_speed)


func consume_jump_buffer() -> bool:
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		return true
	return false


## Sets vertical jump velocity. Never touches horizontal velocity, so every
## jump preserves momentum by construction.
func start_jump(jump_speed := -1.0) -> void:
	velocity.y = stats.jump_velocity if jump_speed < 0.0 else jump_speed
	coyote_timer = 0.0


## Speed reward for a correctly timed bunny hop.
func apply_hop_bonus() -> void:
	var flat := horizontal_velocity()
	var speed := flat.length()
	if speed < 1.0:
		return
	var new_speed := minf(speed + stats.bhop_speed_bonus, stats.bhop_max_speed)
	set_horizontal_velocity(flat.normalized() * maxf(new_speed, speed))


## Grounded steering. Below run speed this is a plain accelerate-toward-input
## model; above run speed the velocity direction is redirected toward input
## while its magnitude is preserved (minus a gentle overspeed drag).
## [param keep_momentum] suppresses friction/drag during the bunny-hop grace.
func ground_steer(delta: float, keep_momentum: bool) -> void:
	var flat := horizontal_velocity()
	var speed := flat.length()
	desired_velocity = move_dir * stats.run_speed
	if move_dir == Vector3.ZERO:
		if not keep_momentum:
			flat = flat.move_toward(Vector3.ZERO, stats.ground_decel * delta)
	elif speed <= stats.run_speed + 0.1:
		flat = flat.move_toward(desired_velocity, stats.ground_accel * delta)
	else:
		flat = _redirect(flat, speed, stats.turn_speed * delta)
		if not keep_momentum:
			var new_speed := maxf(speed - stats.overspeed_drag * delta, stats.run_speed)
			flat = flat.normalized() * new_speed
	set_horizontal_velocity(flat)


## Mid-air steering: meaningful control without free speed. Below air speed
## it accelerates toward input; above it, input only redirects the existing
## momentum (magnitude preserved, no gain, no loss).
func air_steer(delta: float) -> void:
	var flat := horizontal_velocity()
	var speed := flat.length()
	desired_velocity = move_dir * maxf(stats.air_speed, speed)
	if move_dir == Vector3.ZERO:
		return
	if speed <= stats.air_speed:
		flat = flat.move_toward(move_dir * stats.air_speed, stats.air_accel * delta)
	else:
		flat = _redirect(flat, speed, stats.air_turn_speed * delta)
	set_horizontal_velocity(flat)


## Adds gravity-along-slope acceleration while moving on a walkable incline:
## downhill movement builds speed (up to a slope cap), uphill movement pays
## for altitude. Flat ground is untouched.
func apply_slope_acceleration(delta: float) -> void:
	if not is_on_floor():
		return
	var normal := get_floor_normal()
	if normal.y > 0.999:
		return
	var flat := horizontal_velocity()
	var speed := flat.length()
	if speed < 0.5:
		return
	var slide_dir := Vector3.DOWN.slide(normal)
	var sin_theta := slide_dir.length()
	if sin_theta < 0.001:
		return
	var downhill := Vector3(slide_dir.x, 0.0, slide_dir.z).normalized()
	var accel := stats.gravity * stats.slope_accel_factor * sin_theta
	var new_flat := flat + downhill * accel * delta
	if new_flat.length() <= maxf(speed, stats.slope_max_speed):
		set_horizontal_velocity(new_flat)


func respawn() -> void:
	global_transform = _spawn_transform
	velocity = Vector3.ZERO
	hop_chain = 0
	air_dash_available = true
	state_machine.change_to(&"Air")


## Rotates [param flat] (speed [param speed]) toward the current input
## direction by at most [param max_turn] radians, preserving magnitude.
func _redirect(flat: Vector3, speed: float, max_turn: float) -> Vector3:
	var dir := flat / speed
	var angle := dir.signed_angle_to(move_dir.normalized(), Vector3.UP)
	dir = dir.rotated(Vector3.UP, clampf(angle, -max_turn, max_turn))
	return dir * speed


func _update_input() -> void:
	move_input = Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if _camera_rig != null:
		forward = -_camera_rig.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		right = _camera_rig.global_basis.x
		right.y = 0.0
		right = right.normalized()
	move_dir = right * move_input.x - forward * move_input.y
	if move_dir.length() > 1.0:
		move_dir = move_dir.normalized()
	desired_velocity = move_dir * stats.run_speed
	if Input.is_action_just_pressed(&"jump"):
		jump_buffer_timer = stats.jump_buffer_time


func _update_timers(delta: float) -> void:
	jump_buffer_timer = maxf(jump_buffer_timer - delta, 0.0)
	if is_on_floor():
		coyote_timer = stats.coyote_time
	else:
		coyote_timer = maxf(coyote_timer - delta, 0.0)
	time_since_landed += delta


func _update_facing(delta: float) -> void:
	var target := facing
	var flat := horizontal_velocity()
	if flat.length() > 1.0:
		target = flat.normalized()
	elif move_dir != Vector3.ZERO:
		target = move_dir.normalized()
	var angle := facing.signed_angle_to(target, Vector3.UP)
	var max_turn := FACING_TURN_SPEED * delta
	facing = facing.rotated(Vector3.UP, clampf(angle, -max_turn, max_turn)).normalized()
	visual.look_at(visual.global_position + facing)


func _check_fall_respawn() -> void:
	if global_position.y < FALL_LIMIT:
		respawn()
