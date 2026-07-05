extends EnemyState
## Bouncer at rest (Tektite-style): sits motionless, then turns — slowly,
## the OoT tell — to track the player once they're inside notice range.
## The slow turn is the fairness mechanism: you always see it wake up
## before the first leap can come.

## It starts tracking (turning) inside this multiple of engage range.
@export var notice_scale := 1.4
@export var turn_speed := 1.6
@export var spot_interval := 0.25

var _spot_timer := 0.0


func physics_update(delta: float) -> void:
	enemy.apply_enemy_gravity(delta)
	enemy.velocity.x = 0.0
	enemy.velocity.z = 0.0
	if enemy.player_in_range(enemy.engage_range * notice_scale):
		enemy.face_player(delta, turn_speed)
	enemy.move_and_slide()
	_spot_timer -= delta
	if _spot_timer <= 0.0:
		_spot_timer = spot_interval
		if enemy.player_in_range(enemy.engage_range) and enemy.has_player_los():
			machine.change_to(&"Chase")
