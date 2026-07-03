extends PlayerState
## Grounded locomotion: momentum-preserving steering, slope acceleration and
## the bunny-hop friction grace window.


func physics_update(delta: float) -> void:
	var in_bhop_grace := player.time_since_landed < player.stats.bhop_window
	if not in_bhop_grace and player.hop_chain > 0:
		player.hop_chain = 0
	player.velocity.y = Player.GROUND_STICK_VELOCITY
	player.ground_steer(delta, in_bhop_grace)
	player.apply_slope_acceleration(delta)
	player.move_and_slide()
	if not player.is_on_floor():
		state_machine.change_to(&"Air")
		return
	if player.consume_jump_buffer():
		if in_bhop_grace:
			player.hop_chain += 1
			player.apply_hop_bonus()
		else:
			player.hop_chain = 0
		player.start_jump()
		state_machine.change_to(&"Air")
		return
	if Input.is_action_just_pressed(&"dash"):
		state_machine.change_to(&"Dash")
		return
	if player.move_dir == Vector3.ZERO and player.horizontal_velocity().length() < 0.5:
		state_machine.change_to(&"Idle")
