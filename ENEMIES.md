# Enemies — slow, calculated encounters

Five encounter designs in the OoT lineage, tuned for this movement game:
**every fight is a positioning/timing puzzle, never a DPS race.** Each enemy
has one readable rhythm, one deliberate opening, and a movement-kit answer
(dash behind, sidehop the line, count the beat, return the volley). All of
them engage when you enter their range with line of sight and **break off
back to patrol when you leave** — fights are opt-in and escapable.

They all live in the **combat arena** (`scenes/test_level_3.tscn`, last
stop in the F5 rotation): one colored zone per enemy around a central
plaza, plus Z-target practice dummies and a wall for line-of-sight breaks.

## Shared framework

`EnemyBase` (CharacterBody3D) owns health, the shared hit contract
(`hittable` group + `take_hit(hit)`), Z-target support (`targetable` group,
`target_point()`, `is_targetable()`), and movement helpers. Behavior lives
in an `EnemyStateMachine` with one node per state (`src/enemies/states/`) —
the same composition pattern as the player's state machine, and completely
independent of it: enemies only touch the player through
`Player.apply_knockback()` (there is no player health yet, attacks shove).
`enemy_patrol_state.gd` is shared by the walkers; everything else is
enemy-specific. The volley tower is stationary and phase-driven, so it
keeps a small internal enum instead of hosting a machine — its interesting
state rides on the orb.

## The five encounters

**Shield Brute** (`shield_brute.tscn`) — big, slow, front is a wall.
Swings clank off the shield (directional block, ~front 100°); his only
hurtbox is behind. States: Patrol → Engage (plods at you) → Attack in three
beats: **Raise** (0.9 s telegraph — he plants and lifts the shield: your
window to dash past and get behind), **Slam** (shockwave + shove in the
front cone), **Recover** (1.4 s, shield down — his front is briefly
honest). Two counters to one attack: flank during the raise, or punish the
face after the slam. 5 HP, only reachable from behind except during
recovery.

**Poker** (`poker.tscn`) — the Lizalfos. He owns the distance: backpedals
when you close, approaches when you drift, strafes in his comfort band
(~4.5 m), always facing you. On his own timer he commits: **dart in →
windup flash → stab → overextend** — a 1.1 s frozen recovery with the spear
buried, which is the entire opening. Chasing him is wrong; baiting the poke
and spending his recovery is right. 3 HP.

**Flyer** (`flyer.tscn`) — the Keese. Circles ~4.5 m up, above the staff's
reach: you cannot start this fight. When you've been in range long enough
it telegraphs (hover dip), then **swoops through where you were standing** —
no tracking. While it's low it can be hit (Z-target it and meet it with a
lunge, or sidestep and swing); miss it and it climbs away for another pass.
2 HP.

**Bouncer** (`bouncer.tscn`) — the Tektite. Sits motionless, turns slowly
to face you (the OoT tell), then chases as one rhythm: **crouch
(squash telegraph) → ballistic leap at you → landing pause**. Dangerous
exactly when airborne, hittable exactly when grounded — the fight is
counting its beat. 3 HP.

**Volley Spire** (`volley_tower.tscn`) — mini dead man's volley. In range,
an orb charges above the spire (1.4 s wind-up), then fires at where you're
standing. **Your normal swing is the racket**: connect as the orb arrives
and it flies back. The tower returns the volley 50/50 — faster every
rebound, and the orb swaps color per owner (gold from the tower, blue off
your staff), like Phantom Ganon's. Only one orb is ever in play, direct
staff hits clank off, and three failed returns kill it. 3 volley hits.

## Design rules (for future enemies)

1. **One rhythm per enemy**, fully readable before it's dangerous
   (raise → slam; crouch → leap; dip → swoop).
2. **The opening is authored**, not incidental — overextend, recovery,
   grounded pause. Long enough to walk into deliberately.
3. **The counter is a movement verb** — dash behind, sidehop the line,
   lunge the swoop, time the swing. Never "trade hits faster."
4. **Escapable** — disengage ranges return everything to patrol.
5. States are nodes; add an enemy = `EnemyBase` scene + two or three
   `EnemyState` scripts. Keep telegraphs on twos and knockback instead of
   damage until player health exists.
