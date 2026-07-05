class_name EnemyState
extends Node
## Base class for enemy behavior states — the enemy-side mirror of
## [PlayerState]. States are child nodes of an [EnemyStateMachine]; each
## drives [member enemy] velocity/intent for the frame and requests
## transitions. The player's state machine is untouched by any of this:
## enemies only ever talk to the player through its public API
## ([method Player.apply_knockback]) and the shared hit contract.

var enemy: EnemyBase
var machine: EnemyStateMachine


## [param _msg] carries optional hand-off data from the previous state.
func enter(_msg: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass
