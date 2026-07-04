class_name Player
extends CharacterBody3D
## Momentum-driven movement-platformer controller.
##
## This script owns shared data (cached input, timers, facing, tuning stats)
## and reusable physics helpers. The actual moves live in the [PlayerState]
## nodes under [PlayerStateMachine]; states call back into the helpers here,
## which keeps individual moves small and composable.

signal landed(impact_speed: float)
## FX hook: emitted when a skid turnaround plants. [param direction] is the
## horizontal velocity direction being bled off (dust should kick this way).
signal skid_started(direction: Vector3)

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
## Whether the crouch/slide action is currently held.
var crouch_held := false
var jump_buffer_timer := 0.0
var coyote_timer := 0.0
var time_since_landed := 999.0
## Consecutive bunny hops without breaking the chain.
var hop_chain := 0
## Triple jump: which jump of the chain was last performed (1–3, 0 = none).
var jump_chain := 0
var air_dash_available := true

var _camera_rig: Node3D
var _spawn_transform: Transform3D
var _standing_capsule_height := 0.0
var _standing_shape_center_y := 0.0

@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var visual: Node3D = $Visual
@onready var collision_shape: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	if stats == null:
		stats = MovementStats.new()
	_spawn_transform = global_transform
	var capsule := collision_shape.shape as CapsuleShape3D
	_standing_capsule_height = capsule.height
	_standing_shape_center_y = collision_shape.position.y
	floor_max_angle = deg_to_rad(stats.walkable_slope_degrees)
	floor_snap_length = 0.6
	floor_constant_speed = true
	if not camera_rig_path.is_empty():
		_camera_rig = get_node_or_null(camera_rig_path) as Node3D
	if _camera_rig == null:
		_camera_rig = get_tree().get_first_node_in_group(&"camera_rig") as Node3D
	state_machine.setup(self)
	state_machine.state_changed.connect(_on_state_changed)


## The triple-jump chain only survives plain locomotion: any other state
## (dash, slide, skid, wall contact, jump variants…) breaks it in one place
## instead of every state remembering to reset it.
func _on_state_changed(_previous: StringName, current: StringName) -> void:
	if current != &"Air" and current != &"Run":
		jump_chain = 0


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


## Context-sensitive grounded jump variants: the name of the flip state the
## current input asks for, or &"" for a plain jump. Backflip = near standstill
## with input opposing facing; side-flip = low-speed strafe input.
func flip_jump_variant() -> StringName:
	if move_dir == Vector3.ZERO:
		return &""
	var speed := horizontal_velocity().length()
	var toward := move_dir.normalized().dot(facing)
	if speed <= stats.backflip_max_speed and toward < -0.6:
		return &"Backflip"
	if speed <= stats.sideflip_max_speed and absf(toward) <= 0.35:
		return &"SideFlip"
	return &""


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


## Slide steering: low friction with a sustain floor (holding the slide never
## fully arrests you), and only a gentle, committed redirect toward input.
func slide_steer(delta: float) -> void:
	var flat := horizontal_velocity()
	var speed := flat.length()
	desired_velocity = move_dir * stats.run_speed
	if speed <= 0.01:
		return
	var new_speed := maxf(speed - stats.slide_friction * delta,
			minf(speed, stats.slide_sustain_speed))
	flat = flat.normalized() * new_speed
	if move_dir != Vector3.ZERO:
		flat = _redirect(flat, new_speed, stats.slide_turn_speed * delta)
	set_horizontal_velocity(flat)


## Swaps between the standing and slide capsule. The lowered capsule keeps
## the same bottom point so the body never sinks into the floor.
func set_crouch_hitbox(crouched: bool) -> void:
	var capsule := collision_shape.shape as CapsuleShape3D
	var bottom := _standing_shape_center_y - _standing_capsule_height * 0.5
	var height: float = stats.slide_capsule_height if crouched else _standing_capsule_height
	capsule.height = height
	collision_shape.position.y = bottom + height * 0.5


## Whether there is headroom to restore the standing capsule.
func can_stand_up() -> bool:
	var bottom := _standing_shape_center_y - _standing_capsule_height * 0.5
	var standing_top := bottom + _standing_capsule_height
	var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * stats.slide_capsule_height,
			global_position + Vector3.UP * (standing_top + 0.05),
			collision_mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## FX hook call site for the skid turnaround (dust decal / lean listeners).
func notify_skid(direction: Vector3) -> void:
	skid_started.emit(direction)


## Shared wall kick: out + up, tangential speed mostly preserved, air dash
## refunded. Used by WallSlide and WallRun; the calling state still owns the
## transition back to Air.
func perform_wall_kick(wall_normal: Vector3) -> void:
	var tangential := horizontal_velocity().slide(wall_normal)
	var out := Vector3(wall_normal.x, 0.0, wall_normal.z).normalized()
	var flat := tangential * 0.9 + out * stats.wall_kick_out_speed
	velocity = Vector3(flat.x, stats.wall_kick_up_speed, flat.z)
	air_dash_available = true
	facing = out


## Probes for a grabbable ledge lip in [param dir] (horizontal). Returns an
## empty Dictionary or {"ledge_point": Vector3, "wall_normal": Vector3} —
## same raycast pattern as the wall-contact detection, done explicitly so
## the grab can aim above the current collision contact.
func find_ledge(dir: Vector3) -> Dictionary:
	dir = Vector3(dir.x, 0.0, dir.z)
	if dir.length() < 0.1:
		return {}
	dir = dir.normalized()
	var space := get_world_3d().direct_space_state
	var chest := global_position + Vector3.UP * 1.0
	var wall_query := PhysicsRayQueryParameters3D.create(
			chest, chest + dir * stats.ledge_reach, collision_mask, [get_rid()])
	var wall_hit := space.intersect_ray(wall_query)
	if wall_hit.is_empty():
		return {}
	var wall_normal: Vector3 = wall_hit["normal"]
	if absf(wall_normal.y) > 0.3:
		return {}
	# Drop a ray from above the lip, just past the wall face, to find the top.
	var over := (wall_hit["position"] as Vector3) - wall_normal * 0.25
	var top := Vector3(over.x, global_position.y + stats.ledge_max_height + 0.1, over.z)
	var floor_query := PhysicsRayQueryParameters3D.create(
			top, Vector3(top.x, global_position.y + stats.ledge_min_height, top.z),
			collision_mask, [get_rid()])
	var floor_hit := space.intersect_ray(floor_query)
	if floor_hit.is_empty():
		return {}
	if (floor_hit["normal"] as Vector3).y < cos(floor_max_angle):
		return {}
	return {"ledge_point": floor_hit["position"], "wall_normal": wall_normal}


## External launch (bounce pads): *sets* velocity along [param direction].
## A straight-up pad keeps horizontal flow so bounces chain into momentum;
## an angled pad fully commits the new direction. Refunds the air dash, so
## a bounce chains into dash or pound conversions like a pound landing does.
func bounce(direction: Vector3, speed: float) -> void:
	var dir := direction.normalized()
	if state_machine.current_state != null \
			and state_machine.current_state.name == &"GroundPound":
		speed *= stats.bounce_pound_multiplier
	if dir.dot(Vector3.UP) > 0.99:
		velocity = horizontal_velocity() + Vector3.UP * speed
	else:
		velocity = dir * speed
	air_dash_available = true
	coyote_timer = 0.0
	state_machine.change_to(&"Air")


## External flat boost (speed boosters): adds [param amount] along the
## current movement (or facing) direction, capped at the booster ceiling.
func apply_speed_boost(amount: float) -> void:
	var flat := horizontal_velocity()
	var dir := flat.normalized() if flat.length() > 0.5 else facing
	var speed := minf(flat.length() + amount, maxf(stats.booster_max_speed, flat.length()))
	set_horizontal_velocity(dir * speed)
	facing = dir


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
	jump_chain = 0
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
	crouch_held = Input.is_action_pressed(&"crouch")
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
