extends PlayerState
## Ledge grab / mantle: entered from Air when a grabbable lip is detected
## ahead (see [method Player.find_ledge]). A short hang, then a kinematic
## climb up onto the lip — instead of bonking or falling just short.
## Crouch drops the grab; jump wall-kicks away.

## Where the body hangs relative to the lip.
const HANG_DROP := 1.35
const HANG_GAP := 0.45
## How far past the lip the climb ends.
const MANTLE_INSET := 0.5

var _ledge_point := Vector3.ZERO
var _wall_normal := Vector3.ZERO
var _hang_left := 0.0
var _mantle_progress := -1.0
var _hang_position := Vector3.ZERO
var _stand_position := Vector3.ZERO


func enter(msg: Dictionary = {}) -> void:
	_ledge_point = msg.get("ledge_point", player.global_position)
	_wall_normal = msg.get("wall_normal", player.facing * -1.0)
	_hang_left = player.stats.ledge_hang_time
	_mantle_progress = -1.0
	var out := Vector3(_wall_normal.x, 0.0, _wall_normal.z).normalized()
	_hang_position = Vector3(_ledge_point.x, _ledge_point.y - HANG_DROP, _ledge_point.z) \
			+ out * HANG_GAP
	_stand_position = _ledge_point - out * MANTLE_INSET
	player.velocity = Vector3.ZERO
	player.desired_velocity = Vector3.ZERO
	player.global_position = _hang_position
	player.facing = -out
	# The climb path crosses the lip corner; collision comes back on exit.
	player.collision_shape.disabled = true


func exit() -> void:
	player.collision_shape.disabled = false


func physics_update(delta: float) -> void:
	player.velocity = Vector3.ZERO
	if _mantle_progress < 0.0:
		_hang(delta)
	else:
		_mantle(delta)


func _hang(delta: float) -> void:
	_hang_left -= delta
	if player.consume_jump_buffer():
		# Kick away from the wall instead of climbing.
		player.perform_wall_kick(_wall_normal)
		state_machine.change_to(&"Air")
		return
	if player.crouch_held:
		state_machine.change_to(&"Air")
		return
	if _hang_left <= 0.0:
		_mantle_progress = 0.0


func _mantle(delta: float) -> void:
	_mantle_progress = minf(
			_mantle_progress + delta / player.stats.ledge_mantle_time, 1.0)
	# Rise first, then move in over the lip: a two-segment climb that clears
	# the corner instead of lerping through it diagonally.
	var rise := clampf(_mantle_progress * 2.0, 0.0, 1.0)
	var slide_in := clampf(_mantle_progress * 2.0 - 1.0, 0.0, 1.0)
	var up_target := Vector3(_hang_position.x, _stand_position.y, _hang_position.z)
	player.global_position = _hang_position.lerp(up_target, rise) \
			.lerp(_stand_position, slide_in)
	if _mantle_progress >= 1.0:
		player.global_position = _stand_position
		if player.move_dir != Vector3.ZERO:
			state_machine.change_to(&"Run")
		else:
			state_machine.change_to(&"Idle")
