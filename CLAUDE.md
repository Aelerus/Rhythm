# Rhythm — Claude Session Context & Rules

## What This File Is
Paste this at the start of any new session. It is the single source of truth for the project's design decisions, technical rules, and coding standards. It prevents repeated mistakes and keeps Claude aligned without re-explaining everything.

---

## Project Overview

A bullet-hell rhythm game originally written in JavaScript, currently being ported to **Godot 4 / GDScript**. The player dodges bullets, then counterattacks during rhythm-gated windows. The game is data-driven and parametric — no hand-authored beat timelines.

**Engine:** Godot 4.x, GDScript, GL Compatibility renderer
**Canvas:** 1280×720 (16:9). Set in Project Settings → Display → Window. Stretch Mode: `canvas_items`, Aspect: `keep`.
**Arena:** `Rect2(160, 60, 960, 600)` — 160px side borders reserved for future world decorations.

---

## File Map

| File | Role |
|---|---|
| `godot/game/BeatClock.gd` | Timing backbone. `get_current_time()` = elapsed seconds since `start()`. `beat_time(n)` = `n * beat_interval` (elapsed, NOT absolute). |
| `godot/game/FightManager.gd` | Fight state machine. Phases, timeline, bullet damage, inversion, music. |
| `godot/game/Player.gd` | Player state. base_speed=322, focus_speed=149.5. |
| `godot/game/BossController.gd` | Boss state, HP, phase thresholds, fall-on-death. |
| `godot/game/CounterWindow.gd` | Parry/counterattack window. PERFECT_WINDOW=0.05s, GOOD_WINDOW=0.12s. |
| `godot/game/BulletPool.gd` | Bullet lifecycle. `active: Array[Bullet]` (typed). |
| `godot/game/PatternEngine.gd` | Fires bullet patterns from JSON data. |
| `godot/game/AuxAttacks.gd` | TetherAttack, GravityWell, RealityTear auxiliary mechanics. |
| `godot/game/WavLoader.gd` | Loads PCM WAV from filesystem. FORMAT: `1`=16bit, `0`=8bit (no enum). |
| `godot/renderer/CanvasBackground.gd` | Draws world background, arena frame, crack veins. W=1280, H=720. |
| `godot/renderer/BossRenderer.gd` | Draws boss hexagon. `draw_colored_polygon` takes single Color. |
| `godot/renderer/BulletRenderer.gd` | Draws all active bullets. |
| `godot/renderer/PlayerRenderer.gd` | Draws player arrow. |
| `godot/renderer/HUDRenderer.gd` | Boss bar, song timer, player HP, combo, parry prompts, grade flash. CANVAS_W=1280. |
| `godot/screens/FightGame.gd` | Top-level fight screen. Owns intro sequence, pause, renderers. CANVAS_W=1280, ARENA constant. |
| `godot/screens/BossSelect.gd` | Boss selection screen. CANVAS_W=1280. |
| `godot/screens/VictoryScreen.gd` | Post-fight victory. CANVAS_W=1280. |
| `godot/screens/GameOver.gd` | Game over screen. CANVAS_W=1280. |
| `godot/game/InputManager.gd` | Input abstraction. |
| `godot/game/AudioManager.gd` | Music playback, fade. |
| `godot/Main.gd` | Scene root, screen router. |

---

## GDScript 4 Rules — Common Mistakes to Avoid

These caused repeated parser errors in this project. Apply all of them proactively when writing or editing GDScript.

### 1. Never use `:=` with Variant-returning expressions
`:=` infers the type from the RHS. If the RHS returns Variant, Godot throws `INFERENCE_FROM_VARIANT`. Always use explicit type annotation instead.

```gdscript
# WRONG
var x := dict.get("key", 0)
var y := some_array[i]

# RIGHT
var x: int = dict.get("key", 0)
var y: MyType = some_array[i]
```

### 2. Use typed math built-ins — never `min`, `max`, `clamp`, `abs`, `sign` with `:=`
These are polymorphic and return Variant. Use the float-specific versions:

| Avoid | Use instead |
|---|---|
| `min(a, b)` | `minf(a, b)` |
| `max(a, b)` | `maxf(a, b)` |
| `clamp(a, lo, hi)` | `clampf(a, lo, hi)` |
| `abs(a)` | `absf(a)` |
| `min(a, b)` on ints | `mini(a, b)` |

### 3. `draw_colored_polygon` takes a single Color, not PackedColorArray
Godot 4 API change from Godot 3:
```gdscript
# WRONG (Godot 3)
canvas.draw_colored_polygon(pts, PackedColorArray([col, col, col]))

# RIGHT (Godot 4)
canvas.draw_colored_polygon(pts, col)
```

### 4. Lambda captures are by value — use Array for mutable state
```gdscript
# WRONG — reassignment inside lambda does nothing to outer var
var rng := seed_val
var fn := func(): rng = (rng * 9301 + 49297) % 233280

# RIGHT — array is a reference type, mutations persist
var rng_state := [seed_val]
var fn := func():
    rng_state[0] = (rng_state[0] * 9301 + 49297) % 233280
```

### 5. Never name local variables after GDScript built-ins
`var len`, `var seed`, `var min`, `var max` etc. all trigger `SHADOWED_GLOBAL_IDENTIFIER` (treated as error). Rename: `len` → `dist`, `seed` → `rng_seed`.

### 6. Ternary with incompatible branch types fails
```gdscript
# WRONG — Dictionary vs null is incompatible
var x = {"key": val} if condition else null

# RIGHT — use if/else
var x = null
if condition:
    x = {"key": val}
```

### 7. Integer division warning
```gdscript
# WRONG — warns if using :=
var mm := int(remaining) / 60

# RIGHT — explicit type
var mm: int = int(remaining) / 60
```

### 8. Callable.call() returns Variant — always wrap in float()
```gdscript
var result: float = float(my_callable.call())
```

### 9. Unused variables and parameters are errors
Prefix unused params with `_`. Remove unused class vars entirely.

### 10. `beat_time(n)` returns elapsed time, not absolute
`BeatClock.beat_time(n)` correctly returns `n * beat_interval`. Do not change this to include `_start_usec` — that was a bug that broke all parry timing.

### 11. `AudioStreamWAV.FORMAT_16_BIT` enum does not exist in this build
Use integer literals: `1` = 16-bit, `0` = 8-bit.

---

## Coding Standards

- **No comments** unless the WHY is non-obvious (hidden constraint, workaround, subtle invariant).
- **No extra abstractions.** Don't create helpers for one-off use. Three similar lines beats a premature abstraction.
- **No error handling for impossible cases.** Trust internal guarantees. Only validate at system boundaries.
- **When asked to check for issues — scan the ENTIRE file**, not just the reported line. Report all issues at once and fix all at once.
- **Explicit types everywhere** in GDScript — never rely on inference from Variant sources.
- **No backwards-compat shims.** If something is unused, delete it.

---

## Game Design — Single Source of Truth

### Structure
- **6 outer worlds** on a hexagon main map, each with a unique mechanic
- **Each world:** 6 progressive fights (slot 1 = intro, slot 6 = hardest pre-boss) + 1 boss fight (center of world hexagon) = 7 fights per world
- **World navigation:** fixed starting point per world, travel one hex point at a time (direction varies per world), center last
- **The Eye (main map center):** harder remixed versions of all 6 world bosses — mastery test, no new mechanics
- **APEX:** secret boss, orchestral, already in codebase. Unlocked at **144 total points** across all 48 fights

### Scoring
| Grade | Points |
|---|---|
| C | 1 |
| B | 2 |
| A | 3 |
| S | 5 |

- **Max:** 240 points (48 fights × S)
- **APEX unlock:** 144 points (= exactly A-average across all 48 fights, 3×48)
- **World boss unlock:** ~12–14 points from 6 fights (threshold TBD per world, bare C passes not enough)

### The 6 Worlds
| World | Genre | Color | Mechanic |
|---|---|---|---|
| 1 | Techno | Cyan | **Subwoofer Barrage** — large indestructible subwoofers line the border ring and fire bullets in straight lines into the arena on beat. Background: subwoofer wall, bass-pulse visual rings. Safe lanes exist between firing angles. |
| 2 | Metal | Deep Red | **Spotlight Lock** — counter window circle moves like a concert spotlight (boss-driven path). Player must be ON it when they parry. Background: moshpit crowd silhouettes, stage lighting. |
| 3 | Drum and Bass | Orange | **Beat Pulse** — bullets grow in size (hitbox grows with visual) on heavy drum hits and bass strums, synced to the music. Pattern is consistent per song — first attempts are rough, repeated runs become readable as players learn the song structure. |
| 4 | Synthwave | Dark Space Blue | **Grid Lock** — 6 horizontal and 4 vertical faded lines span the arena. Lines light up magenta and become impassable walls for the player (bullets pass through freely). No walls activate near the boss. Creates shifting area control corridors. Background TBD. |
| 5 | Reggaeton | Yellow | TBD |
| 6 | Jazz | Warm Amber | TBD |


### World 4 — Synthwave Fight Roster
| Slot | Fight Name | Song |
|---|---|---|
| 1 | Cruise Control | Open Highway |
| 2–7 | TBD | TBD |

### Visual Identity
- **Arena floor:** world color
- **Arena border ring (160px each side):** genre-specific decoration (e.g. subwoofers for Techno). Mechanically interactive in some worlds.
- **Outer edge:** stays black
- **Boss bar fill:** `boss_col.lightened(0.35)` — always readable regardless of world color
- **Background:** world/boss color tints entire canvas at 12% alpha, inner circle gradient at 62% canvas width

### Fight UI — What's In / What's Out
| Element | Status | Notes |
|---|---|---|
| Boss HP bar | IN | Lightened boss color fill, pulsing phase notches |
| Song timer bar + countdown | IN | Below boss HP bar |
| Player HP bar | IN | Bottom left |
| Beat indicator | IN | Bottom center circle |
| Combo display | IN | Top right. Shows multiplier value (x1.25 not x4). Bar shows progress to ×2.0 max |
| Grade flash (PERFECT/GOOD/MISS) | IN | Center screen |
| Phase feedback text | IN | Center screen |
| Boss name during fight | REMOVED | Shown only in intro flash |
| Controls hint | REMOVED | Tutorial levels will teach instead |
| Damage multiplier text | REMOVED | Tutorial will explain |

### Intro Sequence
On fight enter: boss name flashes in boss color (fade in 0.4s → hold 1.4s → fade out 1.2s) over a dimmed arena. Music and fight start when fade completes. Player can press Space/Enter to skip.

### Tutorial Philosophy
- Tutorial levels teach mechanics by doing — no in-fight text explanations
- "Move to the circle" hint is a toggle in settings (on by default, off for experienced players)
- Controls hint removed from HUD — tutorial covers it

### Council Format
When asked to evaluate ideas, use four voices:
- **Stranger** — never played a bullet hell, surface reactions only
- **Bias** — finds the upside in everything
- **Negative** — assumes the worst, calls out real problems
- **Speaker** — strips bias from all three, synthesizes into actionable ruling

---

## What NOT to Port from APEX to New Worlds
- Hand-authored beat timelines (too expensive)
- Per-boss bespoke soundtracks (music is user jukebox)
- 70+ pattern files per boss (use ~5 parametric mechanics instead)
- Floor-collision inversion (ArenaFloor is display-only)
- Three readability-taxing systems simultaneously
