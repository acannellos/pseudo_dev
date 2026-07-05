class_name CombatController
extends Node
## Three-hit staff combo, running *beside* the movement state machine rather
## than inside it: a swing layers over Idle/Run/Air/Dash/Slide, so attacking
## never interrupts momentum. States whose hands are busy (pound, ledge,
## wall contact, skid) suppress and cancel swings instead.
##
## Swing 1 chains into 2 into 3 (then back to 1); the chain survives
## [member MovementStats.combo_reset_time] between swings before resetting.
## Attack presses are buffered like jumps. Airborne swings fall at reduced
## gravity (a slight anime float) via [member Player.combat_gravity_scale].
##
## This node owns timing and the hitbox; visuals hang off the signals
## (staff animator, slash arc in PlayerFX) — same pattern as movement FX.

## A swing began. [param combo_index] is 1–3 for the combo, or
## [constant LUNGE_COMBO] for the Z-targeted lunge slice.
signal swing_started(combo_index: int, direction: Vector3)
## The live hitbox overlapped a hittable target this swing.
signal swing_hit(target: Node, combo_index: int)
signal combo_reset

## Pseudo combo index of the lunge attack (vertical slice, double damage).
const LUNGE_COMBO := 4

## States that cannot attack; entering one mid-swing cancels the swing.
const BLOCKED_STATES: Array[StringName] = [
	&"GroundPound", &"PoundLand", &"LedgeGrab",
	&"WallSlide", &"WallRun", &"Turnaround",
]
## Grounded locomotion states from which a Z-targeted attack lunges
## (airborne targeted attacks stay normal swings).
const LUNGE_STATES: Array[StringName] = [&"Idle", &"Run"]

@export var player: Player
## Wired explicitly (not via player.state_machine) because children ready
## before their parent — the player's own @onready vars aren't set yet.
@export var state_machine: PlayerStateMachine
## Area enabled during a swing's active window. Its box shape is sized from
## the combat stats at ready, so tuning stays on the MovementStats resource.
@export var hitbox: Area3D

## Which hit of the combo is (or was last) swinging: 1–3, 0 = chain idle.
var combo_index := 0

var _swing_left := 0.0
var _chain_left := 0.0
var _buffer_left := 0.0
## Whether the running swing is the lunge (hitbox live for its whole
## duration, double damage, breaks the combo chain).
var _lunging := false
## Targets already hit by the current swing (one hit per target per swing).
var _hit_targets: Array[Node] = []


func _ready() -> void:
	hitbox.monitoring = false
	var shape := (hitbox.get_node("CollisionShape3D") as CollisionShape3D).shape
	(shape as BoxShape3D).size = Vector3(
			player.stats.attack_half_width * 2.0, 1.5, player.stats.attack_range)
	state_machine.state_changed.connect(_on_state_changed)


func _physics_process(delta: float) -> void:
	_buffer_left = maxf(_buffer_left - delta, 0.0)
	if Input.is_action_just_pressed(&"attack"):
		_buffer_left = player.stats.attack_buffer_time
	if _swing_left > 0.0:
		_update_swing(delta)
	else:
		_update_chain(delta)
	if _buffer_left > 0.0 and _swing_left <= 0.0 and _can_attack():
		if _wants_lunge():
			_start_lunge()
		else:
			_start_swing()


func is_swinging() -> bool:
	return _swing_left > 0.0


func _can_attack() -> bool:
	return not BLOCKED_STATES.has(StringName(state_machine.current_state.name))


## Lunge only on the deliberate OoT input: locked onto a target, grounded,
## AND pushing forward (toward the enemy) as attack lands. Every other
## targeted attack stays a normal swing.
func _wants_lunge() -> bool:
	if not player.is_locked_on():
		return false
	if not LUNGE_STATES.has(StringName(state_machine.current_state.name)):
		return false
	return player.move_dir.dot(player.target_dir()) > 0.5


func _start_swing() -> void:
	_buffer_left = 0.0
	_lunging = false
	combo_index = combo_index % 3 + 1
	_swing_left = player.stats.swing_time
	_hit_targets.clear()
	hitbox.monitoring = true
	swing_started.emit(combo_index, player.facing)


## Z-targeted grounded attack: hand movement to the Lunge state and run an
## overhand slice for the whole flight. The lunge breaks the combo chain —
## it is a committed opener, not a chain link.
func _start_lunge() -> void:
	_buffer_left = 0.0
	_lunging = true
	combo_index = 0
	_swing_left = player.stats.lunge_swing_time
	_hit_targets.clear()
	hitbox.monitoring = true
	var dir := player.target_dir()
	swing_started.emit(LUNGE_COMBO, dir)
	state_machine.change_to(&"Lunge", {"dir": dir})


func _update_swing(delta: float) -> void:
	_swing_left -= delta
	# Slight float while swinging on the way down — never a jump-height
	# gain. The lunge owns its own arc, so it is exempt.
	player.combat_gravity_scale = player.stats.air_attack_gravity_scale \
			if not _lunging and not player.is_on_floor() \
			and player.velocity.y <= 0.0 else 1.0
	var active := _lunging \
			or _swing_left > player.stats.swing_time - player.stats.swing_active_time
	if active:
		_position_hitbox()
		_collect_hits()
	else:
		hitbox.monitoring = false
	if _swing_left <= 0.0:
		player.combat_gravity_scale = 1.0
		hitbox.monitoring = false
		_lunging = false
		_chain_left = player.stats.combo_reset_time


func _update_chain(delta: float) -> void:
	if combo_index == 0:
		return
	_chain_left -= delta
	if _chain_left <= 0.0:
		combo_index = 0
		combo_reset.emit()


## The arc tracks the character: box centered ahead of the chest along the
## current facing, every active frame.
func _position_hitbox() -> void:
	var forward := player.facing
	var origin := player.global_position + Vector3.UP * 1.0 \
			+ forward * (player.stats.attack_range * 0.5)
	hitbox.global_transform = Transform3D(
			Basis.looking_at(forward, Vector3.UP), origin)


func _collect_hits() -> void:
	var targets: Array[Node] = []
	targets.append_array(hitbox.get_overlapping_bodies())
	targets.append_array(hitbox.get_overlapping_areas())
	for target in targets:
		if target == player or _hit_targets.has(target):
			continue
		if not target.has_method(&"take_hit"):
			continue
		_hit_targets.append(target)
		var multiplier := player.stats.lunge_damage_multiplier if _lunging \
				else (2 if combo_index == 3 else 1)
		target.take_hit({
			"damage": player.stats.attack_damage * multiplier,
			"direction": player.facing,
			"position": player.global_position,
			"combo_index": LUNGE_COMBO if _lunging else combo_index,
		})
		swing_hit.emit(target, LUNGE_COMBO if _lunging else combo_index)


## Entering a hands-busy state cancels the swing and drops the chain.
func _on_state_changed(_previous: StringName, current: StringName) -> void:
	if not BLOCKED_STATES.has(current):
		return
	if _swing_left > 0.0 or combo_index != 0:
		_swing_left = 0.0
		combo_index = 0
		_lunging = false
		hitbox.monitoring = false
		player.combat_gravity_scale = 1.0
		combo_reset.emit()
