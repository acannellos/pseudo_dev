class_name EnemyBase
extends CharacterBody3D
## Base for arena enemies: health + the shared hit contract (take_hit /
## hittable group), Z-target support (targetable group + target_point /
## is_targetable), a hosted [EnemyStateMachine], and movement helpers the
## states compose. Scene contract: `CollisionShape3D`, `Visual` (Node3D
## holding the meshes), `StateMachine` with [EnemyState] children.
##
## Design note: every enemy engages when the player is inside
## [member engage_range] with line of sight and *breaks off back to patrol*
## past [member disengage_range] — fights are opt-in and escapable.

signal died

const FLASH_TIME := 0.12

@export var max_hp := 3
@export var move_speed := 2.0
@export var engage_range := 8.0
@export var disengage_range := 14.0
@export var gravity := 30.0
## Height above the origin of the Z-target/LOS point.
@export var target_height := 1.2
## Push speed applied to the player by this enemy's attacks.
@export var knockback_speed := 8.0

var hp := 0
## Horizontal direction the enemy model faces; states steer it.
var facing := Vector3.FORWARD

var _player: Player
var _flash_left := 0.0
var _flash_material := StandardMaterial3D.new()
var _dead := false

@onready var machine: EnemyStateMachine = $StateMachine
@onready var visual: Node3D = $Visual
@onready var home_position: Vector3 = global_position


func _ready() -> void:
	hp = max_hp
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = Color(1.0, 1.0, 1.0)
	_player = get_tree().get_first_node_in_group(&"player") as Player
	machine.setup(self)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_flash(false)
	machine.physics_update(delta)
	_update_visual_facing()


# --- Hit / target contracts -------------------------------------------------

func take_hit(hit: Dictionary) -> void:
	if _dead:
		return
	if not _hit_allowed(hit):
		_blocked_feedback(hit)
		return
	hp -= int(hit.get("damage", 1))
	flash()
	if hp <= 0:
		_die()


## Override to reject hits (shield facings etc.). Blocked hits deal no
## damage and route to [method _blocked_feedback] instead.
func _hit_allowed(_hit: Dictionary) -> bool:
	return true


func _blocked_feedback(_hit: Dictionary) -> void:
	pass


func is_targetable() -> bool:
	return not _dead


func target_point() -> Vector3:
	return global_position + Vector3.UP * target_height


# --- State helpers ----------------------------------------------------------

func player() -> Player:
	return _player


func player_distance() -> float:
	if _player == null:
		return INF
	return global_position.distance_to(_player.global_position)


## Horizontal unit vector toward the player.
func dir_to_player() -> Vector3:
	if _player == null:
		return facing
	var to_player := _player.global_position - global_position
	to_player.y = 0.0
	return to_player.normalized() if to_player.length() > 0.05 else facing


func player_in_range(range_: float) -> bool:
	return player_distance() <= range_


## World-geometry (layer 1) ray to the player's chest.
func has_player_los() -> bool:
	if _player == null:
		return false
	var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * target_height,
			_player.global_position + Vector3.UP,
			1, [get_rid(), _player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func turn_facing(toward: Vector3, delta: float, turn_speed := 6.0) -> void:
	toward = Vector3(toward.x, 0.0, toward.z)
	if toward.length() < 0.05:
		return
	toward = toward.normalized()
	var angle := facing.signed_angle_to(toward, Vector3.UP)
	var max_turn := turn_speed * delta
	facing = facing.rotated(Vector3.UP, clampf(angle, -max_turn, max_turn)).normalized()


func face_player(delta: float, turn_speed := 6.0) -> void:
	turn_facing(dir_to_player(), delta, turn_speed)


func apply_enemy_gravity(delta: float) -> void:
	velocity.y = maxf(velocity.y - gravity * delta, -30.0)


## Melee contact check: shoves the player if within [param reach] and (when
## [param front_dot] > -1) inside the forward cone. Returns whether it hit.
func try_hit_player(reach: float, front_dot := -1.0) -> bool:
	if _player == null or player_distance() > reach:
		return false
	if front_dot > -1.0 and dir_to_player().dot(facing) < front_dot:
		return false
	_player.apply_knockback(dir_to_player(), knockback_speed)
	return true


## White hit-feedback flash, also used by states as an attack telegraph.
func flash() -> void:
	_flash_left = FLASH_TIME
	_set_flash(true)


func _set_flash(on: bool) -> void:
	for found in visual.find_children("*", "MeshInstance3D", true, false):
		(found as MeshInstance3D).material_override = _flash_material if on else null


func _update_visual_facing() -> void:
	var flat := Vector3(facing.x, 0.0, facing.z)
	if flat.length() > 0.5:
		visual.look_at(visual.global_position + flat.normalized())


func _die() -> void:
	_dead = true
	died.emit()
	velocity = Vector3.ZERO
	visual.scale = Vector3(1.35, 0.12, 1.35)
	collision_layer = 0
	set_deferred(&"collision_mask", 0)
	get_tree().create_timer(0.8).timeout.connect(queue_free)
