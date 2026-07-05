class_name Breakable
extends StaticBody3D
## Breakable prop (barrel/crate): smashes from staff swings via the shared
## hit contract, or from the player simply moving through it fast enough —
## movement is combat here, so a dash or a slide chain pops it without a
## swing. Breaking bursts debris and drops a mana orb that refills sidearm
## ammo. Scene contract: a `Visual` Node3D holding the meshes.

signal broken

@export var hit_points := 1
## Sidearm ammo in the dropped mana orb.
@export var orb_ammo := 5
## Player speed at contact that smashes it outright (run speed is 9 —
## dashes, slides, and bhop chains qualify; walking into it doesn't).
@export var break_speed := 11.0
## Contact distance for the speed-break check.
@export var smash_radius := 1.3
@export var debris_color := Color(0.55, 0.4, 0.22)

var _hp := 0
var _player: Player
var _flash_material := StandardMaterial3D.new()

@onready var _visual: Node3D = $Visual


func _ready() -> void:
	_hp = hit_points
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = Color(1.0, 1.0, 1.0)
	_player = get_tree().get_first_node_in_group(&"player") as Player


func _physics_process(_delta: float) -> void:
	if _player == null:
		return
	if _player.velocity.length_squared() < break_speed * break_speed:
		return
	var to_player := _player.global_position + Vector3.UP * 0.5 - global_position
	if to_player.length() <= smash_radius:
		_break()


func take_hit(hit: Dictionary) -> void:
	var damage := int(hit.get("damage", 1))
	_hp -= damage
	DamageNumber.spawn(get_tree().current_scene,
			global_position + Vector3.UP * 1.0, damage)
	if _hp <= 0:
		_break()
	else:
		_flash()


func _break() -> void:
	broken.emit()
	_spawn_debris()
	ManaOrb.spawn(get_tree().current_scene,
			global_position + Vector3.UP * 0.6, orb_ammo)
	queue_free()


func _flash() -> void:
	for found in _visual.find_children("*", "MeshInstance3D", true, false):
		(found as MeshInstance3D).material_override = _flash_material
	get_tree().create_timer(0.09).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		for found in _visual.find_children("*", "MeshInstance3D", true, false):
			(found as MeshInstance3D).material_override = null)


func _spawn_debris() -> void:
	var debris := CPUParticles3D.new()
	var chunk := BoxMesh.new()
	chunk.size = Vector3(0.16, 0.16, 0.16)
	debris.mesh = chunk
	debris.one_shot = true
	debris.emitting = true
	debris.explosiveness = 1.0
	debris.amount = 16
	debris.lifetime = 0.7
	debris.spread = 70.0
	debris.direction = Vector3.UP
	debris.initial_velocity_min = 2.5
	debris.initial_velocity_max = 5.5
	debris.gravity = Vector3(0, -14, 0)
	debris.scale_amount_min = 0.5
	debris.scale_amount_max = 1.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = debris_color
	debris.mesh.surface_set_material(0, material)
	get_tree().current_scene.add_child(debris)
	debris.global_position = global_position + Vector3.UP * 0.5
	get_tree().create_timer(1.2).timeout.connect(debris.queue_free)
