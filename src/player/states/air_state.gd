extends PlayerState
## Airborne: rising or falling. Handles variable jump height, air steering,
## coyote jumps, and landing resolution — including buffered bunny hops,
## which never leave this state (speed is preserved and rewarded instead of
## reset).

var _jump_cut_done := false


func enter(_msg: Dictionary = {}) -> void:
	_jump_cut_done = false


func physics_update(delta: float) -> void:
	if not _jump_cut_done and player.velocity.y > 0.0 \
			and Input.is_action_just_released(&"jump"):
		player.velocity.y *= player.stats.jump_cut_multiplier
		_jump_cut_done = true
	if player.coyote_timer > 0.0 and player.consume_jump_buffer():
		player.hop_chain = 0
		player.start_jump()
		_jump_cut_done = false
	if Input.is_action_just_pressed(&"ground_pound"):
		state_machine.change_to(&"GroundPound")
		return
	if Input.is_action_just_pressed(&"dash") and player.air_dash_available:
		player.air_dash_available = false
		state_machine.change_to(&"Dash")
		return
	player.apply_gravity(delta)
	player.air_steer(delta)
	var fall_speed := maxf(-player.velocity.y, 0.0)
	player.move_and_slide()
	if player.is_on_floor():
		_land(fall_speed)
		return
	if _should_wall_slide():
		state_machine.change_to(&"WallSlide")


func _land(impact_speed: float) -> void:
	player.time_since_landed = 0.0
	player.air_dash_available = true
	player.landed.emit(impact_speed)
	if player.jump_buffer_timer > 0.0:
		# Bunny hop: buffered jump on the landing frame keeps all horizontal
		# speed, earns a bonus, and immediately relaunches.
		player.consume_jump_buffer()
		player.hop_chain += 1
		player.apply_hop_bonus()
		player.start_jump()
		_jump_cut_done = false
		return
	if player.horizontal_velocity().length() > 0.5 or player.move_dir != Vector3.ZERO:
		state_machine.change_to(&"Run")
	else:
		state_machine.change_to(&"Idle")


func _should_wall_slide() -> bool:
	if not player.is_on_wall():
		return false
	if player.velocity.y > 0.5:
		return false
	if player.move_dir == Vector3.ZERO:
		return false
	var normal := player.get_wall_normal()
	return player.move_dir.dot(-normal) > -0.2
