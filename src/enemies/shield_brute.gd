class_name ShieldBrute
extends EnemyBase
## Big, slow, shielded. The whole fight is a positioning puzzle: his front
## is a wall — swings clank off the shield — and his only hurtbox is behind
## it. He paces until you get close, plods at you, and when you're in range
## raises the shield high (the long, readable telegraph — your window to
## dash past/under him) and slams the area in front. After the slam the
## shield hangs low for a beat, so his front is briefly honest too:
## go behind during the raise, or punish the face after the slam.

## Attackers inside this forward cone (dot with facing) are blocked while
## the shield is up.
@export var shield_block_dot := 0.25

## Whether the front is currently a wall. The attack state drops this
## during the post-slam recovery.
var shield_up := true

@onready var _shield_pivot: Node3D = $Visual/ShieldPivot
@onready var _shield_rest_y: float = _shield_pivot.position.y


## The raise telegraph: lifts the shield visual, opening the gap beneath.
func set_shield_raised(amount: float) -> void:
	_shield_pivot.position.y = _shield_rest_y + amount * 1.1


func _hit_allowed(hit: Dictionary) -> bool:
	if not shield_up:
		return true
	var from: Vector3 = hit.get("position", global_position)
	var to_attacker := from - global_position
	to_attacker.y = 0.0
	if to_attacker.length() < 0.05:
		return true
	return to_attacker.normalized().dot(facing) < shield_block_dot


## Clank: flash only the shield, and no damage.
func _blocked_feedback(_hit: Dictionary) -> void:
	var mesh := _shield_pivot.get_node_or_null("Shield") as MeshInstance3D
	if mesh == null:
		return
	mesh.material_override = _flash_material
	get_tree().create_timer(0.09).timeout.connect(func() -> void:
		if is_instance_valid(mesh):
			mesh.material_override = null)
