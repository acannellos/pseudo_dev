class_name StaffAnimator
extends Node3D
## Poses the staff: slung diagonally across the back at rest, snapped
## through a quick three-pose swipe when the combat controller signals a
## swing. Poses are stepped (no easing) to match the stop-motion animation
## style; swings 1 and 2 sweep opposite ways, swing 3 sweeps wider.
##
## Sits under the animated mesh pivot, so the staff inherits facing, run
## bob, and squash — and shows up in afterimage snapshots — for free.

## Number of stepped poses per swing.
const SWING_POSES := 3
## Yaw sweep (radians) per combo hit, one entry per pose. Positive yaw moves
## the tip toward the character's left; sign flips between hits 1 and 2.
const SWING_YAWS: Array = [
	[1.3, 0.1, -1.2],
	[-1.3, -0.1, 1.2],
	[1.6, 0.0, -1.6],
]
## Lunge overhand chop: pitch sweep instead of yaw (raised → down-forward).
const LUNGE_PITCHES: Array = [1.3, 0.2, -0.9]
## Brief follow-through hold after the sweep before returning to the back.
const LINGER := 0.08

const REST_POSITION := Vector3(0.3, 0.7, 0.28)
const REST_ROTATION := Vector3(0.95, 0.35, 0.0)
const SWING_POSITION := Vector3(0.0, 0.85, -0.05)
## Slight downward tilt so the swipe reads as a slash, not a level sweep.
const SWING_TILT := -0.18

@export var combat: CombatController
## The node the swing yaw rotates; the staff mesh hangs off it pointing -Z.
@export var staff_pivot: Node3D

var _swinging := false
var _combo := 1
var _elapsed := 0.0


func _ready() -> void:
	combat.swing_started.connect(_on_swing_started)
	_apply_rest()


func _on_swing_started(combo_index: int, _direction: Vector3) -> void:
	_combo = combo_index
	_elapsed = 0.0
	_swinging = true


func _physics_process(delta: float) -> void:
	if not _swinging:
		return
	var lunging := _combo == CombatController.LUNGE_COMBO
	var swing_time: float = combat.player.stats.lunge_swing_time if lunging \
			else combat.player.stats.swing_time
	_elapsed += delta
	if _elapsed >= swing_time + LINGER:
		_swinging = false
		_apply_rest()
		return
	var pose := clampi(int(_elapsed / (swing_time / SWING_POSES)), 0, SWING_POSES - 1)
	position = SWING_POSITION
	if lunging:
		staff_pivot.rotation = Vector3(LUNGE_PITCHES[pose], 0.0, 0.0)
	else:
		var yaws: Array = SWING_YAWS[_combo - 1]
		staff_pivot.rotation = Vector3(SWING_TILT, yaws[pose], 0.0)


func _apply_rest() -> void:
	position = REST_POSITION
	staff_pivot.rotation = REST_ROTATION
