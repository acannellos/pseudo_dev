extends PlayerState
## Grounded with no meaningful speed. Bleeds off residual velocity and waits
## for input. Jumping with directional intent from a standstill picks the
## flip variants (backflip / side-flip).


func physics_update(delta: float) -> void:
	player.velocity.y = Player.GROUND_STICK_VELOCITY
	player.ground_steer(delta, false)
	player.move_and_slide()
	if not player.is_on_floor():
		state_machine.change_to(&"Air")
		return
	if player.consume_jump_buffer():
		var flip: StringName = player.flip_jump_variant()
		if flip != &"":
			state_machine.change_to(flip)
			return
		player.hop_chain = 0
		player.start_jump()
		state_machine.change_to(&"Air")
		return
	if Input.is_action_just_pressed(&"dash"):
		state_machine.change_to(&"Dash")
		return
	if player.move_dir != Vector3.ZERO or player.horizontal_velocity().length() > 0.5:
		state_machine.change_to(&"Run")
