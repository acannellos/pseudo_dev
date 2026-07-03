# dev_pseudo — movement-tech prototype

A Godot 4.7 third-person movement-platformer prototype in the lineage of
Mario 64 / Pseudoregalia / The Big Catch. Momentum is the design pillar:
every move preserves, redirects, or converts speed — nothing resets it.

Open the project and press Play (`scenes/main.tscn` is the main scene).
Fall off the world and you respawn at the start.

## Controls

| Action | Keyboard / mouse | Gamepad |
| --- | --- | --- |
| Move | WASD | Left stick |
| Camera | Mouse | Right stick |
| Jump | Space | A (bottom) |
| Dash | Shift | X / Right shoulder |
| Ground pound | C or Ctrl | B / Left shoulder |
| Toggle debug view | F3 | — |
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

## State machine

`StateMachine` node under the player hosts one node per state
(`src/player/states/`). States are found by node name; each state drives
velocity, calls `move_and_slide()`, and requests transitions.

| State | Entered from | Exits to |
| --- | --- | --- |
| `Idle` | Run, PoundLand, landing | Run, Air, Dash |
| `Run` | Idle, Air, Dash | Idle, Air, Dash |
| `Air` | any (jump, falling, kicks, boosts) | Run, Idle, Dash, GroundPound, WallSlide |
| `Dash` | Idle, Run, Air, GroundPound, PoundLand | Run, Air |
| `GroundPound` | Air | PoundLand, Dash (fall cancel) |
| `PoundLand` | GroundPound | Air (jump/boost), Idle (expiry) |
| `WallSlide` | Air | Air (kick/release), Run |

Bunny hops intentionally never leave `Air`.

## Debug visualization

Rebuilt every frame from an `ImmediateMesh` (no depth test, visible through
geometry), toggled with **F3** together with the text overlay:

- **Green** — actual velocity, line length scaled to magnitude.
- **Cyan** — desired velocity (input intent), same scale. The gap between
  green and cyan is your momentum vs. what you're asking for.
- **Yellow** — character facing (fixed length).
- **Magenta** — camera look direction (fixed length).

Overlay: current state, horizontal/vertical speed, hop chain, air-dash
availability, FPS.

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

## Placeholder stop-motion animation

`StopMotionAnimator` generates an animation library at runtime: stepped keys
"on twos" at 24 fps with `INTERPOLATION_NEAREST` — choppy, no easing — keyed
on the mesh pivot (squash-and-stretch per state, slam flattening, run bob).
To slot in real art later, author animations with the same snake_case names
(`idle`, `run`, `air`, `dash`, `ground_pound`, `pound_land`, `wall_slide`)
on the player's `AnimationPlayer`; existing names are never overwritten by
the generator. Meshes are low-poly primitives and materials are plain
`StandardMaterial3D` albedo colours, so a toon/gooch shading pass can be
applied later without restructuring.

## Project structure

```
scenes/
  main.tscn          entry point: level + player + camera + debug overlay
  player.tscn        character body, visuals, states, animator, debug draw
  test_level.tscn    CSG greybox level
src/
  player/
	player.gd            shared data + physics helpers (CharacterBody3D)
	movement_stats.gd    all tuning values (Resource — swap per character)
	stop_motion_animator.gd
	states/              one node + script per move
  camera/orbit_camera.gd
  debug/debug_draw.gd, debug_overlay.gd
MOVEMENT.md
```

Extension points: add a state = add one node under `StateMachine` with a
`PlayerState` script; retune the kit = edit the `MovementStats` resource on
the player (or save variants as `.tres`); replace placeholder animation =
author named animations; real level = replace `test_level.tscn` instance in
`main.tscn`.
