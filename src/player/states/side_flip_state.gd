extends AirState
## Side-flip: jump out of a low-speed strafing input. Extra height with a
## small lateral pop in the strafe direction — like the backflip, a height
## tool with no forward commitment.


func enter(msg: Dictionary = {}) -> void:
	super.enter(msg)
	player.start_jump(
			player.stats.jump_velocity * player.stats.flip_height_multiplier)
	var pop_dir := player.move_dir.normalized() \
			if player.move_dir != Vector3.ZERO else player.facing
	player.set_horizontal_velocity(pop_dir * player.stats.sideflip_pop_speed)
	player.hop_chain = 0
