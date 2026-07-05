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

@export_group("Crouch Slide")
## Friction applied to the slide instead of [member ground_decel].
@export var slide_friction := 5.0
## Slide friction never drags speed below this floor while crouch is held.
@export var slide_sustain_speed := 4.5
## Capsule height while sliding (standing height comes from the scene).
@export var slide_capsule_height := 1.0
## How fast the slide redirects toward input (rad/s); low = committed.
@export var slide_turn_speed := 2.2

@export_group("Turnaround")
## Minimum grounded speed before a hard reversal triggers a skid.
@export var turnaround_min_speed := 6.5
## Input must oppose velocity by at least this angle to trigger the skid.
@export var turnaround_angle_degrees := 120.0
## Skid deceleration; the skid ends when speed crosses zero.
@export var turnaround_decel := 28.0
## Hard cap on skid duration in case deceleration never finishes.
@export var turnaround_max_time := 0.6

@export_group("Turn Jump")
## Multiplier on [member jump_velocity] for a jump out of a skid.
@export var turn_jump_height_multiplier := 1.35
## Horizontal pop in the new facing direction when the turn jump launches.
@export var turn_jump_forward_speed := 5.0

@export_group("Long Jump")
## Minimum grounded speed to convert a crouch-jump into a long jump.
@export var long_jump_min_speed := 7.0
## Vertical launch speed — deliberately flatter than a normal jump.
@export var long_jump_velocity := 8.5
## Horizontal speed added on top of current speed at launch.
@export var long_jump_boost := 5.5
## Ceiling on horizontal speed gained from chained long jumps.
@export var long_jump_max_speed := 27.0
## Slide age within which crouch+jump still reads as the long-jump combo;
## older established slides slide-hop instead.
@export var long_jump_combo_window := 0.2

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

@export_group("Slide-Hop")
## Vertical speed of a hop out of an established slide — flatter than a jump.
@export var slide_hop_velocity := 7.5

@export_group("Wavedash")
## After an air dash touches down, jump within this window to wavedash.
@export var wavedash_window := 0.09
## Horizontal speed added by a successful wavedash (beyond the dash-hop's
## plain speed keep).
@export var wavedash_boost := 4.5

@export_group("Triple Jump")
## Jump again within this window after landing to continue the chain.
@export var triple_jump_window := 0.3
## Height multipliers for the second and third jump of the chain.
@export var triple_jump_second_multiplier := 1.18
@export var triple_jump_third_multiplier := 1.45

@export_group("Side-flip / Backflip")
## Height multiplier for both flip variants (no forward commitment).
@export var flip_height_multiplier := 1.3
## Backflip: grounded speed must be below this (near standstill).
@export var backflip_max_speed := 2.0
## Backflip: small pop opposite facing.
@export var backflip_pop_speed := 3.5
## Side-flip: grounded speed must be below this (strafe, not a momentum run).
@export var sideflip_max_speed := 7.5
## Side-flip: small lateral pop in the strafe direction.
@export var sideflip_pop_speed := 4.0

@export_group("Ledge Grab")
## How far ahead of the chest the wall probe reaches.
@export var ledge_reach := 1.0
## Ledge lip must sit between these heights above the feet to be grabbable.
@export var ledge_min_height := 0.7
@export var ledge_max_height := 2.4
## Rising faster than this means "not near apex yet" — no grab.
@export var ledge_grab_max_rise_speed := 4.0
## Brief hang before the climb starts.
@export var ledge_hang_time := 0.1
## Duration of the climb-up onto the lip.
@export var ledge_mantle_time := 0.28

@export_group("Wall Run")
## Tangential (along-wall) speed needed to run the wall instead of sliding.
@export var wall_run_min_speed := 10.0
## How long the wall run lasts before it decays into slide/fall.
@export var wall_run_time := 0.8
## Gravity multiplier during the run — near-flat trajectory along the wall.
@export var wall_run_gravity_scale := 0.12
## Small vertical lift when the run starts.
@export var wall_run_up_boost := 2.5

@export_group("Bounce Pads")
## Launch speed a pad uses when it does not override it per-instance.
@export var bounce_default_speed := 20.0
## Bounce amplification when ground-pounding onto a pad.
@export var bounce_pound_multiplier := 1.35

@export_group("Speed Boosters")
## Speed added by a booster when it does not override it per-instance.
@export var booster_default_boost := 8.0
## Boosters never push the player past this horizontal speed.
@export var booster_max_speed := 30.0

@export_group("Combat")
## Duration of one staff swing (input locked out until the chain point).
@export var swing_time := 0.28
## Portion of the swing (from its start) during which the hitbox is live.
@export var swing_active_time := 0.16
## Attack presses within this window before a swing can start are honored.
@export var attack_buffer_time := 0.2
## After a swing ends, the next press must land within this window to chain
## into the next combo hit; later presses start over at swing 1.
@export var combo_reset_time := 0.7
## Damage dealt per hit (the third combo hit deals double).
@export var attack_damage := 1
## How far in front of the chest the swing arc reaches.
@export var attack_range := 1.9
## Half-width of the swing arc hitbox.
@export var attack_half_width := 1.3
## Gravity multiplier while swinging airborne — a slight anime float.
@export var air_attack_gravity_scale := 0.45

@export_group("Lunge Attack")
## Forward speed of the Z-targeted jump slice (OoT jump attack).
@export var lunge_speed := 9.5
## Upward pop at lunge launch — a short committed hop, not a full jump.
@export var lunge_up_speed := 5.0
## Swing duration for the lunge (hitbox live the whole flight).
@export var lunge_swing_time := 0.55
## Landing recovery before control returns — the deliberate OoT beat.
@export var lunge_recovery_time := 0.22
## Damage multiplier of the lunge slice (OoT jump attacks deal double).
@export var lunge_damage_multiplier := 2

@export_group("Wall")
## Terminal fall speed while wall sliding.
@export var wall_slide_fall_speed := 5.0
## Gravity multiplier while wall sliding.
@export var wall_slide_gravity_scale := 0.4
## Horizontal friction on tangential speed while wall sliding.
@export var wall_friction := 8.0
@export var wall_kick_out_speed := 8.5
@export var wall_kick_up_speed := 11.0
