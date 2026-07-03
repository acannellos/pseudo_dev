class_name MovementStats
extends Resource
## Tuning values for the entire movement kit.
##
## Kept as a [Resource] so alternate characters or game modes can swap in a
## different .tres without touching any state logic. Every state reads its
## numbers from here via [member Player.stats].

@export_group("Ground")
## Target speed from plain running input.
@export var run_speed := 9.0
@export var ground_accel := 60.0
## Friction applied when there is no input (and no bunny-hop grace).
@export var ground_decel := 45.0
## How fast velocity redirects toward input while over run speed (rad/s).
@export var turn_speed := 7.0
## Gentle drag applied above run speed so excess momentum decays slowly.
@export var overspeed_drag := 3.5

@export_group("Jumping")
@export var jump_velocity := 12.0
## Multiplier applied to upward velocity when jump is released early.
@export var jump_cut_multiplier := 0.45
@export var coyote_time := 0.12
@export var jump_buffer_time := 0.15

@export_group("Bunny Hop")
## Grace window after landing during which ground friction is suppressed.
@export var bhop_window := 0.15
## Speed added per successful chained hop.
@export var bhop_speed_bonus := 0.8
## Ceiling on speed gained purely from hop chaining.
@export var bhop_max_speed := 20.0

@export_group("Air")
@export var gravity := 30.0
@export var max_fall_speed := 40.0
@export var air_accel := 32.0
## Max speed reachable from air steering alone (momentum can exceed this).
@export var air_speed := 9.0
## How fast momentum redirects toward input at overspeed in the air (rad/s).
@export var air_turn_speed := 3.2

@export_group("Slopes")
## Slopes steeper than this are unwalkable and shed the character.
@export var walkable_slope_degrees := 46.0
## Multiplier on the gravity-along-slope acceleration while running downhill.
@export var slope_accel_factor := 1.6
## Speed ceiling for slope-fed acceleration.
@export var slope_max_speed := 24.0

@export_group("Dash")
@export var dash_speed := 18.0
@export var dash_time := 0.18

@export_group("Ground Pound")
## Brief hang before the slam drops.
@export var pound_windup_time := 0.09
@export var pound_fall_speed := 42.0
## How long after impact the conversion inputs are accepted.
@export var pound_land_window := 0.3
## Fraction of impact speed converted into horizontal boost speed.
@export var pound_boost_factor := 0.55
@export var pound_boost_max := 26.0
## Small upward pop that accompanies a pound boost.
@export var pound_boost_hop := 5.0
## Upward velocity of the pound super jump.
@export var pound_jump_velocity := 17.0

@export_group("Wall")
## Terminal fall speed while wall sliding.
@export var wall_slide_fall_speed := 5.0
## Gravity multiplier while wall sliding.
@export var wall_slide_gravity_scale := 0.4
## Horizontal friction on tangential speed while wall sliding.
@export var wall_friction := 8.0
@export var wall_kick_out_speed := 8.5
@export var wall_kick_up_speed := 11.0
