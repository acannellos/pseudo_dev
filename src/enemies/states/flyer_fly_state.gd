extends EnemyState
## Flyer at altitude (Keese-style): lazy circles around its home point,
## deliberately above the staff's reach — you cannot start this fight, it
## has to come down to you. When the player has been in range long enough
## (swoop cooldown), it dives. Untargetable geometry is the defense; the
## swoop is the whole vulnerability.

@export var fly_height := 4.5
@export var orbit_radius := 3.0
## Radians per second around the orbit.
@export var orbit_speed := 0.9
@export var swoop_cooldown := 3.0
@export var fly_move_speed := 4.0

var _angle := 0.0
var _cooldown_left := 1.5


func enter(_msg: Dictionary = {}) -> void:
	_cooldown_left = swoop_cooldown


func physics_update(delta: float) -> void:
	_angle = wrapf(_angle + orbit_speed * delta, 0.0, TAU)
	var goal := enemy.home_position \
			+ Vector3(cos(_angle), 0.0, sin(_angle)) * orbit_radius \
			+ Vector3.UP * fly_height
	var to_goal := goal - enemy.global_position
	enemy.velocity = (to_goal * 2.0).limit_length(fly_move_speed)
	if enemy.velocity.length() > 0.5:
		enemy.turn_facing(enemy.velocity, delta, 5.0)
	enemy.move_and_slide()
	if enemy.player_in_range(enemy.engage_range):
		_cooldown_left -= delta
		if _cooldown_left <= 0.0:
			machine.change_to(&"Swoop")
