class_name MovingPlatform
extends AnimatableBody3D
## Ping-pong moving platform (greybox). Moves on a cosine ease between its
## placed position and placed position + [member travel].
##
## Momentum inheritance needs no player-side code: with `sync_to_physics`
## on, `move_and_slide()` reads this body's velocity as platform velocity,
## carries the player while standing, and adds it on jump/step-off
## (CharacterBody3D's default `platform_on_leave = ADD_VELOCITY`).

## Displacement from the placed position to the far end of the path.
@export var travel := Vector3(8.0, 0.0, 0.0)
## Seconds for a full out-and-back cycle.
@export var period := 4.0
## Phase offset (0–1) so neighbouring platforms can desync.
@export_range(0.0, 1.0) var start_offset := 0.0

var _origin := Vector3.ZERO
var _time := 0.0


func _ready() -> void:
	_origin = global_position
	_time = start_offset * period


func _physics_process(delta: float) -> void:
	_time += delta
	var s := 0.5 - 0.5 * cos(TAU * _time / period)
	global_position = _origin + travel * s
