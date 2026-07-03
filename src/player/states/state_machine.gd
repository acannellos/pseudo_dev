class_name PlayerStateMachine
extends Node
## Minimal state machine hosting [PlayerState] child nodes.
##
## States are looked up by node name, so composition happens in the scene
## tree: drop a new state node under this one and it is immediately
## reachable via [method change_to].

signal state_changed(previous: StringName, current: StringName)

@export var initial_state: PlayerState

var current_state: PlayerState

var _states: Dictionary = {}


## Injects dependencies into every child state and activates the initial one.
## Called by [Player] once it is ready.
func setup(player: Player) -> void:
	for child in get_children():
		var state := child as PlayerState
		if state == null:
			continue
		state.player = player
		state.state_machine = self
		_states[StringName(state.name)] = state
	current_state = initial_state
	if current_state == null:
		current_state = get_child(0) as PlayerState
	current_state.enter()
	state_changed.emit(&"", StringName(current_state.name))


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func change_to(state_name: StringName, msg: Dictionary = {}) -> void:
	var next: PlayerState = _states.get(state_name)
	assert(next != null, "Unknown player state: %s" % state_name)
	var previous := StringName(current_state.name)
	current_state.exit()
	current_state = next
	current_state.enter(msg)
	state_changed.emit(previous, StringName(current_state.name))
