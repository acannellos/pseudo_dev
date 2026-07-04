extends PlayerState
## Skid turnaround: triggered by reversing input hard while running fast.
## Velocity bleeds down on its own deceleration curve while normal steering
## is locked out — the character plants and pivots instead of carving.
## Jumping during the skid converts it into a Turn Jump; letting it finish
## hands control back facing the new direction.

var _time_left := 0.0
## Direction the player asked for when the skid started; becomes the new
## facing on exit and the pop direction of a Turn Jump.
var _pivot_dir := Vector3.ZERO


func enter(_msg: Dictionary = {}) -> void:
	_time_left = player.stats.turnaround_max_time
	_pivot_dir = player.move_dir.normalized()
	player.notify_skid(player.horizontal_velocity().normalized())


func physics_update(delta: float) -> void:
	_time_left -= delta
	if player.move_dir != Vector3.ZERO:
		_pivot_dir = player.move_dir.normalized()
	player.velocity.y = Player.GROUND_STICK_VELOCITY
	var flat := player.horizontal_velocity()
	flat = flat.move_toward(Vector3.ZERO, player.stats.turnaround_decel * delta)
	player.set_horizontal_velocity(flat)
	player.desired_velocity = player.move_dir * player.stats.run_speed
	player.move_and_slide()
	if not player.is_on_floor():
		state_machine.change_to(&"Air")
		return
	if player.jump_buffer_timer > 0.0:
		player.consume_jump_buffer()
		state_machine.change_to(&"TurnJump", {"pivot_dir": _pivot_dir})
		return
	if Input.is_action_just_pressed(&"dash"):
		state_machine.change_to(&"Dash")
		return
	if flat.length() <= 0.4 or _time_left <= 0.0:
		player.facing = _pivot_dir
		if player.move_dir != Vector3.ZERO:
			state_machine.change_to(&"Run")
		else:
			state_machine.change_to(&"Idle")
