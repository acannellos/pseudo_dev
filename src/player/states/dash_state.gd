extends PlayerState
## Flat horizontal burst. Dash speed is the *floor*, not the value: dashing
## while already faster keeps the higher speed, so dashes extend momentum
## chains instead of clamping them. Jumping out of a grounded dash keeps the
## full dash speed (dash-hop).
##
## Wavedash: an *air* dash that touches down and is cancelled into a jump
## within a tight window gains speed beyond the plain dash-hop keep — the
## higher-skill-ceiling refinement of the same dash→jump interaction.

var _time_left := 0.0
## Whether this dash launched airborne (only those can wavedash).
var _started_airborne := false
## Seconds since the dash first touched the floor; negative = not yet.
var _ground_time := -1.0


func enter(_msg: Dictionary = {}) -> void:
	_time_left = player.stats.dash_time
	_started_airborne = not player.is_on_floor()
	_ground_time = -1.0
	var dir := player.move_dir
	if dir == Vector3.ZERO:
		dir = player.facing
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	var speed := maxf(player.stats.dash_speed, player.horizontal_velocity().length())
	player.velocity = dir * speed
	player.facing = dir


func physics_update(delta: float) -> void:
	_time_left -= delta
	player.velocity.y = 0.0
	player.desired_velocity = player.velocity
	player.move_and_slide()
	if player.is_on_floor() and _ground_time < 0.0:
		_ground_time = 0.0
	elif _ground_time >= 0.0:
		_ground_time += delta
	var grounded := player.is_on_floor() or player.coyote_timer > 0.0
	if grounded and player.consume_jump_buffer():
		if _is_wavedash():
			var flat := player.horizontal_velocity()
			player.set_horizontal_velocity(
					flat.normalized() * (flat.length() + player.stats.wavedash_boost))
		player.start_jump()
		state_machine.change_to(&"Air")
		return
	if _time_left <= 0.0:
		state_machine.change_to(&"Run" if player.is_on_floor() else &"Air")


func _is_wavedash() -> bool:
	return _started_airborne and _ground_time >= 0.0 \
			and _ground_time <= player.stats.wavedash_window
