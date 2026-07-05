class_name Hud
extends CanvasLayer
## Minimal gameplay HUD: sidearm ammo readout and the focus-aim crosshair
## (a plain dot for now). Signal-driven like the FX — listens to the
## player's SidearmController and TargetingSystem.

@export var player: Player

@onready var _ammo_label: Label = $AmmoLabel
@onready var _crosshair: Control = $Crosshair


func _ready() -> void:
	_crosshair.visible = false
	if player.sidearm != null:
		player.sidearm.ammo_changed.connect(_on_ammo_changed)
		_on_ammo_changed(player.sidearm.ammo, player.sidearm.stats.max_ammo)
	if player.targeting != null:
		player.targeting.focus_started.connect(func() -> void:
			_crosshair.visible = true)
		player.targeting.focus_ended.connect(func() -> void:
			_crosshair.visible = false)


func _on_ammo_changed(current: int, maximum: int) -> void:
	_ammo_label.text = "%s  %d / %d" % [player.sidearm.stats.display_name,
			current, maximum]
