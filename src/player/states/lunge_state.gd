extends PlayerState
## Lunge attack (OoT jump attack): pressing Attack while Z-targeting on the
## ground leaps at the enemy with an overhand slice. Flight is committed —
## no steering, like the Long Jump — and landing holds a short recovery
## beat before control returns, which is what makes targeted combat
## deliberate instead of mashy. The swing itself (hitbox, damage, VFX) is
## run by [CombatController], which is also who transitions us in.

var _recover_left := -1.0


func enter(msg: Dictionary = {}) -> void:
	var dir: Vector3 = msg.get("dir", player.facing)
	dir = Vector3(dir.x, 0.0, dir.z).normalized()
	player.velocity = dir * player.stats.lunge_speed \
			+ Vector3.UP * player.stats.lunge_up_speed
	player.facing = dir
	player.coyote_timer = 0.0
	player.hop_chain = 0
	_recover_left = -1.0


func physics_update(delta: float) -> void:
	if _recover_left >= 0.0:
		_recover(delta)
		return
	player.apply_gravity(delta)
	player.desired_velocity = player.horizontal_velocity()
	player.move_and_slide()
	if player.is_on_floor() and player.velocity.y <= 0.0:
		player.time_since_landed = 0.0
		player.landed.emit(maxf(-player.velocity.y, 0.0))
		player.set_horizontal_velocity(player.horizontal_velocity() * 0.25)
		_recover_left = player.stats.lunge_recovery_time


func _recover(delta: float) -> void:
	_recover_left -= delta
	player.velocity.y = Player.GROUND_STICK_VELOCITY
	player.set_horizontal_velocity(player.horizontal_velocity()
			.move_toward(Vector3.ZERO, player.stats.ground_decel * delta))
	player.move_and_slide()
	if _recover_left <= 0.0:
		if player.move_dir != Vector3.ZERO:
			state_machine.change_to(&"Run")
		else:
			state_machine.change_to(&"Idle")
