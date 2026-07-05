extends EnemyState
## The brute's one attack, in three readable beats:
## RAISE — shield lifts high and he plants (long telegraph; the gap under
## the shield is the invitation to dash past and get behind);
## SLAM — shield crashes down, shockwave, anyone in the front cone is
## shoved;
## RECOVER — shield hangs low with [member ShieldBrute.shield_up] off, so
## the front is briefly vulnerable. Two counters, one attack.

const SHOCKWAVE_RING := preload("res://src/fx/shockwave_ring.gd")

@export var raise_time := 0.9
@export var slam_time := 0.3
@export var recover_time := 1.4
## Reach of the slam shove in front of the brute.
@export var slam_reach := 3.4

enum Phase { RAISE, SLAM, RECOVER }

var _phase := Phase.RAISE
var _timer := 0.0
var _slam_done := false


func enter(_msg: Dictionary = {}) -> void:
	_phase = Phase.RAISE
	_timer = raise_time
	_slam_done = false
	(enemy as ShieldBrute).shield_up = true


func exit() -> void:
	var brute := enemy as ShieldBrute
	brute.shield_up = true
	brute.set_shield_raised(0.0)


func physics_update(delta: float) -> void:
	enemy.apply_enemy_gravity(delta)
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	enemy.move_and_slide()
	var brute := enemy as ShieldBrute
	_timer -= delta
	match _phase:
		Phase.RAISE:
			# Committed: he no longer tracks the player once the raise starts.
			brute.set_shield_raised(1.0 - _timer / raise_time)
			if _timer <= 0.0:
				_phase = Phase.SLAM
				_timer = slam_time
		Phase.SLAM:
			brute.set_shield_raised(maxf(_timer / slam_time, 0.0))
			if not _slam_done:
				_slam_done = true
				SHOCKWAVE_RING.spawn(enemy.get_tree().current_scene,
						enemy.global_position + enemy.facing * 1.6)
				enemy.try_hit_player(slam_reach, 0.2)
			if _timer <= 0.0:
				_phase = Phase.RECOVER
				_timer = recover_time
				brute.shield_up = false
		Phase.RECOVER:
			if _timer <= 0.0:
				machine.change_to(&"Engage")
