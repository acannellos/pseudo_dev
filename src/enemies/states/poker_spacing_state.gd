extends EnemyState
## Poker spacing (Lizalfos-style): he owns the distance. Inside his comfort
## band he backpedals, outside it he closes, in the sweet spot he strafes —
## always facing you, never committing. Chasing him is wrong; the fight is
## waiting out his patience: on his own timer he darts in to poke, and the
## recovery after that poke is your opening.

## The distance he tries to hold.
@export var preferred_distance := 4.5
@export var backpedal_speed_scale := 1.5
## Seconds of strafe before flipping direction.
@export var strafe_flip_time := 1.6
## Random wait band before he commits to a poke.
@export var attack_wait_min := 1.8
@export var attack_wait_max := 3.2

var _attack_wait := 0.0
var _strafe_left := 0.0
var _strafe_sign := 1.0


func enter(_msg: Dictionary = {}) -> void:
	_attack_wait = randf_range(attack_wait_min, attack_wait_max)
	_strafe_left = strafe_flip_time
	_strafe_sign = 1.0 if randf() < 0.5 else -1.0


func physics_update(delta: float) -> void:
	enemy.apply_enemy_gravity(delta)
	enemy.face_player(delta, 8.0)
	var dist := enemy.player_distance()
	var to_player := enemy.dir_to_player()
	var move := Vector3.ZERO
	if dist < preferred_distance - 0.4:
		move = -to_player * enemy.move_speed * backpedal_speed_scale
	elif dist > preferred_distance + 1.6:
		move = to_player * enemy.move_speed
	else:
		_strafe_left -= delta
		if _strafe_left <= 0.0:
			_strafe_left = strafe_flip_time
			_strafe_sign = -_strafe_sign
		move = to_player.cross(Vector3.UP) * _strafe_sign * enemy.move_speed * 0.6
	enemy.velocity.x = move.x
	enemy.velocity.z = move.z
	enemy.move_and_slide()
	if not enemy.player_in_range(enemy.disengage_range):
		machine.change_to(&"Patrol")
		return
	_attack_wait -= delta
	if _attack_wait <= 0.0:
		machine.change_to(&"Poke")
