extends PlayerState
## Impact window after a ground pound. While the window is open:
## jump converts the impact into a super jump, dash converts the stored fall
## speed into a large horizontal boost (Ultrakill-style slam storage). If the
## window expires the pound ends in a plain recovery.

var _window_left := 0.0
var _impact_speed := 0.0


func enter(msg: Dictionary = {}) -> void:
	_window_left = player.stats.pound_land_window
	_impact_speed = msg.get("impact_speed", player.stats.pound_fall_speed)
	player.velocity = Vector3.ZERO
	player.air_dash_available = true


func physics_update(delta: float) -> void:
	_window_left -= delta
	player.velocity.y = Player.GROUND_STICK_VELOCITY
	player.set_horizontal_velocity(Vector3.ZERO)
	player.desired_velocity = Vector3.ZERO
	player.move_and_slide()
	if player.consume_jump_buffer():
		_super_jump()
		return
	if Input.is_action_just_pressed(&"dash"):
		_momentum_boost()
		return
	if _window_left <= 0.0:
		state_machine.change_to(&"Idle")
	elif not player.is_on_floor():
		state_machine.change_to(&"Air")


func _super_jump() -> void:
	player.start_jump(player.stats.pound_jump_velocity)
	player.set_horizontal_velocity(player.move_dir * player.stats.run_speed * 0.5)
	state_machine.change_to(&"Air")


func _momentum_boost() -> void:
	var dir := player.move_dir
	if dir == Vector3.ZERO:
		dir = player.facing
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	var speed := clampf(
			_impact_speed * player.stats.pound_boost_factor,
			player.stats.dash_speed,
			player.stats.pound_boost_max)
	player.set_horizontal_velocity(dir * speed)
	player.velocity.y = player.stats.pound_boost_hop
	player.facing = dir
	state_machine.change_to(&"Air")
