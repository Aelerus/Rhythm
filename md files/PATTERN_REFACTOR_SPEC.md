# Pattern System Refactor Spec

Paste this file back into Claude Code when implementing the pattern scalability changes.

---

## Goal

Eliminate the explosion of near-identical JSON files in `data/patterns/` by allowing boss timelines to define patterns **inline** (with full parameters) instead of always referencing a separate file. Existing pattern files and all current boss files remain valid — this is purely additive.

---

## Current Architecture (do not break this)

### Data flow
1. `main.js` loads all files under `data/patterns/*.json` and builds a `patternLibrary` map (`id → pattern object`).
2. `main.js` passes `patternLibrary` into `FightManager` → `PatternEngine`.
3. Boss timeline entries look like: `{ "beat": 32, "type": "pattern", "id": "apex_burst" }`
4. `FightManager._onBeat()` fires `patternEngine.fire(id, ctx)` when the beat matches.
5. `PatternEngine.fire(id, ctx)` looks up `this.library[id]`, then dispatches to the right `_method(pattern, ctx)` based on `pattern.type`.

### Key files
| File | Role |
|---|---|
| `src/game/PatternEngine.js` | All bullet-spawn logic. 20+ `_method(p, ctx)` handlers. |
| `src/game/FightManager.js` | Beat clock, timeline scheduling, multi-phase state. |
| `src/main.js` | Loads data, builds `patternLibrary`, wires everything together. |
| `data/patterns/*.json` | ~80 files, each one a flat parameter object with an `"id"` and `"type"`. |
| `data/bosses/*.json` | Boss definitions. May have top-level `timeline` (legacy) or `phases[].timeline` (multi-phase). |

### Pattern file shape (current)
```json
{
  "id": "apex_burst_chaos",
  "type": "arena_burst",
  "sites": 7,
  "arms": 8,
  "speed": 270,
  "telegraph": 0.38,
  "radius": 6,
  "color": "#ffffff"
}
```

### Timeline event shape (current)
```json
{ "beat": 64, "type": "pattern", "id": "apex_burst_chaos" }
```

---

## Proposed Change: Inline Pattern Data

Add a second form of timeline pattern event that carries its parameters directly:

```json
{
  "beat": 64,
  "type": "pattern",
  "patternData": {
    "type": "arena_burst",
    "sites": 7,
    "arms": 8,
    "speed": 270,
    "telegraph": 0.38,
    "radius": 6,
    "color": "#ffffff"
  }
}
```

When `patternData` is present, skip the library lookup entirely and fire directly with that object.

---

## Exact Code Changes Required

### 1. `PatternEngine.fire()` — accept a raw pattern object as an alternative

**Current signature:**
```js
fire(patternId, ctx) {
  const pattern = this.library[patternId];
  if (!pattern) { console.warn(...); return; }
  switch (pattern.type) { ... }
}
```

**New signature:**
```js
fire(patternIdOrData, ctx) {
  const pattern = typeof patternIdOrData === "string"
    ? this.library[patternIdOrData]
    : patternIdOrData;
  if (!pattern) { console.warn(`PatternEngine: unknown pattern '${patternIdOrData}'`); return; }
  switch (pattern.type) { ... }
}
```

No other changes to `PatternEngine` — all `_method(p, ctx)` handlers stay identical.

### 2. `FightManager._onBeat()` — pass inline data when present

Find the section that dispatches pattern events. It currently does something like:
```js
if (evt.type === "pattern") {
  this.patternEngine.fire(evt.id, ctx);
}
```

Change to:
```js
if (evt.type === "pattern") {
  this.patternEngine.fire(evt.patternData ?? evt.id, ctx);
}
```

That single change is sufficient. `evt.patternData` (an object) takes priority; `evt.id` (a string) is the fallback for all existing boss files.

### 3. No changes to `main.js` or pattern loading

`patternLibrary` continues to be built the same way. Pattern files already on disk remain valid and referenced as before.

---

## Migration Strategy for New Bosses

When creating a new boss, skip making separate pattern files for variations. Define them inline:

**Before (required a file `data/patterns/boss07_shot_a.json`):**
```json
{ "beat": 16, "type": "pattern", "id": "boss07_shot_a" }
```
plus a separate file:
```json
{ "id": "boss07_shot_a", "type": "aimed_shot", "count": 3, "spread": 0.25, "speed": 350, "color": "#ff4400" }
```

**After (no separate file needed):**
```json
{
  "beat": 16,
  "type": "pattern",
  "patternData": { "type": "aimed_shot", "count": 3, "spread": 0.25, "speed": 350, "color": "#ff4400" }
}
```

Only create a named pattern file when the same pattern is **reused across multiple bosses** or phases.

---

## All Valid `type` Values (PatternEngine dispatch table)

These are the strings the `switch` in `PatternEngine.fire()` handles. `patternData.type` must be one of:

| type | Method | Key params |
|---|---|---|
| `radial_burst` | `_radial` | count, speed, radius, color, rotateWithBeat, rotateStep |
| `aimed_shot` | `_aimed` | count, spread, speed, radius, color |
| `spiral` | `_spiral` | count, speed, radius, color, angleStep, rotateWithBeat |
| `wall` | `_wall` | count, spacing, speed, radius, color, orient |
| `cross` | `_cross` | arms, count, speed, radius, color |
| `homing` | `_homing` | count, speed, turnRate, radius, color |
| `rain` | `_rain` | count, speed, radius, color |
| `converging` | `_converging` | count, speed, radius, color |
| `mirror_path` | `_mirrorPath` | count, speed, radius, color, telegraph |
| `arena_burst` | `_arenaBurst` | sites, arms, speed, telegraph, radius, markerRadius, color |
| `vortex` | `_vortex` | count, orbitDur, orbitRadius, omega, releaseSpeed, reverse, radius, color |
| `echo` | `_echo` | lookback, count, spread, speed, radius, color |
| `laser_line` | `_laserLine` | (see PatternEngine) |
| `stutter_aim` | `_stutterAim` | (see PatternEngine) |
| `split_wave` | `_splitWave` | (see PatternEngine) |
| `pulse_beam` | `_pulseBeam` | (see PatternEngine) |
| `tempo_grid` | `_tempoGrid` | (see PatternEngine) |
| `phase_locked_radial` | `_phaseLockedRadial` | count, speed, radius, color, lockColor, rotateWithBeat |
| `phase_locked_aimed` | `_phaseLockedAimed` | count, spread, speed, radius, color, lockColor |
| `tether` | `_tether` | duration, spawnInterval, bulletSpeed, radius, color |
| `gravity_well` | `_gravityWell` | anchor, atPlayer, x, y, duration, strength, radius, color |
| `expanding_radial` | `_expandingRadial` | count, speed, growRate, radius, color, maxLife |
| `reality_tear` | `_realityTear` | orient, x, y, angle, length, duration, spawnInterval, bulletSpeed, radius, color |

---

## Invariants to Preserve

- All existing `data/bosses/*.json` files must load and play without any change.
- All existing `data/patterns/*.json` files must remain valid (they are still loaded and referenceable by ID).
- `PatternEngine` methods are pure functions of `(p, ctx)` — adding inline dispatch does not change their behavior.
- `FightManager` multi-phase logic (phases array, legacy single-phase fallback) is unchanged.
- The `patternLibrary` map is still populated from disk; inline patterns simply bypass the lookup step.

---

## Example: Converting an Existing Boss Variation

`apex_burst.json` vs `apex_burst_chaos.json` are two files that differ in 4 numbers:

```json
// apex_burst.json
{ "id": "apex_burst", "type": "arena_burst", "sites": 4, "arms": 6, "speed": 240, "telegraph": 0.45, "radius": 7, "markerRadius": 14, "color": "#ffffff" }

// apex_burst_chaos.json  
{ "id": "apex_burst_chaos", "type": "arena_burst", "sites": 7, "arms": 8, "speed": 270, "telegraph": 0.38, "radius": 6, "markerRadius": 12, "color": "#ffffff" }
```

With inline patterns, future bosses can define these directly in the timeline without creating files. The APEX boss files themselves don't need to change — this is for new content only.
