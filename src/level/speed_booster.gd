class_name SpeedBooster
extends Area3D
## Speed booster / launch ramp floor trigger: adds a flat speed boost in the
## player's current movement (or facing) direction on contact. Capped by
## MovementStats "Speed Boosters" so booster chains can't run away.


## Speed added on contact; negative uses MovementStats.booster_default_boost.
@export var boost_amount := -1.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	var player := body as Player
	if player == null:
		return
	var amount: float = boost_amount if boost_amount > 0.0 \
			else player.stats.booster_default_boost
	player.apply_speed_boost(amount)
