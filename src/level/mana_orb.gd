class_name ManaOrb
extends Area3D
## Sidearm-mana pickup dropped by breakables: a small bobbing glow orb;
## touch it to refill sidearm ammo. Code-built like the other one-shot FX.

var ammo := 5

var _time := 0.0
var _base_y := 0.0


static func spawn(parent: Node, position: Vector3, ammo_amount: int) -> void:
	var orb := ManaOrb.new()
	orb.ammo = ammo_amount
	parent.add_child(orb)
	orb.global_position = position
	orb._base_y = position.y


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # The player's body layer.
	monitoring = true
	monitorable = false
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.55
	shape.shape = ball
	add_child(shape)
	var core_material := StandardMaterial3D.new()
	core_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	core_material.albedo_color = Color(0.5, 0.85, 1.0)
	var core := MeshInstance3D.new()
	var core_mesh := SphereMesh.new()
	core_mesh.radius = 0.14
	core_mesh.height = 0.28
	core_mesh.radial_segments = 10
	core_mesh.rings = 5
	core.mesh = core_mesh
	core.material_override = core_material
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(core)
	var glow_material := StandardMaterial3D.new()
	glow_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_material.albedo_color = Color(0.4, 0.7, 1.0, 0.3)
	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.26
	glow_mesh.height = 0.52
	glow_mesh.radial_segments = 10
	glow_mesh.rings = 5
	glow.mesh = glow_mesh
	glow.material_override = glow_material
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glow)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	global_position.y = _base_y + sin(_time * 3.0) * 0.12


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null or player.sidearm == null:
		return
	player.sidearm.add_ammo(ammo)
	queue_free()
