class_name LevelSwitcher
extends Node
## Debug level cycling: the `cycle_level` action (F5) swaps the active level
## instance among [member levels] at runtime and respawns the player, so
## every test level stays reachable in one play session.

@export var levels: Array[PackedScene] = []
## The level instance already present in the scene (assumed to be levels[0]).
@export var current_level: Node
@export var player: Player

var _index := 0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"cycle_level"):
		_cycle_level()


func _cycle_level() -> void:
	if levels.size() < 2:
		return
	_index = (_index + 1) % levels.size()
	if current_level != null:
		current_level.queue_free()
	current_level = levels[_index].instantiate()
	get_parent().add_child(current_level)
	if player != null:
		player.respawn()
