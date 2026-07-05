class_name AfterimageTrail
extends Node
## Signal-driven afterimage trail: whenever the player performs a movement
## tech ([signal Player.tech_performed] — dash, wavedash, bunny hop, wall
## kick, pound conversion, jump variants…), a burst of [member image_count]
## frozen mesh snapshots is dropped behind the character in world space,
## each fading away. States never call this — it only listens up.

const AFTERIMAGE := preload("res://src/fx/afterimage.gd")

@export var player: Player
## Root of the meshes to snapshot (the player's animated visual).
@export var source_visual: Node3D
## Flat silhouette color of every afterimage.
@export var image_color := Color(0.62, 0.4, 1.0)
## Snapshots dropped per tech trigger.
@export var image_count := 5
## Seconds between snapshots — spacing along the movement path.
@export var spawn_interval := 0.04
## Seconds each snapshot takes to fade out.
@export var fade_time := 0.35

var _images_left := 0
var _spawn_timer := 0.0


func _ready() -> void:
	player.tech_performed.connect(_on_tech_performed)


func _on_tech_performed(_tech: StringName) -> void:
	_images_left = image_count
	_spawn_timer = 0.0


func _physics_process(delta: float) -> void:
	if _images_left <= 0:
		return
	_spawn_timer -= delta
	if _spawn_timer > 0.0:
		return
	_spawn_timer = spawn_interval
	_images_left -= 1
	AFTERIMAGE.spawn(get_tree().current_scene, source_visual, image_color, fade_time)
