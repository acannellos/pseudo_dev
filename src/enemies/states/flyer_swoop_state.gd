extends EnemyState
## The flyer's dive, OoT Keese style: a hover-dip telegraph, then a
## committed swoop through where the player's chest *was* when the dive
## started — it does not track. While it's low it can finally be hit
## (or Z-targeted and met with a lunge); sidestep the line and it climbs
## away empty. The player's counters are timing, not chasing.

@export var aim_time := 0.45
@export var dive_speed := 9.0
@export var dive_max_time := 1.4
@export var climb_speed := 5.0

enum Phase { AIM, DIVE, CLIMB }

var _phase := Phase.AIM
var _timer := 0.0
var _dive_point := Vector3.ZERO
var _hit_done := false


func enter(_msg: Dictionary = {}) -> void:
	_phase = Phase.AIM
	_timer = aim_time
	_hit_done = false


func physics_update(delta: float) -> void:
	_timer -= delta
	match _phase:
		Phase.AIM:
			# Telegraph: hang and dip slightly, nose at the player.
			enemy.velocity = Vector3.DOWN * 0.8
			enemy.turn_facing(enemy.dir_to_player(), delta, 8.0)
			if _timer <= 0.0:
				_phase = Phase.DIVE
				_timer = dive_max_time
				_dive_point = enemy.player().global_position + Vector3.UP * 0.9
		Phase.DIVE:
			var to_point := _dive_point - enemy.global_position
			enemy.velocity = to_point.normalized() * dive_speed
			enemy.turn_facing(enemy.velocity, delta, 10.0)
			if not _hit_done and enemy.try_hit_player(1.1):
				_hit_done = true
			if to_point.length() < 0.8 or _timer <= 0.0:
				_phase = Phase.CLIMB
		Phase.CLIMB:
			var goal := enemy.home_position + Vector3.UP * 4.5
			var to_goal := goal - enemy.global_position
			if to_goal.length() < 1.0:
				machine.change_to(&"Fly")
			else:
				enemy.velocity = to_goal.normalized() * climb_speed
	enemy.move_and_slide()
