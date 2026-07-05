class_name HitDummy
extends StaticBody3D
## Practice target for the staff combo. Implements the combat contract —
## [method take_hit] — flashing white and wobbling away from the hit;
## depleting its hit points knocks it flat for a moment, then it pops back
## up. All feedback is stepped on twos, matching the stop-motion style.

const FRAME := 1.0 / 12.0
const FLASH_TIME := 0.1
const WOBBLE_TIME := 0.3
const WOBBLE_ANGLE := 0.45

@export var hit_points := 3
@export var respawn_time := 2.0

var _hp := 0
var _flash_left := 0.0
var _wobble_left := 0.0
var _down_left := 0.0
var _step_timer := 0.0
var _wobble_axis := Vector3.RIGHT
var _flash_material := StandardMaterial3D.new()

@onready var _visual: Node3D = $Visual
@onready var _collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:
	_hp = hit_points
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = Color(1.0, 1.0, 1.0)


## Z-target contract: knocked-down dummies drop the lock.
func is_targetable() -> bool:
	return _down_left <= 0.0


func target_point() -> Vector3:
	return global_position + Vector3.UP * 1.3


## Combat contract (see [CombatController]): [param hit] carries damage,
## direction, position, and combo_index.
func take_hit(hit: Dictionary) -> void:
	if _down_left > 0.0:
		return
	var damage := int(hit.get("damage", 1))
	_hp -= damage
	DamageNumber.spawn(get_tree().current_scene, target_point(), damage)
	_flash_left = FLASH_TIME
	_set_flash(true)
	var dir: Vector3 = hit.get("direction", Vector3.FORWARD)
	dir = Vector3(dir.x, 0.0, dir.z)
	if dir.length() > 0.01:
		_wobble_axis = Vector3.UP.cross(dir.normalized()).normalized()
	_wobble_left = WOBBLE_TIME
	if _hp <= 0:
		_knock_down()


func _physics_process(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			_set_flash(false)
	if _down_left > 0.0:
		_down_left -= delta
		if _down_left <= 0.0:
			_pop_back_up()
		return
	if _wobble_left <= 0.0:
		return
	_wobble_left = maxf(_wobble_left - delta, 0.0)
	_step_timer += delta
	if _step_timer < FRAME:
		return
	_step_timer = 0.0
	var angle := WOBBLE_ANGLE * (_wobble_left / WOBBLE_TIME)
	_visual.rotation = _wobble_axis * angle


func _knock_down() -> void:
	_down_left = respawn_time
	_wobble_left = 0.0
	_visual.rotation = Vector3.ZERO
	_visual.scale = Vector3(1.5, 0.12, 1.5)
	_collision.set_deferred(&"disabled", true)


func _pop_back_up() -> void:
	_hp = hit_points
	_visual.scale = Vector3.ONE
	_collision.set_deferred(&"disabled", false)


func _set_flash(on: bool) -> void:
	for found in _visual.find_children("*", "MeshInstance3D", true, false):
		(found as MeshInstance3D).material_override = _flash_material if on else null
