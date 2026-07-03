extends CanvasLayer
## Numeric readout companion to [DebugDraw]: speed, state, hop chain, and a
## legend for the vector colours. Toggle with the `toggle_debug` action (F3).

@onready var _label: Label = $Label

var _player: Player


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as Player


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"toggle_debug"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible or _player == null:
		return
	var flat := _player.horizontal_velocity()
	var state_name := "?"
	if _player.state_machine.current_state != null:
		state_name = String(_player.state_machine.current_state.name)
	_label.text = "\n".join([
		"state: %s" % state_name,
		"h-speed: %5.1f m/s   v-speed: %+5.1f m/s" % [flat.length(), _player.velocity.y],
		"hop chain: %d   air dash: %s" % [
			_player.hop_chain,
			"ready" if _player.air_dash_available else "spent",
		],
		"fps: %d" % Engine.get_frames_per_second(),
		"",
		"green   velocity",
		"cyan    desired velocity (input)",
		"yellow  facing",
		"magenta camera look",
		"",
		"F3 toggle debug   Esc release mouse",
	])
