extends EnemyState
## The poker's commitment, in beats: DART in fast, WINDUP flash (the
## parry-read moment), STAB with a short shove, then OVEREXTEND — a long
## still beat where the spear is buried and he can't defend. That window is
## the whole design: you make him whiff or eat the poke, and you spend his
## recovery. He hops back and returns to spacing on his own.

@export var dart_speed := 7.0
## Dart ends inside this distance (or on timeout).
@export var dart_stop_distance := 1.7
@export var dart_max_time := 0.6
@export var windup_time := 0.28
@export var stab_time := 0.22
@export var stab_reach := 2.0
## The opening. Long on purpose.
@export var overextend_time := 1.1
@export var hop_back_time := 0.35
@export var hop_back_speed := 6.0

enum Phase { DART, WINDUP, STAB, OVEREXTEND, HOP_BACK }

var _phase := Phase.DART
var _timer := 0.0
var _stab_hit_done := false


func enter(_msg: Dictionary = {}) -> void:
	_phase = Phase.DART
	_timer = dart_max_time
	_stab_hit_done = false


func physics_update(delta: float) -> void:
	enemy.apply_enemy_gravity(delta)
	_timer -= delta
	var flat := Vector3.ZERO
	match _phase:
		Phase.DART:
			enemy.face_player(delta, 10.0)
			flat = enemy.dir_to_player() * dart_speed
			if enemy.player_distance() <= dart_stop_distance or _timer <= 0.0:
				_phase = Phase.WINDUP
				_timer = windup_time
				enemy.flash()
		Phase.WINDUP:
			enemy.face_player(delta, 10.0)
			if _timer <= 0.0:
				_phase = Phase.STAB
				_timer = stab_time
		Phase.STAB:
			flat = enemy.facing * 3.0
			if not _stab_hit_done:
				_stab_hit_done = true
				enemy.try_hit_player(stab_reach, 0.3)
			if _timer <= 0.0:
				_phase = Phase.OVEREXTEND
				_timer = overextend_time
		Phase.OVEREXTEND:
			# Buried spear: stock-still, no tracking. This is the opening.
			if _timer <= 0.0:
				_phase = Phase.HOP_BACK
				_timer = hop_back_time
		Phase.HOP_BACK:
			flat = -enemy.dir_to_player() * hop_back_speed
			if _timer <= 0.0:
				machine.change_to(&"Spacing")
	enemy.velocity.x = flat.x
	enemy.velocity.z = flat.z
	enemy.move_and_slide()
