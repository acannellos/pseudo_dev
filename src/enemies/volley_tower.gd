class_name VolleyTower
extends StaticBody3D
## Dead man's volley spire (mini Phantom-Ganon tennis). Come in range and
## an orb charges above the spire (readable wind-up), then fires at where
## you are standing. Your normal swing is the racket: connect as the orb
## arrives and it flies back at the spire. The tower has a 50/50 chance of
## returning the volley — faster every rebound, OoT style (and the orb
## swaps color per owner: gold from the tower, blue off your staff) — and
## only ever has one orb in play. Three failed returns kill it. Swords do
## nothing to the tower directly: the rally is the only way in.
##
## Stationary and phase-driven, so unlike the walking enemies it keeps a
## small internal phase enum instead of hosting an [EnemyStateMachine] —
## the interesting state lives on the orb.

signal died

const FLASH_TIME := 0.14

@export var max_hp := 3
@export var engage_range := 13.0
## The orb grows above the spire for this long before firing.
@export var charge_time := 1.4
@export var cooldown_time := 1.8
@export var orb_speed := 7.0
## Speed multiplier applied when the tower returns a volley.
@export var return_speed_multiplier := 1.2
@export var return_chance := 0.5
## Z-target/LOS point height (mid-spire).
@export var target_height := 2.4

enum Phase { DORMANT, CHARGING, RALLY, COOLDOWN }

var phase := Phase.DORMANT

var _hp := 0
var _timer := 0.0
var _dead := false
var _player: Player
var _orb: VolleyOrb
var _flash_material := StandardMaterial3D.new()

@onready var _orb_anchor: Node3D = $OrbAnchor
@onready var _visual: Node3D = $Visual


func _ready() -> void:
	_hp = max_hp
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.albedo_color = Color(1.0, 1.0, 1.0)
	_player = get_tree().get_first_node_in_group(&"player") as Player


func _physics_process(delta: float) -> void:
	if _dead or _player == null:
		return
	var dist := global_position.distance_to(_player.global_position)
	match phase:
		Phase.DORMANT:
			if dist <= engage_range:
				_begin_charge()
		Phase.CHARGING:
			_timer -= delta
			if dist > engage_range * 1.3:
				_cancel_charge()
			elif _timer <= 0.0:
				_fire()
		Phase.RALLY:
			pass  # The orb drives; it calls back into the tower.
		Phase.COOLDOWN:
			_timer -= delta
			if _timer <= 0.0:
				phase = Phase.DORMANT


# --- Z-target / hit contracts ----------------------------------------------

func is_targetable() -> bool:
	return not _dead


func target_point() -> Vector3:
	return global_position + Vector3.UP * target_height


## Direct staff hits clank off — the volley is the only way to hurt it.
func take_hit(_hit: Dictionary) -> void:
	if _dead:
		return
	_flash(0.08)


# --- Orb callbacks ----------------------------------------------------------

## A returned orb arrived: 50/50 volley back (faster) or eat the hit.
func on_orb_returned(orb: VolleyOrb) -> void:
	if randf() < return_chance:
		orb.volley_to_player(_player, return_speed_multiplier)
	else:
		orb.dissipate()
		_take_volley_hit()


## The orb resolved without coming back (hit or missed the player).
func on_orb_resolved() -> void:
	if phase == Phase.RALLY:
		phase = Phase.COOLDOWN
		_timer = cooldown_time


# --- Internals ---------------------------------------------------------------

func _begin_charge() -> void:
	phase = Phase.CHARGING
	_timer = charge_time
	_orb = VolleyOrb.new()
	_orb.tower = self
	get_tree().current_scene.add_child(_orb)
	_orb.begin_charge(_orb_anchor.global_position, charge_time)


func _cancel_charge() -> void:
	phase = Phase.DORMANT
	if is_instance_valid(_orb):
		_orb.dissipate()
	_orb = null


func _fire() -> void:
	phase = Phase.RALLY
	_orb.launch_at(_player, orb_speed)


func _take_volley_hit() -> void:
	_hp -= 1
	_flash(FLASH_TIME)
	DamageNumber.spawn(get_tree().current_scene, target_point(), 1)
	if _hp <= 0:
		_die()
	else:
		phase = Phase.COOLDOWN
		_timer = cooldown_time


func _flash(duration: float) -> void:
	for found in _visual.find_children("*", "MeshInstance3D", true, false):
		var mesh := found as MeshInstance3D
		mesh.material_override = _flash_material
	get_tree().create_timer(duration).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		for found in _visual.find_children("*", "MeshInstance3D", true, false):
			(found as MeshInstance3D).material_override = null)


## Dead towers stay as husks: no more volleys, no longer targetable.
func _die() -> void:
	_dead = true
	phase = Phase.DORMANT
	died.emit()
	_visual.scale = Vector3(1.0, 0.55, 1.0)
