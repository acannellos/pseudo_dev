# 3D pixel art rendering pipeline

A Shadowglass / t3ssel8r-style real-time pixel-art look, built as a stack of
independently toggleable layers on top of the existing movement demo. No
gameplay code was touched: the whole 3D game simply renders inside a low-res
SubViewport, and the pipeline decorates that.

Two dressed demo scenes show it off — `scenes/demo_outdoor/` (bright
single-directional-light stress test) and `scenes/demo_castle/` (dark
interior, many coloured point lights). **F5** cycles levels in-game:
outdoor → castle → test level 1 → test level 2.

## Live layer toggles

Every layer can be toggled from the Inspector (select `Main/PixelPipeline`)
**or live in-game on the number row** (raw keycodes; the input map is
untouched):

| Key | Layer | Default |
| --- | --- | --- |
| 1 | Pixelation (low-res SubViewport) | on |
| 2 | Camera texel snapping | on |
| 3 | Sub-texel smoothing | on |
| 4 | Depth+normal outline | on |
| 5 | Colour quantization | on |
| 6 | Ordered (Bayer) dithering | on |
| 7 | Toon/stepped lighting | on |
| 8 | Low-fps render cap (12 fps look) | off |

## Architecture

```
Main (scenes/main.tscn)
  PixelPipeline            pixel_art_pipeline/pixel_art_pipeline.gd — owns all toggles
    WorldViewport          SubViewport, fixed low internal resolution
      DemoOutdoor          the active level (LevelSwitcher swaps it here)
      LevelSwitcher / Player / CameraRig   (unchanged gameplay)
      TexelSnap            pixel_art_pipeline/texel_snap.gd
      PostQuad             full-screen quad, shaders/pixel_post.gdshader
    Screen                 TextureRect, nearest filter, scaled to the window
  DebugOverlay             stays outside the viewport → crisp native-res text
```

Nodes inside a SubViewport receive no input on their own, so `PixelPipeline`
forwards every unhandled event into the viewport with `push_input()` — this
is how the orbit camera and F5 level switcher keep working. The debug
overlay lives outside and still gets root-viewport input directly. The
SubViewport shares the root `World3D` (default `own_world_3d = false`), so
runtime-spawned FX like the pound shockwave (added under the scene root)
render inside the pipeline too.

## The layers

### 1. Low fixed-resolution render — `pixel_art_pipeline.gd`

The world renders at **384x216** (16:9, exactly 5x integer scale at the
project's default 1080p window; change `internal_resolution` on
`PixelPipeline`). The `Screen` TextureRect upscales with nearest-neighbour
filtering. Non-integer window sizes still fill the window (pixels get
slightly uneven); if you want strict integer scaling, pick a window size
that is a multiple of the internal resolution.

The viewport is actually 2 texels larger per side (`MARGIN_TEXELS`) so layer
2b below can slide the image without exposing an unrendered border.

### 2. Camera texel-grid snapping — `texel_snap.gd`  ← the anti-swim layer

**This is the correctness-critical layer.** After all camera scripts run
(late `process_priority`), the camera position is snapped onto a grid
aligned with its own right/up axes, spaced one texel apart in world units.
Geometry therefore always lands on the same texel boundaries while the
camera translates — no shimmer/crawl during dolly/track movement.

**2b. Sub-texel smoothing** (toggle 3): the snap remainder is published as
`screen_offset_texels`, and `PixelPipeline` slides the upscaled image by
exactly that fraction each frame. You get smooth apparent camera motion
while texels stay locked — snapping without it looks deliberately "steppy",
which is also a valid look; that's why it toggles separately.

Honest limitations (inherent with a perspective camera, documented rather
than hidden):

- Texel world-size is exact only at the focus distance (auto-detected from
  the SpringArm3D length, override `focus_distance` on the TexelSnap node).
  Geometry much nearer/farther than the player is stabilised approximately.
- **Rotation** cannot be grid-stabilised without an orthographic camera —
  orbiting the camera still crawls, translating doesn't. (The t3ssel8r
  video uses a fixed-angle orthographic camera; this project's playable
  third-person orbit camera rules that out.)
- The existing speed-reactive FOV kick (`OrbitCamera` "Speed Feedback")
  continuously changes texel size while accelerating, which re-introduces
  swim during FOV transitions. Set `fov_max == fov_base` on the CameraRig
  in `main.tscn` if you want maximum stability over game feel.

### 3. Depth+normal outline — `shaders/pixel_post.gdshader`

Screen-space pass on the full-screen `PostQuad` inside the low-res viewport
(so lines are exactly one *texel* wide, matching the pixel scale). Depth
silhouettes: a pixel is outlined when a neighbour is *farther* by a
threshold that grows with distance and grazing view angle — the line lands
on the near object's own silhouette and floors don't false-positive.
Normal creases (box edges, arch reveals) use a high `1 - dot(n, n')`
threshold so only strong creases draw, keeping surfaces clean and chunky.
Sky pixels are excluded via raw depth.

Tune on `Main.tscn → PostQuad → material_override`: `outline_color`,
`outline_strength`, `depth_edge_scale` (lower = more edges),
`normal_edge_threshold`.

### 4. Colour quantization + ordered dithering — same shader

Colour is converted to gamma space (so bands are perceptually even),
offset by an 8x8 Bayer matrix scaled to one quantization step, rounded to
`color_levels` per channel (default **6** → a 216-colour palette), and
converted back. Lighting falloff reads as dithered bands instead of smooth
gradients. `dither_strength` sets the Bayer amplitude; both stages toggle
independently so you can see banding without dither and vice versa.

The quad's material has `render_priority = -10`, so alpha-blended FX (the
pound shockwave ring) draw *after* the crush — they stay visible, still
pixelated by the upscale, just not palette-crushed. Opaque FX (skid dust)
go through the full pipeline.

### 5. Toon/stepped lighting — `shaders/toon.gdshader` + `materials/`

Every material in the project is now a `ShaderMaterial` on `toon.gdshader`
(shared library in `pixel_art_pipeline/materials/toon_*.tres` — one flat
colour each, plus emissive variants for flames/pads). A custom `light()`
quantizes `N·L × attenuation` into `band_count` bands (default 3) with a
`rim_size`/`rim_strength` view-edge highlight band on the lit side. Since
omni attenuation is folded in *before* banding, torch light pools render as
stepped concentric rings, which the dither then breaks up — exactly the
castle stress test.

The toggle is the `pixel_toon_enabled` **global shader uniform** (declared
in `project.godot [shader_globals]`, driven by `PixelPipeline`), which
cross-fades every material to plain smooth lambert at once — no material
swapping. Per-material tuning: `band_count`, `band_softness`, `rim_*`,
`emission_energy` on each `.tres`.

### 6. Low-fps render cap (optional, default off)

`PixelPipeline` sets the SubViewport to `UPDATE_DISABLED` and manually
requests `UPDATE_ONCE` at `low_fps` Hz (default 12). Game logic, physics
and input keep running at full rate — only the *rendered* world steps like
stop-motion, matching the animator's on-twos aesthetic. Sub-texel
smoothing pauses while capped (offsetting a frozen frame would slide it).

## Demo scene 1 — outdoor fantasy (`scenes/demo_outdoor/`)

Kit pieces: `pine_tree.tscn`, `rock.tscn`, `standing_stone.tscn` (all
faceted CSG primitives, `smooth_faces` off for the low-poly toon read).

- **Meadow + dirt path** at spawn, rolling half-buried sphere hills,
  scattered trees/rocks for the outline shader to chew on.
- **North: terraced cliff** — two 2.8 m stone terraces (ledge-grab
  staircase) up to a plateau with the **ruin**: standing-stone circle
  (one fallen), intact arch, broken pillar with fallen lintel.
- **Plateau: chimney tower** — 2 m slot between tower and free wall
  (wall-kick chimney, same spec as test level 1), red **pound pad** on
  top, ~16 m gap to the floating purple island: pound → dash-convert
  clears it, a plain jump does not.
- **South: dirt runway** (20°) down to the river — build slope speed into
  the **stepping-stone bunny-hop chain** (gaps 2 → 5 → 7 → 9 → 11 m)
  across the water to the far-bank goal. Boosters on both banks.
- **West: gorge wall-run** — dash off the launch pad and run the 28 m
  cliff fin over the gorge to the west rim goal; the bounce pad on the
  gorge floor (launch 32) recovers a fall, and pounding onto it amplifies.

## Demo scene 2 — castle interior (`scenes/demo_castle/`)

Modular kit first (`scenes/demo_castle/kit/`): `wall_segment` (6x8 m,
plinth+cornice trim), `arch_doorway` (CSG-subtracted round arch),
`column`, `floor_tile`, `stair_flight` (visible steps + hidden walkable
ramp collider — the capsule can't step 0.55 m risers), `torch` (flame +
flickering OmniLight, `src/level/torch_flicker.gd`), `banner` (notched
pennant — silhouette piece), `chandelier` (torus + candles + shadowed
flickering light).

Assembled: **great hall** (16x36 m, checkerboard aisle, column rows,
beams, banners, two chandeliers, throne dais) → east arch → **corridor** →
**side room** with crates and a working **fireplace**.

Movement tech routes:

- **Stairs → west balcony**, broken in the middle: **wall-run** the 12 m
  gap along the west wall between the two balcony halves.
- **Pound pad** on the north balcony → pound + dash-convert (or long jump)
  across the 10 m hall to the east ledge goal. The **moving-platform
  lift** and column-capital **ledge grabs** (table → capital → ledge) are
  alternate routes up.
- **Fireplace chimney**: hop into the firebox and **wall-kick** up the
  2 m shaft (lit by the fire below), exiting through the roof next to the
  rooftop goal pad. Thematically, finally, an actual chimney.
- The hall's long aisle chains **long jumps**; ten flickering torches +
  two chandeliers + the fireplace stress-test banded coloured point-light
  falloff + dither indoors.

## Judgment calls / deviations

- **Internal resolution 384x216** over 320x180: keeps the third-person
  camera readable at gameplay distances; exactly 5x at 1080p.
- **"Palette size" = quantization levels per RGB channel** (default 6),
  not a fixed hand-authored palette — scene-agnostic and one knob.
- **Outline + crush share one shader pass**: chained full-screen passes
  can't see each other's output inside a single 3D transparent pass
  (screen texture is captured once), so the stages live in one shader
  with independent uniform toggles. Functionally identical to separate
  layers, and cheaper.
- **Input forwarding** via `push_input`: chosen over SubViewportContainer
  because the container's stretch mode fights fixed-resolution rendering
  and the sub-texel offset trick needs manual placement anyway.
- **Per-level Sun/WorldEnvironment**: lighting moved out of `main.tscn`
  into each level scene so the castle can be night-dark while the meadow
  is noon-bright. Both test levels received a copy of the old main-scene
  sun/sky; their materials were also swapped to the shared toon library
  (same colours), so toggle 7 affects them too.
- **Player visual**: rebuilt as a ball-with-feet (sphere body, ellipsoid
  feet, oval eyes, cheeks) on the same `Visual/Squash/Pivot` rig — all
  stop-motion animations and landing squash apply unchanged. The collision
  capsule is untouched (gameplay-identical); the visual ball is smaller
  than the capsule, which is normal for greybox.

## Files

```
pixel_art_pipeline/
  pixel_art_pipeline.gd      layer owner: toggles, presentation, input forwarding
  texel_snap.gd              camera grid snapping + sub-texel remainder
  shaders/pixel_post.gdshader  outline + dither + quantize (post quad)
  shaders/toon.gdshader        stepped-lighting material shader
  materials/toon_*.tres        shared flat-colour toon material library
scenes/main.tscn             pipeline wiring (see Architecture above)
scenes/demo_outdoor/         outdoor demo + tree/rock/stone kit
scenes/demo_castle/          castle demo + kit/ (wall, arch, column, tile,
                             stairs, torch, banner, chandelier)
src/level/torch_flicker.gd   OmniLight flicker (stepped on twos)
project.godot                [shader_globals] pixel_toon_enabled
```
