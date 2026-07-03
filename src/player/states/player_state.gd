class_name PlayerState
extends Node
## Base class for player movement states.
##
## States are plain child nodes of [PlayerStateMachine]. Each state drives
## [member player] velocity for the frame (including calling
## `move_and_slide()`), then requests transitions via
## [method PlayerStateMachine.change_to]. Adding a move to the kit means
## adding one node with one script — no other state needs to change.

var player: Player
var state_machine: PlayerStateMachine


## Called when the state becomes active. [param _msg] carries optional
## hand-off data from the previous state (e.g. ground-pound impact speed).
func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
