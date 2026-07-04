extends PlayerState
## Grounded locomotion: momentum-preserving steering, slope acceleration and
## the bunny-hop friction grace window. Also the launch point for the
## grounded techs: crouch slides, skid turnarounds and long jumps.


func physics_update(delta: float) -> void:
	var in_bhop_grace := player.time_since_landed < player.stats.bhop_window
	if not in_bhop_grace and player.hop_chain > 0:
		player.hop_chain = 0
	if player.jump_chain > 0 \
			and player.time_since_landed > player.stats.triple_jump_window:
		player.jump_chain = 0
	player.velocity.y = Player.GROUND_STICK_VELOCITY
	player.ground_steer(delta, in_bhop_grace)
	player.apply_slope_acceleration(delta)
	player.move_and_slide()
	if not player.is_on_floor():
		state_machine.change_to(&"Air")
		return
	if player.consume_jump_buffer():
		_jump(in_bhop_grace)
		return
	if Input.is_action_just_pressed(&"dash"):
		state_machine.change_to(&"Dash")
		return
	if _should_turnaround(in_bhop_grace):
		state_machine.change_to(&"Turnaround")
		return
	if player.crouch_held:
		state_machine.change_to(&"Slide")
		return
	if player.move_dir == Vector3.ZERO and player.horizontal_velocity().length() < 0.5:
		state_machine.change_to(&"Idle")


func _jump(in_bhop_grace: bool) -> void:
	# Crouch + jump above the speed threshold is a Long Jump — a deliberate
	# combo, distinct from plain jump timing (bhop) handled below.
	if player.crouch_held and player.horizontal_velocity().length() \
			>= player.stats.long_jump_min_speed:
		state_machine.change_to(&"LongJump")
		return
	var flip: StringName = player.flip_jump_variant()
	if flip != &"":
		state_machine.change_to(flip)
		return
	if in_bhop_grace:
		# Bunny hop wins the landing frame; it never advances the triple.
		player.hop_chain += 1
		player.jump_chain = 0
		player.apply_hop_bonus()
		player.start_jump()
		state_machine.change_to(&"Air")
		return
	player.hop_chain = 0
	_triple_jump()


## Consecutive grounded jumps climb: each landing re-jumped inside the
## window is higher than the last, capping at the third.
func _triple_jump() -> void:
	if player.move_dir != Vector3.ZERO \
			and player.time_since_landed <= player.stats.triple_jump_window:
		player.jump_chain = mini(player.jump_chain + 1, 3)
	else:
		player.jump_chain = 1
	var height := player.stats.jump_velocity
	match player.jump_chain:
		2: height *= player.stats.triple_jump_second_multiplier
		3: height *= player.stats.triple_jump_third_multiplier
	player.start_jump(height)
	state_machine.change_to(&"Air")


## Grounded-trigger skid: fast, and input reversed hard against velocity.
## Gated off the bunny-hop landing window so the two never compete.
func _should_turnaround(in_bhop_grace: bool) -> bool:
	if in_bhop_grace or player.move_dir == Vector3.ZERO:
		return false
	var flat := player.horizontal_velocity()
	if flat.length() < player.stats.turnaround_min_speed:
		return false
	return rad_to_deg(flat.angle_to(player.move_dir)) \
			>= player.stats.turnaround_angle_degrees
