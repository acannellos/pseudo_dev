extends PlayerState
## Crouch slide: hold crouch while grounded to drop the capsule and coast on
## reduced friction. Speed decays to a sustain floor, never to zero, so a
## slide is always a momentum tool, not a brake.
##
## Jumping out converts by intent: a *fresh* slide (crouch+jump pressed
## together, within the combo window) at speed launches a Long Jump; an
## *established* slide launches a Slide-Hop. Long-jump landings re-enter
## this state fresh, which is exactly what lets long jumps chain.

## Seconds this slide has been active; drives the long-jump combo window.
var _age := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_age = 0.0
	player.set_crouch_hitbox(true)


func exit() -> void:
	player.set_crouch_hitbox(false)


func physics_update(delta: float) -> void:
	_age += delta
	player.velocity.y = Player.GROUND_STICK_VELOCITY
	player.slide_steer(delta)
	player.apply_slope_acceleration(delta)
	player.move_and_slide()
	if not player.is_on_floor():
		state_machine.change_to(&"Air")
		return
	if player.jump_buffer_timer > 0.0 and player.can_stand_up():
		player.consume_jump_buffer()
		_jump_out()
		return
	if Input.is_action_just_pressed(&"dash") and player.can_stand_up():
		state_machine.change_to(&"Dash")
		return
	if not player.crouch_held and player.can_stand_up():
		if player.move_dir != Vector3.ZERO \
				or player.horizontal_velocity().length() > 0.5:
			state_machine.change_to(&"Run")
		else:
			state_machine.change_to(&"Idle")


func _jump_out() -> void:
	var speed := player.horizontal_velocity().length()
	if _age <= player.stats.long_jump_combo_window \
			and speed >= player.stats.long_jump_min_speed:
		state_machine.change_to(&"LongJump")
	elif speed > 0.5:
		state_machine.change_to(&"SlideHop")
	else:
		# Jumping from a crouched standstill: plain jump.
		player.hop_chain = 0
		player.start_jump()
		state_machine.change_to(&"Air")
