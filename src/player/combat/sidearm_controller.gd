class_name SidearmController
extends Node
## Sidearm: the secondary, ammo-limited ranged ability next to the staff —
## another parallel component. Fires only from an aim stance: locked on, the
## shot arcs onto the target (ballistic solve — the "aim a little over
## them" drop compensation is built in); in focus mode it arcs toward the
## crosshair direction. Unaimed presses do nothing, by design.
##
## Data-driven: everything about the current sidearm lives on a
## [SidearmStats] resource, so new sidearms are new .tres files (plus a
## projectile look, if they want one).

signal ammo_changed(current: int, maximum: int)
signal fired(stats: SidearmStats)

@export var player: Player
@export var targeting: TargetingSystem
@export var stats: SidearmStats

var ammo := 0

var _cooldown_left := 0.0


func _ready() -> void:
	if stats != null:
		ammo = stats.max_ammo


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if not Input.is_action_just_pressed(&"sidearm"):
		return
	if stats == null or ammo <= 0 or _cooldown_left > 0.0:
		return
	if targeting.is_active():
		_fire(TargetingSystem.point_of(targeting.target))
	elif targeting.is_focusing():
		_fire(_muzzle() + targeting.focus_dir * stats.focus_aim_range
				+ Vector3.UP * 0.5)


## Pickups call this (mana orbs from breakables).
func add_ammo(amount: int) -> void:
	ammo = clampi(ammo + amount, 0, stats.max_ammo)
	ammo_changed.emit(ammo, stats.max_ammo)


func _fire(aim_point: Vector3) -> void:
	ammo -= 1
	_cooldown_left = stats.cooldown
	SidearmProjectile.spawn(get_tree().current_scene, _muzzle(), aim_point, stats)
	ammo_changed.emit(ammo, stats.max_ammo)
	fired.emit(stats)


func _muzzle() -> Vector3:
	return player.global_position + Vector3.UP * 1.3 + player.facing * 0.35
