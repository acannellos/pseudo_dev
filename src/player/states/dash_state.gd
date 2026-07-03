extends PlayerState
## Flat horizontal burst. Dash speed is the *floor*, not the value: dashing
## while already faster keeps the higher speed, so dashes extend momentum
## chains instead of clamping them. Jumping out of a grounded dash keeps the
## full dash speed (dash-hop).

var _time_left := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_time_left = player.stats.dash_time
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
	var grounded := player.is_on_floor() or player.coyote_timer > 0.0
	if grounded and player.consume_jump_buffer():
		player.start_jump()
		state_machine.change_to(&"Air")
		return
	if _time_left <= 0.0:
		state_machine.change_to(&"Run" if player.is_on_floor() else &"Air")
