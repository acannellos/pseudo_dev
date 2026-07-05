class_name TexelSnap
extends Node
## Camera texel-grid snapping (pipeline layer 2 — the anti-pixel-swim layer).
##
## Every render frame, after the camera scripts have positioned the camera
## (this node runs at a late [member Node.process_priority]), the camera's
## position is snapped onto a grid aligned to its own right/up axes, spaced
## one texel apart. World geometry therefore always lands on the same texel
## boundaries while the camera translates, which kills shimmer/crawl.
##
## The sub-texel remainder is published in [member screen_offset_texels] so
## [PixelArtPipeline] can slide the upscaled image by the fraction the camera
## was snapped by — motion stays smooth on screen while texels stay locked
## (the t3ssel8r trick). With a perspective camera the texel size is exact at
## [member focus_distance] (the player's orbit distance) and approximate
## elsewhere; rotation is left continuous, so orbiting still crawls — only
## translation can be made stable without an orthographic camera.

@export var camera: Camera3D
@export var enabled := true
## Distance at which one texel is made to map exactly onto one viewport
## pixel. Values <= 0 auto-detect the parent SpringArm3D's spring length.
@export var focus_distance := 0.0

## Sub-texel image shift (in texels, x right / y down in screen space) that
## compensates for the snap this frame. Consumed by [PixelArtPipeline].
var screen_offset_texels := Vector2.ZERO


func _ready() -> void:
	# After OrbitCamera/SpringArm3D and any other camera movers.
	process_priority = 1000


func _process(_delta: float) -> void:
	screen_offset_texels = Vector2.ZERO
	if not enabled or camera == null or not camera.is_inside_tree():
		return
	var viewport_height := float(camera.get_viewport().get_visible_rect().size.y)
	if viewport_height < 1.0:
		return
	var texel := _texel_world_size(viewport_height)
	if texel <= 0.0:
		return
	var xf := camera.global_transform
	var right := xf.basis.x
	var up := xf.basis.y
	var u := xf.origin.dot(right)
	var v := xf.origin.dot(up)
	var su := snappedf(u, texel)
	var sv := snappedf(v, texel)
	camera.global_position = xf.origin + right * (su - u) + up * (sv - v)
	# True position minus snapped, in texels. Shifting the displayed image by
	# (-du, +dv) screen pixels reproduces the un-snapped framing exactly.
	var du := (u - su) / texel
	var dv := (v - sv) / texel
	screen_offset_texels = Vector2(-du, dv)


## World-space size of one texel at the focus plane.
func _texel_world_size(viewport_height: float) -> float:
	if camera.projection == Camera3D.PROJECTION_ORTHOGONAL:
		return camera.size / viewport_height
	var dist := focus_distance
	if dist <= 0.0:
		var arm := camera.get_parent() as SpringArm3D
		dist = arm.spring_length if arm != null else 6.0
	return 2.0 * dist * tan(deg_to_rad(camera.fov) * 0.5) / viewport_height
