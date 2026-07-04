class_name BouncePad
extends Area3D
## Bounce pad: *sets* (never adds) the player's velocity along this pad's
## local up axis on contact — tilt the pad in the editor for a diagonal
## launch. The bounce refunds the air dash, so it chains into dash or pound
## conversions the same way a pound landing does; pounding onto a pad
## amplifies the launch (see MovementStats "Bounce Pads").


## Launch speed along local up; negative uses MovementStats.bounce_default_speed.
@export var launch_speed := -1.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	var speed: float = launch_speed if launch_speed > 0.0 \
			else player.stats.bounce_default_speed
	player.bounce(global_basis.y, speed)
