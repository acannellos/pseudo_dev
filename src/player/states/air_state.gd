class_name AirState
extends PlayerState
## Airborne: rising or falling. Handles variable jump height, air steering,
## coyote jumps, and landing resolution — including buffered bunny hops,
## which never leave this state (speed is preserved and rewarded instead of
## reset).
##
## Jump variants that launch differently but fly like a normal jump
## (Turn Jump, Slide-Hop, flips) extend this class: they override
## [method enter] for their launch and inherit steering, jump cut, and
## landing resolution. A bunny-hop relaunch from a variant hands control
## back to plain Air so the variant's animation does not linger across hops.

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
	if _try_ledge_grab():
		return
	_resolve_wall_contact()


func _land(impact_speed: float) -> void:
	player.time_since_landed = 0.0
	player.air_dash_available = true
	player.landed.emit(impact_speed)
	if player.jump_buffer_timer > 0.0:
		# Bunny hop: buffered jump on the landing frame keeps all horizontal
		# speed, earns a bonus, and immediately relaunches.
		player.consume_jump_buffer()
		player.hop_chain += 1
		player.jump_chain = 0
		player.apply_hop_bonus()
		player.start_jump()
		_jump_cut_done = false
		if name != &"Air":
			state_machine.change_to(&"Air")
		return
	if player.horizontal_velocity().length() > 0.5 or player.move_dir != Vector3.ZERO:
		state_machine.change_to(&"Run")
	else:
		state_machine.change_to(&"Idle")


## Grabs a ledge lip ahead when near apex or falling and moving toward it.
func _try_ledge_grab() -> bool:
	if player.velocity.y > player.stats.ledge_grab_max_rise_speed:
		return false
	var probe_dir := player.horizontal_velocity()
	if probe_dir.length() < 1.0:
		probe_dir = player.move_dir
	var ledge: Dictionary = player.find_ledge(probe_dir)
	if ledge.is_empty():
		return false
	state_machine.change_to(&"LedgeGrab", ledge)
	return true


## Wall contact splits on incoming along-wall speed: fast enough runs the
## wall (WallRun), low/no speed while falling slides it (WallSlide).
func _resolve_wall_contact() -> void:
	if not player.is_on_wall():
		return
	if player.move_dir == Vector3.ZERO:
		return
	var normal := player.get_wall_normal()
	if player.move_dir.dot(-normal) <= -0.2:
		return
	var tangential := player.horizontal_velocity().slide(normal)
	if tangential.length() >= player.stats.wall_run_min_speed:
		state_machine.change_to(&"WallRun")
	elif player.velocity.y <= 0.5:
		state_machine.change_to(&"WallSlide")
