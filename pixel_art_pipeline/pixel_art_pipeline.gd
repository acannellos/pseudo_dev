class_name PixelArtPipeline
extends Node
## Owner of the 3D-pixel-art render pipeline (see PIXEL_ART_PIPELINE.md).
##
## The whole 3D game (level, player, camera) lives inside
## [member world_viewport], a SubViewport rendered at a fixed low resolution
## and presented through [member screen], a nearest-filtered TextureRect
## scaled to the window. This node owns every layer toggle, forwards input
## into the SubViewport (nodes inside a SubViewport receive no events on
## their own), and applies the sub-texel smoothing offset published by
## [TexelSnap].
##
## Layers can be toggled in the Inspector or live in-game with the number
## keys (raw keycodes — the input map is untouched):
##   1 pixelation   2 texel snap   3 sub-texel smoothing   4 outline
##   5 quantize     6 dither       7 toon lighting         8 low-fps cap
##
## Per-layer tuning lives with each layer: outline/crush parameters on the
## post quad's material, band counts on the toon materials, snap focus on
## the TexelSnap node.

## Extra texels rendered on each side so the sub-texel smoothing offset never
## exposes an unrendered border.
const MARGIN_TEXELS := 2

@export_group("Wiring")
@export var world_viewport: SubViewport
@export var screen: TextureRect
@export var texel_snap: TexelSnap
@export var post_quad: MeshInstance3D

@export_group("Resolution")
## Fixed internal render resolution. 384x216 is 16:9 and exactly 5x at
## 1080p, so default windows get perfect integer pixels.
@export var internal_resolution := Vector2i(384, 216):
	set(value):
		internal_resolution = value.max(Vector2i(64, 36))
		_refresh()

@export_group("Layers")
## Layer 1: render at [member internal_resolution] instead of window size.
@export var pixelation_enabled := true:
	set(value):
		pixelation_enabled = value
		_refresh()
## Layer 2: snap the camera to the texel grid (kills pixel swim).
@export var snap_enabled := true:
	set(value):
		snap_enabled = value
		_refresh()
## Layer 2b: slide the upscaled image by the snap remainder so camera motion
## stays smooth while texels stay locked.
@export var smooth_subtexel := true:
	set(value):
		smooth_subtexel = value
		_refresh()
## Layer 3: depth+normal outline pass.
@export var outline_enabled := true:
	set(value):
		outline_enabled = value
		_refresh()
## Layer 4a: colour quantization ("crush").
@export var quantize_enabled := true:
	set(value):
		quantize_enabled = value
		_refresh()
## Layer 4b: 8x8 Bayer ordered dithering.
@export var dither_enabled := true:
	set(value):
		dither_enabled = value
		_refresh()
## Layer 5: stepped toon lighting on all toon materials (global uniform).
@export var toon_enabled := true:
	set(value):
		toon_enabled = value
		_refresh()
## Layer 6 (optional stylistic): cap the world render rate at [member low_fps]
## while game logic keeps running at full rate.
@export var low_fps_enabled := false:
	set(value):
		low_fps_enabled = value
		_frame_accum = 0.0
		_refresh()
@export_range(4.0, 30.0) var low_fps := 12.0

var _frame_accum := 0.0


func _ready() -> void:
	# After TexelSnap (priority 1000) so this frame's offset is consumed,
	# not last frame's.
	process_priority = 1001
	screen.texture = world_viewport.get_texture()
	get_viewport().size_changed.connect(_refresh)
	_refresh()


func _process(delta: float) -> void:
	if low_fps_enabled:
		_frame_accum += delta
		var interval := 1.0 / maxf(low_fps, 1.0)
		if _frame_accum >= interval:
			_frame_accum = fmod(_frame_accum, interval)
			world_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_update_screen_transform()


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and _toggle_for_key(key.keycode):
		get_viewport().set_input_as_handled()
		return
	# Nodes inside a SubViewport (orbit camera, level switcher) never receive
	# input on their own — feed them everything that reached us unhandled.
	if world_viewport != null:
		world_viewport.push_input(event, false)


## Live layer toggles on the number row. Returns whether the key was one.
func _toggle_for_key(keycode: Key) -> bool:
	match keycode:
		KEY_1: pixelation_enabled = not pixelation_enabled
		KEY_2: snap_enabled = not snap_enabled
		KEY_3: smooth_subtexel = not smooth_subtexel
		KEY_4: outline_enabled = not outline_enabled
		KEY_5: quantize_enabled = not quantize_enabled
		KEY_6: dither_enabled = not dither_enabled
		KEY_7: toon_enabled = not toon_enabled
		KEY_8: low_fps_enabled = not low_fps_enabled
		_: return false
	return true


## Pushes every toggle out to the nodes/materials/globals that implement it.
func _refresh() -> void:
	if not is_node_ready():
		return
	var window := _window_size()
	var margin := _margin_texels()
	world_viewport.size = _render_resolution(window) + Vector2i(margin, margin) * 2
	world_viewport.render_target_update_mode = (
			SubViewport.UPDATE_DISABLED if low_fps_enabled
			else SubViewport.UPDATE_ALWAYS)
	if texel_snap != null:
		texel_snap.enabled = snap_enabled
	if post_quad != null:
		var post := post_quad.material_override as ShaderMaterial
		if post != null:
			post.set_shader_parameter(&"outline_enabled", outline_enabled)
			post.set_shader_parameter(&"quantize_enabled", quantize_enabled)
			post.set_shader_parameter(&"dither_enabled", dither_enabled)
	RenderingServer.global_shader_parameter_set(
			&"pixel_toon_enabled", 1.0 if toon_enabled else 0.0)
	_update_screen_transform()


## Positions/sizes the presenting TextureRect: base upscale, minus the margin
## border, plus this frame's sub-texel smoothing offset.
func _update_screen_transform() -> void:
	if screen == null:
		return
	var window := _window_size()
	var res := Vector2(_render_resolution(window))
	var scale := window / res
	var margin := float(_margin_texels())
	var offset := Vector2.ZERO
	if margin > 0.0 and texel_snap != null and not low_fps_enabled:
		offset = texel_snap.screen_offset_texels.clamp(
				Vector2(-margin, -margin), Vector2(margin, margin))
	screen.position = (Vector2(-margin, -margin) + offset) * scale
	screen.size = (res + Vector2(margin, margin) * 2.0) * scale


func _window_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _render_resolution(window: Vector2) -> Vector2i:
	return internal_resolution if pixelation_enabled else Vector2i(window)


func _margin_texels() -> int:
	var smoothing := pixelation_enabled and snap_enabled and smooth_subtexel
	return MARGIN_TEXELS if smoothing else 0
