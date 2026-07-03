extends PlayerState
## Ground pound: a short windup hang, then a fast vertical slam. Impact hands
## off to PoundLand, where the stored fall speed can be converted into
## outward momentum. Pressing dash mid-fall cancels the pound into an air
## dash (early conversion).

var _windup_left := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_windup_left = player.stats.pound_windup_time
	player.velocity = Vector3.ZERO
	player.desired_velocity = Vector3.ZERO


func physics_update(delta: float) -> void:
	player.desired_velocity = Vector3.ZERO
	if _windup_left > 0.0:
		_windup_left -= delta
		player.velocity = Vector3.ZERO
		player.move_and_slide()
		return
	if Input.is_action_just_pressed(&"dash") and player.air_dash_available:
		player.air_dash_available = false
		state_machine.change_to(&"Dash")
		return
	player.velocity = Vector3(0.0, -player.stats.pound_fall_speed, 0.0)
	player.move_and_slide()
	if player.is_on_floor():
		state_machine.change_to(
				&"PoundLand", {"impact_speed": player.stats.pound_fall_speed})
