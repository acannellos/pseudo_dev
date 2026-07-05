class_name EnemyStateMachine
extends Node
## Minimal state machine hosting [EnemyState] child nodes — same
## composition pattern as [PlayerStateMachine]: states are looked up by
## node name, so an enemy's brain is visible in its scene tree.

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: EnemyState

var current_state: EnemyState

var _states: Dictionary = {}


## Injects the owning enemy into every child state and starts the initial
## one. Called by [EnemyBase] once it is ready.
func setup(enemy: EnemyBase) -> void:
	for child in get_children():
		var state := child as EnemyState
		if state == null:
			continue
		state.enemy = enemy
		state.machine = self
		_states[StringName(state.name)] = state
	current_state = initial_state
	if current_state == null:
		current_state = get_child(0) as EnemyState
	current_state.enter()
	state_changed.emit(&"", StringName(current_state.name))


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func change_to(state_name: StringName, msg: Dictionary = {}) -> void:
	var next: EnemyState = _states.get(state_name)
	assert(next != null, "Unknown enemy state: %s" % state_name)
	var previous := StringName(current_state.name)
	current_state.exit()
	current_state = next
	current_state.enter(msg)
	state_changed.emit(previous, StringName(current_state.name))
