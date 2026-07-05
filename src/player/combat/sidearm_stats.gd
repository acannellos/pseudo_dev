class_name SidearmStats
extends Resource
## Tuning for one sidearm (secondary ranged ability). Swap the .tres on the
## player's [SidearmController] to change sidearms — same pattern as
## [MovementStats]. The magic arrows live in
## `src/player/combat/sidearms/magic_arrows.tres`.

@export var display_name := "Magic Arrows"
@export var max_ammo := 20
@export var damage := 1
## Launch speed — the ballistic solve stretches flight time from this.
@export var projectile_speed := 16.0
## Gravity on the projectile; the aim compensates by lofting over the
## target so a locked shot still lands.
@export var projectile_gravity := 18.0
@export var cooldown := 0.35
## How far ahead the aim point sits when firing from focus (no lock).
@export var focus_aim_range := 14.0
@export var color_core := Color(0.6, 0.95, 1.0)
@export var color_trail := Color(0.3, 0.55, 1.0)
