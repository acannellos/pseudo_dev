extends CanvasLayer
## Numeric readout companion to [DebugDraw]: speed, state, chain counters,
## per-tech availability, and a legend for the vector colours. Toggle with
## the `toggle_debug` action (F3).

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
	var speed := _player.horizontal_velocity().length()
	var state_name := "?"
	if _player.state_machine.current_state != null:
		state_name = String(_player.state_machine.current_state.name)
	_label.text = "\n".join([
		"state: %s" % state_name,
		"h-speed: %5.1f m/s   v-speed: %+5.1f m/s" % [speed, _player.velocity.y],
		"hop chain: %d   triple jump: %d/3   air dash: %s" % [
			_player.hop_chain,
			_player.jump_chain,
			"ready" if _player.air_dash_available else "spent",
		],
		"long jump: %s   turn jump: %s   slide hop: %s" % [
			_long_jump_status(state_name, speed),
			_turn_jump_status(state_name, speed),
			_slide_hop_status(state_name, speed),
		],
		"fps: %d" % Engine.get_frames_per_second(),
		"",
		"green   velocity",
		"cyan    desired velocity (input)",
		"yellow  facing",
		"magenta camera look",
		"",
		"F3 toggle debug   F5 cycle level   Esc release mouse",
	])


## READY when crouch+jump right now would launch a long jump.
func _long_jump_status(state_name: String, speed: float) -> String:
	if state_name in ["Run", "Slide", "Turnaround"] \
			and speed >= _player.stats.long_jump_min_speed:
		return "READY"
	return "--"


## NOW during the skid window itself; ready when a hard reversal would skid.
func _turn_jump_status(state_name: String, speed: float) -> String:
	if state_name == "Turnaround":
		return "NOW"
	if state_name == "Run" and speed >= _player.stats.turnaround_min_speed:
		return "ready"
	return "--"


func _slide_hop_status(state_name: String, speed: float) -> String:
	if state_name == "Slide" and speed > 0.5:
		return "READY"
	return "--"
