class_name EnemyPatrolState
extends EnemyState
## Shared patrol: amble between random points near the enemy's home
## position, pausing between legs. Hands off to [member engage_to] when the
## player comes inside the enemy's engage range with line of sight — and
## every engage state hands back here when the player breaks away, so
## patrol is the resting loop of every ground enemy.

## State entered when the player is spotted.
@export var engage_to: StringName = &"Engage"
## How far from home patrol legs wander.
@export var pace_radius := 4.0
## Patrol walks slower than the enemy's combat speed.
@export var pace_speed_scale := 0.55
@export var pause_time := 1.3
## Seconds between spot checks (distance is cheap; the LOS ray is not).
@export var spot_interval := 0.25

var _goal := Vector3.ZERO
var _pause_left := 0.0
var _spot_timer := 0.0


func enter(_msg: Dictionary = {}) -> void:
	_pick_goal()
	_pause_left = 0.0


func physics_update(delta: float) -> void:
	enemy.apply_enemy_gravity(delta)
	if _pause_left > 0.0:
		_pause_left -= delta
		enemy.velocity.x = 0.0
		enemy.velocity.z = 0.0
	else:
		var to_goal := _goal - enemy.global_position
		to_goal.y = 0.0
		if to_goal.length() < 0.4:
			_pause_left = pause_time
			_pick_goal()
		else:
			var dir := to_goal.normalized()
			enemy.turn_facing(dir, delta, 4.0)
			enemy.velocity.x = dir.x * enemy.move_speed * pace_speed_scale
			enemy.velocity.z = dir.z * enemy.move_speed * pace_speed_scale
	enemy.move_and_slide()
	_spot_timer -= delta
	if _spot_timer <= 0.0:
		_spot_timer = spot_interval
		if enemy.player_in_range(enemy.engage_range) and enemy.has_player_los():
			machine.change_to(engage_to)


func _pick_goal() -> void:
	var angle := randf() * TAU
	var reach := randf_range(pace_radius * 0.4, pace_radius)
	_goal = enemy.home_position + Vector3(cos(angle), 0.0, sin(angle)) * reach
