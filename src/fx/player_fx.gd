class_name PlayerFX
extends Node3D
## Signal-driven gameplay FX for the player: skid dust bursts and the pound
## impact shockwave ring. Listens up to [Player] / [PlayerStateMachine]
## signals — states never call FX directly, so the moves stay pure logic.

const SHOCKWAVE_RING := preload("res://src/fx/shockwave_ring.gd")

@export var player: Player
## Wired explicitly (not via player.state_machine) because children ready
## before their parent — the player's own @onready vars aren't set yet.
@export var state_machine: PlayerStateMachine

var _skid_dust := CPUParticles3D.new()


func _ready() -> void:
	_configure_skid_dust()
	add_child(_skid_dust)
	player.skid_started.connect(_on_skid_started)
	state_machine.state_changed.connect(_on_state_changed)


func _configure_skid_dust() -> void:
	var puff := BoxMesh.new()
	puff.size = Vector3(0.14, 0.14, 0.14)
	_skid_dust.mesh = puff
	_skid_dust.emitting = false
	_skid_dust.one_shot = true
	_skid_dust.explosiveness = 1.0
	_skid_dust.amount = 14
	_skid_dust.lifetime = 0.45
	_skid_dust.spread = 30.0
	_skid_dust.initial_velocity_min = 2.0
	_skid_dust.initial_velocity_max = 4.5
	_skid_dust.gravity = Vector3(0.0, 2.5, 0.0)
	_skid_dust.scale_amount_min = 0.5
	_skid_dust.scale_amount_max = 1.0
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.75, 0.72, 0.68, 1.0)
	_skid_dust.mesh.surface_set_material(0, material)


## Dust kicks out along the old velocity direction, at the feet.
func _on_skid_started(direction: Vector3) -> void:
	_skid_dust.global_position = player.global_position + Vector3.UP * 0.15
	_skid_dust.direction = direction
	_skid_dust.restart()


func _on_state_changed(_previous: StringName, current: StringName) -> void:
	if current == &"PoundLand":
		SHOCKWAVE_RING.spawn(get_tree().current_scene, player.global_position)
