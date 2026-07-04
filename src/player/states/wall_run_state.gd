extends PlayerState
## Wall run: hitting a wall with enough along-wall speed converts the fall
## into a brief run along the surface — a speed tool, distinct from the
## low-speed Wall Slide (same wall-contact detection, gated on incoming
## tangential speed). Jump kicks off (shared wall kick: out + up, tangential
## speed preserved, air dash refunded); running out of time or speed decays
## into a Wall Slide if still holding toward the wall, otherwise Air.

var _wall_normal := Vector3.ZERO
var _time_left := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_wall_normal = player.get_wall_normal()
	_time_left = player.stats.wall_run_time
	# Commit velocity to the wall tangent, preserving its magnitude, and add
	# a small lift so the run carries across gaps in the wall.
	var flat := player.horizontal_velocity()
	var tangential := flat.slide(_wall_normal)
	if tangential.length() > 0.1:
		player.set_horizontal_velocity(tangential.normalized() * flat.length())
	player.velocity.y = maxf(player.velocity.y, player.stats.wall_run_up_boost)


func physics_update(delta: float) -> void:
	_time_left -= delta
	if player.is_on_wall():
		_wall_normal = player.get_wall_normal()
	player.apply_gravity(delta, player.stats.wall_run_gravity_scale)
	# Keep the run glued to and aligned with the wall as it curves.
	var flat := player.horizontal_velocity()
	var tangential := flat.slide(_wall_normal)
	if tangential.length() > 0.1:
		tangential = tangential.normalized() * flat.length()
	player.set_horizontal_velocity(tangential - _wall_normal * 2.0)
	player.desired_velocity = tangential
	player.facing = tangential.normalized() if tangential.length() > 0.5 else player.facing
	player.move_and_slide()
	if player.consume_jump_buffer():
		player.perform_wall_kick(_wall_normal)
		state_machine.change_to(&"Air")
		return
	if player.is_on_floor():
		state_machine.change_to(&"Run")
		return
	if not player.is_on_wall():
		state_machine.change_to(&"Air")
		return
	var speed := player.horizontal_velocity().slide(_wall_normal).length()
	if _time_left <= 0.0 or speed < player.stats.wall_run_min_speed * 0.5:
		# Run exhausted: decay into a slide if still holding toward the wall.
		if player.move_dir != Vector3.ZERO \
				and player.move_dir.dot(-_wall_normal) > -0.2:
			state_machine.change_to(&"WallSlide")
		else:
			state_machine.change_to(&"Air")
