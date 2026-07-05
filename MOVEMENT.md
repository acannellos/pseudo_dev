# pseudo_dev — movement-tech prototype

A Godot 4.7 third-person movement-platformer prototype in the lineage of
Mario 64 / Pseudoregalia / The Big Catch. Momentum is the design pillar:
every move preserves, redirects, or converts speed — nothing resets it.

Open the project and press Play (`scenes/main.tscn` is the main scene).
Fall off the world and you respawn at the start.

The game renders through a toggleable 3D-pixel-art pipeline (low-res
viewport, camera texel snapping, outlines, palette crush, toon lighting) —
see [PIXEL_ART_PIPELINE.md](PIXEL_ART_PIPELINE.md). Two dressed demo
scenes (outdoor fantasy, castle interior) join the two greybox test levels
in the F5 rotation; the game boots into the outdoor demo.

## Controls

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Move | WASD | Left stick |
| Camera | Mouse | Right stick |
| Jump | Space | A (bottom) |
| Dash | Shift | X / Right shoulder |
| Crouch / Slide (hold) | Left Ctrl | L3 (left stick click) |
| Ground pound | C | B / Left shoulder |
| Toggle debug view | F3 | — |
| Cycle level (outdoor → castle → test 1 → test 2) | F5 | — |
| Toggle render-pipeline layers | 1–8 | — |
| Release / capture mouse | Esc / click | — |

## The movement kit

**Jump** — preserves all horizontal velocity by construction (jumps only set
vertical speed). Variable height: release jump early to cut the rise. Coyote
time (0.12 s) and a jump input buffer (0.15 s) are always active.

**Bunny hop** — press jump on (or buffer it just before) the landing frame:
friction never touches you, you keep all horizontal speed, gain a small
bonus per chained hop (up to a cap), and relaunch instantly. There is also a
short grace window after landing during which ground friction is suppressed,
so a slightly late hop still keeps its speed. The hop chain counter is shown
in the debug overlay.

**Slopes** — floor snapping and `floor_constant_speed` keep transitions
smooth; additionally, gravity-along-slope acceleration applies while moving
on walkable inclines: running downhill builds real speed (own cap, higher
than run speed), running uphill costs it. Slopes steeper than 46° are
unwalkable and shed the character. Carry downhill speed into a bunny-hop
chain to keep it.

**Dash** — flat burst in the input (or facing) direction. Dash speed is a
*floor*: dashing while already faster keeps the higher speed. Jumping during
a grounded dash keeps the full dash speed (dash-hop). One air dash per
airtime; refunded on landing, wall kick, or pound impact.

**Ground pound → momentum conversion** (Ultrakill-inspired) — press ground
pound in the air: short hang, then a 42 m/s slam. On impact a 0.3 s
conversion window opens:

- **Dash** during the window → the stored impact speed converts into a large
  horizontal boost (~23 m/s) in the input direction, with a small pop —
  far beyond anything a plain dash gives.
- **Jump** during the window → super jump (much higher than a normal jump).
- Do nothing → the pound just ends (recovery), momentum dead. Converting is
  always better.
- **Dash during the fall** cancels the pound into an air dash (early
  conversion).

**Wall slide / wall kick** — hold toward a wall while falling to slide
slowly; jump to kick off (out + up, tangential speed preserved, air dash
refunded). Two facing walls form a climbable chimney.

**Air control** — below ~9 m/s, air input accelerates you normally; above
it, input only *redirects* your momentum (magnitude preserved — no free
speed, no punishment for steering).

**Crouch slide** — hold Crouch/Slide while grounded and moving: the capsule
drops, friction drops, and speed decays only to a sustain floor — holding a
slide never fully arrests you. Steering is committed (slow redirect), slope
acceleration still applies, so sliding downhill builds speed. Release to
stand back up into Run/Idle (blocked while under low geometry).

**Skid turnaround → Turn jump** — reverse input hard (≥ ~120°) while
running above a speed threshold: instead of carving, the character plants
and skids, bleeding speed on its own deceleration curve with normal
steering locked out. Let it finish to pivot cleanly into the new direction
— or press jump during the skid for a **Turn Jump**: a higher-than-normal
apex with a small forward pop in the new facing direction. Grounded-trigger
only; it never competes with the bunny-hop landing window.

**Long jump** — crouch + jump while above a speed threshold: a flatter,
longer arc with a horizontal boost and **no air control** — velocity is
committed at launch (ground pound is the only cancel; bonking a wall
returns control). Lands into a slide; if enough speed survives the landing,
jumping again immediately re-triggers, so long jumps chain like Mario 64's.
Distinct from the bunny hop: bhop keeps speed you already have on a normal
landing, the long jump spends a committed jump to buy distance.

**Ledge grab / mantle** — near apex or while falling toward a ledge lip,
the character grabs it and climbs up instead of bonking or falling short
(raycast probe, same wall-detection pattern as the slides). Brief hang,
then an automatic mantle onto the lip. During the hang: jump wall-kicks
away, crouch drops.

**Wall run** — hit a wall with enough *along-wall* speed and the fall
converts into a brief run along the surface (near-flat trajectory, small
initial lift). Jump kicks off with the shared wall kick (out + up,
tangential speed preserved, air dash refunded). When the run expires it
decays into a wall slide if you're still holding toward the wall. Wall
slide and wall run share the same wall-contact detection and split purely
on incoming tangential speed — slide is the low-speed chimney tool, run is
the high-speed traversal tool.

**Slide-Hop** — jump out of an *established* slide (held past the long-jump
combo window): a flatter, friction-immune hop that keeps all horizontal
speed. The second bhop-family tech — the bunny hop is gated on
landing-window timing, the slide-hop on being in a slide. Landing with
crouch still held re-enters the slide, so slide → hop → slide chains flow.

**Wavedash** — an *air* dash that touches the ground and is cancelled into
a jump within a tight window (~0.09 s) gains speed beyond the plain
dash-hop keep. Same dash→jump interaction, higher skill ceiling: the
dash-hop preserves, the wavedash pays out.

**Triple jump chain** — consecutive grounded jumps with no stop between
them: re-jump within a short window after each landing and every jump is
higher than the last, capping at the third (chain shown in the debug
overlay). The bunny hop always wins the landing frame itself — a bhop
keeps speed and resets the triple chain; the triple rewards the slightly
later, deliberate re-jump. Any non-locomotion state (dash, slide, skid,
wall contact, jump variants) breaks the chain.

**Side-flip / Backflip** — context-sensitive jump variants with extra
height and *no forward commitment* (the anti-Long-Jump): **backflip** from
a near standstill while pushing away from facing; **side-flip** from a
low-speed strafing input. Both give a small pop in the input direction and
otherwise fly like a normal jump.

**Moving platforms** — the player inherits platform velocity while riding
and keeps it on jump/step-off (`move_and_slide()` platform velocity with
the default `platform_on_leave = ADD_VELOCITY`; the greybox
`MovingPlatform` scene uses `sync_to_physics` so its velocity is real).

**Bounce pads & speed boosters** (environmental, no player state) —
bounce pads *set* velocity along the pad's up axis (tilt the pad for a
diagonal launch); a straight-up pad keeps your horizontal speed so bounces
chain. The bounce refunds the air dash, so pad → air dash or pad → pound
conversions flow like a pound landing does, and pounding *onto* a pad
amplifies the launch. Speed boosters add a flat boost in your current
movement direction, capped so booster chains can't run away. Both are
reusable `Area3D` scenes under `scenes/objects/`.

## State machine

`StateMachine` node under the player hosts one node per state
(`src/player/states/`). States are found by node name; each state drives
velocity, calls `move_and_slide()`, and requests transitions. For a visual
diagram of every transition, see [STATE_CHART.md](STATE_CHART.md).

| State | Entered from | Exits to |
| --- | --- | --- |
| `Idle` | Run, PoundLand, landing | Run, Air, Dash |
| `Run` | Idle, Air, Dash | Idle, Air, Dash |
| `Air` | any (jump, falling, kicks, boosts) | Run, Idle, Dash, GroundPound, WallSlide |
| `Dash` | Idle, Run, Air, GroundPound, PoundLand | Run, Air |
| `GroundPound` | Air | PoundLand, Dash (fall cancel) |
| `PoundLand` | GroundPound | Air (jump/boost), Idle (expiry) |
| `WallSlide` | Air | Air (kick/release), Run |
| `Slide` | Run (crouch held), LongJump (landing) | Run, Idle, Air, Dash, LongJump |
| `Turnaround` | Run (hard input reversal at speed) | TurnJump, Run, Idle, Air, Dash |
| `TurnJump` | Turnaround (jump during skid) | as `Air` (it extends Air) |
| `LongJump` | Run, Slide (crouch + jump at speed) | Slide (landing), Air (bonk), GroundPound |
| `LedgeGrab` | Air (lip detected ahead) | Run, Idle (mantle done), Air (jump/drop) |
| `WallRun` | Air (wall contact at tangential speed) | Air (kick/expiry), WallSlide (decay), Run |
| `SlideHop` | Slide (jump from established slide) | as `Air` (it extends Air) |
| `Backflip` | Idle, Run (jump opposing facing at standstill) | as `Air` (it extends Air) |
| `SideFlip` | Idle, Run (jump with low-speed strafe input) | as `Air` (it extends Air) |

Bunny hops intentionally never leave `Air`. The wavedash is not a state:
it lives inside `Dash`'s jump-out handling.

## Debug visualization

Rebuilt every frame from an `ImmediateMesh` (no depth test, visible through
geometry), toggled with **F3** together with the text overlay:

- **Green** — actual velocity, line length scaled to magnitude.
- **Cyan** — desired velocity (input intent), same scale. The gap between
  green and cyan is your momentum vs. what you're asking for.
- **Yellow** — character facing (fixed length).
- **Magenta** — camera look direction (fixed length).

Overlay: current state, horizontal/vertical speed, hop chain, triple-jump
chain (n/3), air-dash availability, per-tech availability indicators
(long jump / turn jump / slide hop), FPS.

Beyond the vectors, gameplay feedback (always on): FOV kicks out and the
camera leans into hard turns as speed builds (`OrbitCamera` "Speed
Feedback" exports), landings squash the character proportionally to fall
speed (stepped on twos, like the placeholder animations), skids kick dust
in the old velocity direction, and pound impacts spawn an expanding
shockwave ring. FX listen to player signals (`skid_started`, `landed`,
state changes) via the `PlayerFX` node — states stay pure logic.

## Demo scene tours

Both demo scenes route the full movement kit through dressed environments;
the full tours (and every render-pipeline detail) live in
[PIXEL_ART_PIPELINE.md](PIXEL_ART_PIPELINE.md). Short version:

**Outdoor fantasy (`scenes/demo_outdoor/`)** — boot scene. Ledge-grab
terraces up to a ruin plateau; a wall-kick chimney tower with a pound pad
and a 16 m pound-dash gap to a floating island; a 20° runway into a
stepping-stone bunny-hop chain across a river; a gorge wall-run crossing
with a recovery bounce pad on the gorge floor.

**Castle interior (`scenes/demo_castle/`)** — stairs to a broken balcony
crossed by a 12 m wall-run; pound pad → dash-convert (or long jump) across
the great hall to the east-ledge goal, with a moving-platform lift and
table → column-capital ledge grabs as slower routes; an actual fireplace
chimney to wall-kick up onto the roof; a long-jump-friendly hall aisle —
all lit by flickering torch point lights.

## Test level tour (`scenes/test_level.tscn`)

- **Plaza** (grey) — spawn, flat ground.
- **North: slope bank** (orange) — 15°, 30°, 44° walkable ramps with landing
  pads at different heights, plus a red 55° ramp that is deliberately
  unwalkable (sheds you).
- **East: downhill runway** (orange) — long 18° descent for building slope
  speed, flowing into the **green bunny-hop platforms** with widening gaps;
  keep the chain alive to clear the last ones.
- **West: wall-kick chimney and pound tower** (blue) — a 2 m slot between
  the tower and a free wall; chain wall kicks to reach the tower top. The
  red pad up top marks the **ground-pound spot**: pound, then dash-convert
  to boost across the 17 m gap to the purple platform (a plain jump falls
  well short; the boost clears it with room to spare).
- **South: practice wall** (blue) — single wall for slide/kick basics.

## Test level 2 tour (`scenes/test_level_2.tscn`)

A larger traversal greybox. Press **F5** in-game to cycle between test
levels (the compact per-tech check zone above stays as level 1).

- **Hub plaza** (grey) — spawn, flat ground, routes lead out in all four
  directions.
- **South: 25° mega-runway** (orange) — a much bigger decline than level
  1's 18° runway; build slope speed all the way down to the lower field
  (a speed booster there tops you back up between attempts).
- **South-far: wide-gap bunny-hop gauntlet** (green) — gaps grow from 6 m
  to 12 m; you need the runway's slope speed plus a live hop chain to
  clear the far ones.
- **East of the lower field: long-jump alley** (green → purple) — flat,
  same-height platforms with 6–12 m gaps: land in the slide, buffer the
  next jump, chain long jumps to the purple pad. Also bhoppable at very
  high speed, for comparing the two techs.
- **North: tower stack** (sage) — cubes rising 2.2 m → 13.4 m with 2–4 m
  horizontal gaps: the first riser is a plain jump, everything above wants
  ledge grabs, turn jumps or a long jump across the wider gaps. Purple
  summit platform on top. Vertical counterpart to level 1's wall-kick
  chimney, no walls to kick.
- **East: pad gauntlet** (yellow pads / cyan boosters) — booster strip
  into a vertical bounce pad onto a raised platform, then an angled pad
  that throws you a full platform-gap forward, then another booster into a
  final gap. Tests pads and boosters in a large-scale traversal chain, and
  the pound-onto-pad amplified bounce.
- **West: wall-run crossing** (blue) — a 40 m wall over a void: hit it
  fast (dash off the plaza) and run it, kicking off to the far landing.
  Alternatively ride the two counter-phased **moving platforms** across
  and feel jump-off momentum inheritance.

## Placeholder stop-motion animation

`StopMotionAnimator` generates an animation library at runtime: stepped keys
"on twos" at 24 fps with `INTERPOLATION_NEAREST` — choppy, no easing — keyed
on the mesh pivot (squash-and-stretch per state, slam flattening, run bob).
To slot in real art later, author animations with the same snake_case names
(`idle`, `run`, `air`, `dash`, `ground_pound`, `pound_land`, `wall_slide`,
`slide`, `turnaround`, `turn_jump`, `long_jump`, `ledge_grab`, `wall_run`,
`slide_hop`, `backflip`, `side_flip`) on the player's `AnimationPlayer`;
existing names are never overwritten by the generator. Landing squash is
applied on the `Visual/Squash` node — the *parent* of the animated pivot —
so impact weight stacks with the keyed poses instead of fighting them.
The character visual is a ball-with-feet (sphere body, ellipsoid feet,
oval eyes, cheeks) built from primitive meshes under the same pivot, so
every generated animation and the landing squash apply to it unchanged;
the collision capsule is untouched. All meshes use the shared toon
material library (`pixel_art_pipeline/materials/`) — the stepped-shading
pass described in PIXEL_ART_PIPELINE.md.

## Project structure

```
scenes/
  main.tscn          entry point: pixel pipeline + level + player + camera
					 + overlay + switcher (world lives in a SubViewport)
  player.tscn        character body, ball-with-feet visuals, states,
					 animator, FX, debug draw
  test_level.tscn    CSG greybox level 1: compact per-tech check zones
  test_level_2.tscn  CSG greybox level 2: large-scale traversal zones
  demo_outdoor/      dressed outdoor demo scene + tree/rock/stone kit
  demo_castle/       dressed castle demo scene + kit/ (wall, arch, column,
					 tile, stairs, torch, banner, chandelier)
  objects/           reusable level objects (instance freely)
	bounce_pad.tscn, speed_booster.tscn, moving_platform.tscn
pixel_art_pipeline/  render pipeline: pipeline + texel-snap scripts,
					 post/toon shaders, shared toon material library
src/
  player/
	player.gd            shared data + physics helpers (CharacterBody3D)
	movement_stats.gd    all tuning values (Resource — swap per character),
						 grouped per tech family in the inspector
	stop_motion_animator.gd  placeholder animations + landing squash
	states/              one node + script per move; jump variants extend
						 AirState (air_state.gd)
  level/               level-side scripts: bounce_pad.gd, speed_booster.gd,
					   moving_platform.gd, level_switcher.gd,
					   torch_flicker.gd
  fx/                  player_fx.gd (signal-driven skid dust / pound ring),
					   shockwave_ring.gd
  camera/orbit_camera.gd   orbit + speed-reactive FOV / turn lean
  debug/debug_draw.gd, debug_overlay.gd
MOVEMENT.md, PIXEL_ART_PIPELINE.md
```

Extension points: add a state = add one node under `StateMachine` with a
`PlayerState` script (extend `AirState` if it flies like a jump); retune
the kit = edit the `MovementStats` resource on the player (or save
variants as `.tres`); retune one placed pad/booster = per-instance exports
on the object; replace placeholder animation = author named animations;
new level = add its `PackedScene` to `LevelSwitcher.levels` in
`main.tscn`.

## Backlog (deliberately not built yet)

- **Midair jump** (gated double jump) — future task.
- **Dive / belly-slide** — future task.
- Aimed/diagonal air dash, grapple/swing point, rail grind — considered,
  out of scope for now.
