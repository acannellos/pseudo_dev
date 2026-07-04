extends PlayerState
## Long Jump: crouch + jump above a speed threshold. A flatter, longer arc
## with a horizontal boost — and no air control: velocity is committed at
## launch, which is what separates it from a bunny hop (bhop = keep speed on
## a normal landing; long jump = spend a committed jump to buy distance).
## Lands into a Slide; if enough speed survives, jumping again immediately
## re-triggers, so long jumps chain like Mario 64's.


func enter(_msg: Dictionary = {}) -> void:
	var flat := player.horizontal_velocity()
	var dir := flat.normalized() if flat.length() > 0.5 else player.facing
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	var speed := minf(
			flat.length() + player.stats.long_jump_boost,
			player.stats.long_jump_max_speed)
	player.set_horizontal_velocity(dir * speed)
	player.velocity.y = player.stats.long_jump_velocity
	player.facing = dir
	player.coyote_timer = 0.0
	player.hop_chain = 0


func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	# Committed flight: input is ignored, so show the actual velocity as the
	# intent in the debug draw instead of a misleading steering vector.
	player.desired_velocity = player.horizontal_velocity()
	if Input.is_action_just_pressed(&"ground_pound"):
		state_machine.change_to(&"GroundPound")
		return
	var fall_speed := maxf(-player.velocity.y, 0.0)
	player.move_and_slide()
	if player.is_on_floor():
		_land(fall_speed)
		return
	if player.is_on_wall():
		# Bonk: the committed arc is over; give control back to Air.
		state_machine.change_to(&"Air")


func _land(impact_speed: float) -> void:
	player.time_since_landed = 0.0
	player.air_dash_available = true
	player.landed.emit(impact_speed)
	# Recover into the slide; with enough speed and a buffered jump the slide
	# immediately re-launches the next long jump in the chain.
	state_machine.change_to(&"Slide")
