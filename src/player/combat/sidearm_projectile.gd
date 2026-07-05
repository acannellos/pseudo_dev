class_name SidearmProjectile
extends Area3D
## The sidearm's projectile: a retro low-poly magic bolt (glowing shaft,
## diamond tip, particle trail) flying a true ballistic arc. The spawn
## solve lofts it over the aim point exactly enough to cancel the gravity
## drop, so a locked shot lands on the target — the OoT-style "aim a bit
## above them" reward, done for the player. Anything hittable it touches
## takes the sidearm's damage; world geometry stops it.
##
## Styled entirely from [SidearmStats] (colors, speed, gravity, damage),
## so future sidearms can reuse it or swap in their own scene.

const LIFETIME := 5.0
## Ballistic solve clamps flight time so point-blank shots stay sane.
const MIN_FLIGHT_TIME := 0.15

var _stats: SidearmStats
var _velocity := Vector3.ZERO
var _age := 0.0


static func spawn(parent: Node, origin: Vector3, aim_point: Vector3,
		stats: SidearmStats) -> void:
	var arrow := SidearmProjectile.new()
	arrow._stats = stats
	var to_target := aim_point - origin
	var flight_time := maxf(to_target.length() / stats.projectile_speed,
			MIN_FLIGHT_TIME)
	# Velocity that lands exactly on the aim point under gravity: straight
	# shot plus the lofted compensation term.
	arrow._velocity = to_target / flight_time \
			+ Vector3.UP * 0.5 * stats.projectile_gravity * flight_time
	parent.add_child(arrow)
	arrow.global_position = origin
	arrow._orient()


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.22
	shape.shape = ball
	add_child(shape)
	_build_visual()
	body_entered.connect(_on_hit)
	area_entered.connect(_on_hit)


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= LIFETIME:
		queue_free()
		return
	_velocity.y -= _stats.projectile_gravity * delta
	global_position += _velocity * delta
	_orient()


func _on_hit(node: Node) -> void:
	if node.has_method(&"take_hit"):
		node.take_hit({
			"damage": _stats.damage,
			"direction": _velocity.normalized(),
			"position": global_position,
			"source": &"sidearm",
		})
	queue_free()


func _orient() -> void:
	if _velocity.length() > 0.1:
		look_at(global_position + _velocity.normalized())


## Shaft + diamond tip + trailing particles, colored from the stats.
func _build_visual() -> void:
	var core := StandardMaterial3D.new()
	core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core.albedo_color = _stats.color_core
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.07, 0.07, 0.55)
	shaft.mesh = shaft_mesh
	shaft.material_override = core
	shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.14, 0.14, 0.14)
	tip.mesh = tip_mesh
	tip.material_override = core
	tip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tip.position = Vector3(0, 0, -0.32)
	tip.rotation = Vector3(0.0, PI * 0.25, 0.0)
	add_child(tip)
	var trail := CPUParticles3D.new()
	var puff := BoxMesh.new()
	puff.size = Vector3(0.06, 0.06, 0.06)
	trail.mesh = puff
	trail.amount = 14
	trail.lifetime = 0.35
	trail.local_coords = false
	trail.spread = 8.0
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.4
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.4
	trail.scale_amount_max = 1.0
	trail.color = _stats.color_trail
	var trail_material := StandardMaterial3D.new()
	trail_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_material.vertex_color_use_as_albedo = true
	trail.mesh.surface_set_material(0, trail_material)
	add_child(trail)
