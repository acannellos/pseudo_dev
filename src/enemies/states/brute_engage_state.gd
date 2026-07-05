extends EnemyState
## Brute engaged: plod straight at the player, shield squared up. Slow on
## purpose — the player decides the geometry of the fight, the brute just
## keeps presenting the wall. In slam range → Attack; player breaks far
## enough away → back to Patrol.

@export var attack_range := 3.0


func enter(_msg: Dictionary = {}) -> void:
	var brute := enemy as ShieldBrute
	brute.shield_up = true
	brute.set_shield_raised(0.0)


func physics_update(delta: float) -> void:
	enemy.apply_enemy_gravity(delta)
	enemy.face_player(delta, 3.0)
	var dir := enemy.dir_to_player()
	enemy.velocity.x = dir.x * enemy.move_speed
	enemy.velocity.z = dir.z * enemy.move_speed
	enemy.move_and_slide()
	if not enemy.player_in_range(enemy.disengage_range):
		machine.change_to(&"Patrol")
	elif enemy.player_in_range(attack_range):
		machine.change_to(&"Attack")
