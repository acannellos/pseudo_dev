extends AirState
## Turn Jump: jumping during a skid turnaround. Higher apex than a normal
## jump plus a small forward pop in the new facing direction — the reward
## for planting a hard reversal instead of carving around. Flight behaves
## like a normal jump (full air control); only the launch differs.


func enter(msg: Dictionary = {}) -> void:
	super.enter(msg)
	var pivot_dir: Vector3 = msg.get("pivot_dir", -player.facing)
	if pivot_dir == Vector3.ZERO:
		pivot_dir = -player.facing
	pivot_dir = Vector3(pivot_dir.x, 0.0, pivot_dir.z).normalized()
	player.start_jump(
			player.stats.jump_velocity * player.stats.turn_jump_height_multiplier)
	player.set_horizontal_velocity(
			pivot_dir * player.stats.turn_jump_forward_speed)
	player.facing = pivot_dir
	player.hop_chain = 0
