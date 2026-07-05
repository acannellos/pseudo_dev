extends AirState
## Backflip: jump while pushing away from facing at a near standstill.
## Extra height over a normal jump with a small backward pop — vertical
## reach without forward commitment (unlike the Long Jump).


func enter(msg: Dictionary = {}) -> void:
	super.enter(msg)
	player.start_jump(
			player.stats.jump_velocity * player.stats.flip_height_multiplier)
	var pop_dir := player.move_dir.normalized() \
			if player.move_dir != Vector3.ZERO else -player.facing
	player.set_horizontal_velocity(pop_dir * player.stats.backflip_pop_speed)
	player.hop_chain = 0
	player.notify_tech(&"backflip")
