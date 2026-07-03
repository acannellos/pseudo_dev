extends PlayerState
## Sliding down a wall while holding toward it. Jump performs a wall kick
## that pushes off the wall, preserves tangential speed, and refunds the air
## dash — chaining kicks between two walls climbs a chimney.

var _wall_normal := Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	_wall_normal = player.get_wall_normal()


func physics_update(delta: float) -> void:
	if player.is_on_wall():
		_wall_normal = player.get_wall_normal()
	player.apply_gravity(delta, player.stats.wall_slide_gravity_scale)
	player.velocity.y = maxf(player.velocity.y, -player.stats.wall_slide_fall_speed)
	var tangential := player.horizontal_velocity().slide(_wall_normal)
	tangential = tangential.move_toward(Vector3.ZERO, player.stats.wall_friction * delta)
	player.set_horizontal_velocity(tangential - _wall_normal * 2.0)
	player.desired_velocity = player.move_dir * player.stats.run_speed
	player.move_and_slide()
	if player.consume_jump_buffer():
		_wall_kick()
		return
	if player.is_on_floor():
		state_machine.change_to(&"Run")
		return
	if not player.is_on_wall():
		state_machine.change_to(&"Air")
		return
	if player.move_dir != Vector3.ZERO and player.move_dir.dot(-_wall_normal) < -0.5:
		state_machine.change_to(&"Air")


func _wall_kick() -> void:
	var tangential := player.horizontal_velocity().slide(_wall_normal)
	var out := Vector3(_wall_normal.x, 0.0, _wall_normal.z).normalized()
	var flat := tangential * 0.9 + out * player.stats.wall_kick_out_speed
	player.velocity = Vector3(flat.x, player.stats.wall_kick_up_speed, flat.z)
	player.air_dash_available = true
	player.facing = out
	state_machine.change_to(&"Air")
