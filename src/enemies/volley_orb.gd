class_name VolleyOrb
extends Area3D
## The volley ball. Charges above the spire, flies at the player's position
## at fire time (no homing — you dodge by not being there, you rally by
## swinging as it arrives), and reverses toward the tower when the player's
## staff connects (it implements `take_hit`, so the normal combat hitbox is
## the racket — no special input). Gold while the tower owns it, blue after
## a return, and a little faster every rebound, faithful to OoT.
##
## Entirely code-built: mesh, glow, and collision (layer 1, so the player's
## attack area can see it) are assembled in [method _ready].

const TOWER_COLOR := Color(1.0, 0.8, 0.25)
const PLAYER_COLOR := Color(0.4, 0.75, 1.0)
## Speed gain when the player returns it (tower gain is the tower's stat).
const PLAYER_RETURN_MULTIPLIER := 1.1
## Reaching this far from the arena kills a stray orb.
const MAX_RANGE := 34.0

enum Phase { CHARGING, TO_PLAYER, TO_TOWER, DYING }

var tower: VolleyTower
var phase := Phase.CHARGING

var _velocity := Vector3.ZERO
var _speed := 0.0
var _timer := 0.0
var _charge_total := 1.0
var _player: Player
var _material := StandardMaterial3D.new()


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	monitoring = false
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh_instance := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	sphere.radial_segments = 12
	sphere.rings = 6
	mesh_instance.mesh = sphere
	mesh_instance.material_override = _material
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.5
	shape.shape = ball
	add_child(shape)
	_apply_color(TOWER_COLOR)


func begin_charge(anchor: Vector3, charge_time: float) -> void:
	global_position = anchor
	phase = Phase.CHARGING
	_charge_total = charge_time
	_timer = charge_time
	scale = Vector3.ONE * 0.05


func launch_at(player: Player, speed: float) -> void:
	_player = player
	_speed = speed
	phase = Phase.TO_PLAYER
	scale = Vector3.ONE
	_velocity = (player.global_position + Vector3.UP * 0.9 - global_position) \
			.normalized() * _speed
	_apply_color(TOWER_COLOR)


## The tower chose to rally: back at the player, faster.
func volley_to_player(player: Player, speed_multiplier: float) -> void:
	_player = player
	_speed *= speed_multiplier
	phase = Phase.TO_PLAYER
	_velocity = (player.global_position + Vector3.UP * 0.9 - global_position) \
			.normalized() * _speed
	_apply_color(TOWER_COLOR)


## Combat contract: a staff swing while the orb is inbound returns it.
func take_hit(_hit: Dictionary) -> void:
	if phase != Phase.TO_PLAYER:
		return
	_speed *= PLAYER_RETURN_MULTIPLIER
	phase = Phase.TO_TOWER
	_velocity = (tower.target_point() - global_position).normalized() * _speed
	_apply_color(PLAYER_COLOR)


func dissipate() -> void:
	if phase == Phase.DYING:
		return
	phase = Phase.DYING
	_timer = 0.15


func _physics_process(delta: float) -> void:
	match phase:
		Phase.CHARGING:
			_timer -= delta
			scale = Vector3.ONE * clampf(
					1.0 - _timer / _charge_total, 0.05, 1.0)
		Phase.TO_PLAYER:
			global_position += _velocity * delta
			if _player != null and global_position.distance_to(
					_player.global_position + Vector3.UP * 0.9) < 0.9:
				_player.apply_knockback(_velocity, 9.0)
				_resolve()
			elif _out_of_bounds():
				_resolve()
		Phase.TO_TOWER:
			global_position += _velocity * delta
			if global_position.distance_to(tower.target_point()) < 1.1:
				tower.on_orb_returned(self)
			elif _out_of_bounds():
				_resolve()
		Phase.DYING:
			_timer -= delta
			scale = Vector3.ONE * maxf(_timer / 0.15, 0.01)
			if _timer <= 0.0:
				queue_free()


func _resolve() -> void:
	if is_instance_valid(tower):
		tower.on_orb_resolved()
	dissipate()


func _out_of_bounds() -> bool:
	return not is_instance_valid(tower) \
			or global_position.distance_to(tower.global_position) > MAX_RANGE


func _apply_color(color: Color) -> void:
	_material.albedo_color = color
