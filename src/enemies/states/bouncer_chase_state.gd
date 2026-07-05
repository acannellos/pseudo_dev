extends EnemyState
## Bouncer chasing: the whole enemy is one rhythm — CROUCH (squash
## telegraph, still and hittable), LEAP (a committed ballistic hop at where
## you are standing, shoving on contact), LAND (a grounded pause, hittable
## again). It is dangerous exactly when airborne and open exactly when
## grounded, so the fight is about counting its beat, not about speed.

@export var crouch_time := 0.55
@export var land_time := 0.45
@export var hop_speed := 5.0
@export var hop_up_speed := 8.0

enum Phase { CROUCH, LEAP, LAND }

var _phase := Phase.CROUCH
var _timer := 0.0
var _hit_done := false


func enter(_msg: Dictionary = {}) -> void:
	_start_crouch()


func exit() -> void:
	enemy.visual.scale = Vector3.ONE


func physics_update(delta: float) -> void:
	enemy.apply_enemy_gravity(delta)
	_timer -= delta
	match _phase:
		Phase.CROUCH:
			enemy.velocity.x = 0.0
			enemy.velocity.z = 0.0
			enemy.face_player(delta, 4.0)
			if _timer <= 0.0:
				_phase = Phase.LEAP
				_hit_done = false
				enemy.visual.scale = Vector3.ONE
				var dir := enemy.dir_to_player()
				enemy.velocity = dir * hop_speed + Vector3.UP * hop_up_speed
		Phase.LEAP:
			# Committed arc: no steering. Contact shoves the player once.
			if not _hit_done and not enemy.is_on_floor() \
					and enemy.try_hit_player(1.2):
				_hit_done = true
			if enemy.is_on_floor() and enemy.velocity.y <= 0.0:
				_phase = Phase.LAND
				_timer = land_time
				enemy.velocity.x = 0.0
				enemy.velocity.z = 0.0
		Phase.LAND:
			if _timer <= 0.0:
				if enemy.player_in_range(enemy.disengage_range):
					_start_crouch()
				else:
					machine.change_to(&"Idle")
	enemy.move_and_slide()


func _start_crouch() -> void:
	_phase = Phase.CROUCH
	_timer = crouch_time
	enemy.visual.scale = Vector3(1.15, 0.7, 1.15)
