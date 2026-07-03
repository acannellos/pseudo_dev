class_name StopMotionAnimator
extends Node
## Placeholder "stop-motion" animation driver.
##
## Generates a library of deliberately choppy animations (stepped keys "on
## twos" at 24 fps, [constant Animation.INTERPOLATION_NEAREST], no easing)
## that pose the mesh pivot per state: squash-and-stretch, hops, slam
## flattening. This is a stand-in for real art, not a keyframe dump —
## swapping in real animations later means authoring an animation with the
## same snake_case name on [member animation_player]; any name that already
## exists is left untouched by the generator.

## One animation "frame": on-twos at 24 fps (i.e. 12 poses per second).
const FRAME := 1.0 / 12.0

@export var animation_player: AnimationPlayer
@export var state_machine: PlayerStateMachine
## Path (relative to the AnimationPlayer root) of the node the placeholder
## poses are keyed on.
@export var pivot_path := NodePath("Visual/Pivot")


func _ready() -> void:
	_build_placeholder_library()
	if state_machine != null:
		state_machine.state_changed.connect(_on_state_changed)


func _on_state_changed(_previous: StringName, current: StringName) -> void:
	var anim_name := StringName(String(current).to_snake_case())
	if animation_player.has_animation(anim_name):
		animation_player.play(anim_name)
	else:
		animation_player.play(&"RESET")


func _build_placeholder_library() -> void:
	var library: AnimationLibrary
	if animation_player.has_animation_library(&""):
		library = animation_player.get_animation_library(&"")
	else:
		library = AnimationLibrary.new()
		animation_player.add_animation_library(&"", library)
	_ensure(library, &"RESET", _make_animation(0.1, false,
			[[0.0, Vector3.ONE]]))
	_ensure(library, &"idle", _make_animation(8.0 * FRAME, true, [
			[0.0, Vector3.ONE],
			[2.0 * FRAME, Vector3(1.05, 0.94, 1.05)],
			[4.0 * FRAME, Vector3.ONE],
			[6.0 * FRAME, Vector3(0.96, 1.05, 0.96)],
	]))
	_ensure(library, &"run", _make_animation(4.0 * FRAME, true, [
			[0.0, Vector3(1.08, 0.9, 1.08)],
			[2.0 * FRAME, Vector3(0.9, 1.12, 0.9)],
	], [
			[0.0, Vector3.ZERO],
			[2.0 * FRAME, Vector3(0.0, 0.12, 0.0)],
	]))
	_ensure(library, &"air", _make_animation(4.0 * FRAME, true, [
			[0.0, Vector3(0.92, 1.14, 0.92)],
			[2.0 * FRAME, Vector3(0.88, 1.2, 0.88)],
	]))
	_ensure(library, &"dash", _make_animation(4.0 * FRAME, true, [
			[0.0, Vector3(0.8, 0.8, 1.35)],
			[2.0 * FRAME, Vector3(0.85, 0.85, 1.25)],
	]))
	_ensure(library, &"ground_pound", _make_animation(2.0 * FRAME, true, [
			[0.0, Vector3(1.2, 0.65, 1.2)],
			[FRAME, Vector3(0.65, 1.2, 0.65)],
	]))
	_ensure(library, &"pound_land", _make_animation(6.0 * FRAME, false, [
			[0.0, Vector3(1.6, 0.4, 1.6)],
			[3.0 * FRAME, Vector3(1.2, 0.75, 1.2)],
			[5.0 * FRAME, Vector3.ONE],
	]))
	_ensure(library, &"wall_slide", _make_animation(4.0 * FRAME, true, [
			[0.0, Vector3(1.06, 0.94, 1.06)],
			[2.0 * FRAME, Vector3(0.98, 1.04, 0.98)],
	]))


## Adds [param animation] under [param anim_name] unless an animation with
## that name already exists (i.e. real art has been slotted in).
func _ensure(library: AnimationLibrary, anim_name: StringName,
		animation: Animation) -> void:
	if not animation_player.has_animation(anim_name):
		library.add_animation(anim_name, animation)


## Builds one stepped animation. [param scale_keys] and [param position_keys]
## are arrays of [time, value] pairs. Every animation keys position at least
## once so discrete tracks never leak poses between states.
func _make_animation(length: float, loops: bool, scale_keys: Array,
		position_keys: Array = []) -> Animation:
	var animation := Animation.new()
	animation.length = length
	animation.loop_mode = Animation.LOOP_LINEAR if loops else Animation.LOOP_NONE
	_add_stepped_track(animation, ":scale", scale_keys)
	if position_keys.is_empty():
		position_keys = [[0.0, Vector3.ZERO]]
	_add_stepped_track(animation, ":position", position_keys)
	return animation


func _add_stepped_track(animation: Animation, property: String, keys: Array) -> void:
	var track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(track, NodePath(String(pivot_path) + property))
	animation.track_set_interpolation_type(track, Animation.INTERPOLATION_NEAREST)
	animation.value_track_set_update_mode(track, Animation.UPDATE_DISCRETE)
	for key: Array in keys:
		animation.track_insert_key(track, key[0], key[1])
