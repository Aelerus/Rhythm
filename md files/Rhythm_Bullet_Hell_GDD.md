# Rhythm Bullet Hell — Game Design Document (GDD)

> **Version:** 0.1 — Initial Design Draft  
> **Target Platform (Phase 1):** HTML5 (Browser)  
> **Target Platform (Phase 2):** Godot Engine  
> **Status:** Pre-Production

---

## Table of Contents

1. [Game Overview](#1-game-overview)
2. [Core Pillars](#2-core-pillars)
3. [Gameplay Loop](#3-gameplay-loop)
4. [Player](#4-player)
5. [Combat Systems](#5-combat-systems)
6. [Boss Design](#6-boss-design)
7. [Music & Beat System](#7-music--beat-system)
8. [UI & UX](#8-ui--ux)
9. [Visual Style](#9-visual-style)
10. [Stage Structure](#10-stage-structure)
11. [Scoring & Grading](#11-scoring--grading)
12. [File Structure & Scalability](#12-file-structure--scalability)
13. [HTML Prototype Scope](#13-html-prototype-scope)
14. [Godot Migration Notes](#14-godot-migration-notes)
15. [Open Questions & Future Features](#15-open-questions--future-features)

---

## 1. Game Overview

**Title (Working):** Rhythm Bullet Hell *(TBD)*

**Genre:** Rhythm Game + Bullet Hell Boss Fighter

**Elevator Pitch:**  
A stage-based arcade game where players dodge waves of enemy attacks that sync exactly to the beat of the music, then retaliate during counterattack windows by pressing attacks on precise beat timing. Think *Just Beats & Shapes* meets a traditional bullet hell boss fighter — but you can punch back.

**Core Experience Goals:**
- Every action — enemy attacks AND player counterattacks — feels musically satisfying
- Dodging and attacking are two distinct, learnable skill sets
- Each boss has a unique personality expressed through their attack patterns and music

---

## 2. Core Pillars

| Pillar | Description |
|---|---|
| **Rhythm First** | All gameplay events are anchored to the beat. Nothing fires off-beat. |
| **Readable Chaos** | Bullet patterns must be visually clear even at high density. |
| **Expressive Style** | Anime/cel-shaded visuals with personality — bosses feel alive. |
| **Learnable Mastery** | Players can improve. Patterns are fair, telegraphed, and repeatable. |
| **Clean Architecture** | Code is modular and separated for easy migration from HTML to Godot. |

---

## 3. Gameplay Loop

```
[Stage Select Screen]
        ↓
  [Boss Intro / Cutscene beat]
        ↓
  ┌─────────────────────────────┐
  │       DODGE PHASE           │  ← Boss attacks in beat-synced waves
  │  Player: free movement      │
  │  Boss: fires patterns       │
  └────────────┬────────────────┘
               │ (counterattack window opens)
  ┌────────────▼────────────────┐
  │     COUNTERATTACK PHASE     │  ← Beat prompts appear on screen
  │  Player: press on beat      │  ← Timing graded: Perfect / Good / Miss
  │  Boss: vulnerable / reacts  │
  └────────────┬────────────────┘
               │ (repeat cycle)
               │
  [Boss HP reaches 0] → Victory Screen → Stage Grade → Stage Select
       OR
  [Player HP reaches 0] → Game Over → Retry / Quit
```

**Phase Transitions** are triggered by the song's structure (e.g., a musical break signals the counterattack window). In the HTML prototype, this will be handled by a manual timeline/event array keyed to elapsed time.

---

## 4. Player

### 4.1 Character Design

- **Style:** Simple, distinct, and anime-inspired. Readable at small sizes against busy backgrounds.
- **Silhouette:** Strong, iconic silhouette so they're identifiable during frantic bullet patterns.
- **Expression:** Character should have idle, dodge, attack, and hit animations (even if simple in the HTML prototype).
- **Hitbox:** Small, clearly visualized hitbox (a visible glowing core/point) — standard bullet hell convention.

### 4.2 Movement (Dodge Phase)

- **Control Scheme:** Free movement via `WASD` or Arrow Keys. Mouse movement optional (TBD).
- **Speed:** Constant base movement speed. A "focus" modifier (hold `Shift`) halves movement speed and shows the hitbox clearly — used for precision dodging.
- **Constraints:** Player is bounded to the play field. Cannot leave the arena.
- **No invincibility frames** by default (can be revisited).

### 4.3 Health System

- **Health Bar:** Displayed visually as a bar (e.g., segmented hearts or a continuous bar — TBD stylistically).
- **Damage:** Taking a hit from a bullet reduces health. Amount TBD per boss.
- **Death:** Reaching 0 HP triggers a game over screen.
- **No regeneration** between phases (health persists across dodge/counterattack cycles within a fight).
- **Future consideration:** Small HP restore on a perfect counterattack chain.

---

## 5. Combat Systems

### 5.1 Dodge Phase

- Boss fires beat-synced bullet patterns toward / around the player.
- Player uses free movement to avoid projectiles.
- Patterns escalate as the boss loses HP (phase thresholds — see Boss Design).
- No player input required other than movement.

### 5.2 Counterattack Phase

- **Trigger:** A musical cue (break, drop, specific beat marker) signals the window opening.
- **Visual Cue:** Beat prompts appear on screen — circular rings, arrows, or button icons (TBD).
- **Input:** Player presses the attack key (`Space` or `Z`) on the beat.
- **Timing Grades:**

| Grade | Window | Effect |
|---|---|---|
| **PERFECT** | ±50ms from beat | Full damage + visual flash |
| **GOOD** | ±120ms from beat | Reduced damage (~60%) |
| **MISS** | Outside window | No damage, counter breaks |

- **Combo System:** Consecutive PERFECTs and GOODs build a combo multiplier. A MISS resets the combo.
- **Boss Reaction:** Boss visually reacts to each hit (flinch, flash, expression change).
- **Window End:** After a fixed number of beats (e.g., 8 beats), the counterattack window closes and the dodge phase resumes.

### 5.3 Damage Model

```
Base Damage × Timing Multiplier × Combo Multiplier = Total Damage

Timing Multiplier:  PERFECT = 1.0 | GOOD = 0.6 | MISS = 0
Combo Multiplier:   1× (no combo) up to 2× (max combo — TBD threshold)
```

---

## 6. Boss Design

### 6.1 Boss Structure

Each boss has:
- A **name and personality** expressed through their patterns and visual reactions
- A **unique song/track** (placeholder BPM-synced beat in prototype)
- **Multiple phases** triggered by HP thresholds (e.g., 75%, 50%, 25%)
- A **set of bullet patterns** per phase, each locked to beat timing
- **Counterattack windows** placed at musically appropriate moments

### 6.2 Pattern Types (Reference Library)

| Pattern Name | Description |
|---|---|
| **Radial Burst** | Bullets fire outward in all directions from boss center |
| **Aimed Shot** | Bullet(s) fired directly at player position |
| **Spiral** | Rotating stream of bullets curling outward |
| **Wall** | Line of bullets with one gap — player must find the gap |
| **Cross** | Four-directional simultaneous burst |
| **Delayed Rain** | Bullets drop from above on beat, position telegraphed by warnings |
| **Homing** | Slow bullets that curve toward player |

### 6.3 Boss Roster (Phase 1 — HTML Prototype)

5+ bosses planned. Each should feel distinct. Example archetypes:

| # | Working Name | Personality | Pattern Focus | BPM Feel |
|---|---|---|---|---|
| 1 | Tutorial Boss | Calm, simple | Radial + Aimed | Slow (80 BPM) |
| 2 | TBD | Aggressive | Spirals + Walls | Mid (120 BPM) |
| 3 | TBD | Erratic | Cross + Homing | Fast (140 BPM) |
| 4 | TBD | Elegant | Delayed Rain + Radial | Mid-slow (100 BPM) |
| 5 | TBD | Final/Intense | All patterns | Fast (160+ BPM) |

> Full boss sheets will be written as separate design documents per boss once core systems are confirmed.

### 6.4 Boss HP Phases

```
Phase 1: 100% – 75% HP  → Intro patterns, telegraphed, learnable
Phase 2:  75% – 50% HP  → Speed or density increase, new pattern added
Phase 3:  50% – 25% HP  → More aggressive, counterattack windows shorten
Phase 4:  25% –  0% HP  → "Enrage" — max pattern complexity, desperation moves
```

---

## 7. Music & Beat System

### 7.1 Beat Tracking

The entire game is driven by a central **Beat Clock**:
- Reads the current song's BPM
- Fires a beat event at each interval: `beatInterval = 60000ms / BPM`
- All gameplay events (bullets, counterattack windows, UI pulses) subscribe to this clock
- The Beat Clock is the single source of truth — nothing fires independently

### 7.2 Event Timeline

Each boss fight is driven by a **Song Event Timeline** — a JSON array of timed events:

```json
[
  { "beat": 1,  "type": "pattern", "id": "radial_burst" },
  { "beat": 5,  "type": "pattern", "id": "aimed_shot" },
  { "beat": 9,  "type": "counterattack_window", "duration_beats": 8 },
  { "beat": 17, "type": "pattern", "id": "spiral" }
]
```

This makes each fight fully data-driven and easy to edit without touching game logic.

### 7.3 Audio (Prototype)

- **HTML Prototype:** Placeholder royalty-free tracks or programmatically generated beats (Web Audio API oscillators)
- **BPM must be declared manually** per track in the boss data file
- Audio sync uses the `AudioContext.currentTime` for precision over `Date.now()`
- **Future:** Each boss gets a custom composed track. Music should dynamically react to phase transitions (filter, pitch shift, layer add).

---

## 8. UI & UX

### 8.1 HUD Elements (In-Fight)

| Element | Location | Notes |
|---|---|---|
| Player HP Bar | Bottom-left | Segmented or smooth bar |
| Boss HP Bar | Top-center | Wide, prominent |
| Boss Name / Phase | Above boss HP | Fades in on phase change |
| Beat Indicator | Bottom-center | Pulses visually on each beat |
| Combo Counter | Top-right | Displays during counterattack only |
| Timing Grade | Center-screen | PERFECT / GOOD / MISS flash |
| Counterattack Prompt | Center-screen | Beat rings that appear during windows |

### 8.2 Screens

- **Main Menu:** Stage select + settings
- **Stage Select:** Grid or list of bosses, locked/unlocked states, best grade shown
- **Boss Intro:** Name card + brief animation (simple in prototype)
- **In-Fight HUD:** As above
- **Pause Screen:** Resume, Retry, Quit
- **Victory Screen:** Grade breakdown, score, combo stats
- **Game Over Screen:** Retry or return to Stage Select

### 8.3 Accessibility Considerations (Future)

- Colorblind-friendly palette option for bullet types
- Input remapping
- Hitbox visibility toggle (always on vs. focus mode only)

---

## 9. Visual Style

### 9.1 Art Direction

- **Style:** Anime / cel-shaded. Bold outlines, flat color with shading, expressive character designs.
- **Color Palette:** Each boss has a dominant color that saturates the background and their bullet patterns.
- **Bullets:** Distinct shapes and colors per pattern type. Never visually ambiguous.
- **Background:** Per-boss animated background that reacts to the beat (subtle pulse, color shifts).
- **Player:** Neutral color palette so they contrast against any boss's theme.

### 9.2 Animation Priorities (Prototype → Full)

| Element | Prototype | Full Game |
|---|---|---|
| Player movement | Placeholder sprite | Smooth directional animation |
| Player hit | Flash red | Hit reaction + brief stagger |
| Player attack | Key press flash | Attack animation with trail |
| Boss idle | Static image | Looping idle animation |
| Boss hit | Flash | Flinch + expression change |
| Boss phase change | Color shift | Full phase transition cutscene |
| Bullets | Simple shapes | Stylized sprites with particle trails |

---

## 10. Stage Structure

### 10.1 Flow

- Game opens to **Stage Select** screen
- Stages are listed as a grid of boss portraits
- Stages unlock sequentially (beat stage N to unlock stage N+1)
- Each stage stores: best grade, best score, completion status

### 10.2 Grading

Each stage awards a letter grade on completion:

| Grade | Criteria |
|---|---|
| **S** | No damage taken + 90%+ PERFECT hits |
| **A** | No damage taken OR 80%+ PERFECT hits |
| **B** | Completed with moderate HP + decent combo |
| **C** | Completed (survived) |
| **F** | Game Over |

---

## 11. Scoring & Grading

### 11.1 Score Calculation

```
Score = Σ (Hit Timing Score × Combo Multiplier)

Hit Timing Score:  PERFECT = 100pts | GOOD = 60pts | MISS = 0pts
Combo Multiplier:  Scales from 1× to 2× at combo thresholds (TBD)
Bonus:             No-damage clear bonus (+% TBD)
```

### 11.2 Leaderboard (Future)

- Local high score per stage
- Optional online leaderboard post-Godot migration

---

## 12. File Structure & Scalability

> **Key Principle:** Logic, data, and presentation are always separated. This makes the Godot migration straightforward — swap the renderer, keep the logic.

### 12.1 HTML Prototype File Structure

```
/rhythm-bullet-hell/
│
├── index.html                  # Entry point
├── style.css                   # Global styles
│
├── /src/
│   ├── main.js                 # App init, scene manager
│   ├── /core/
│   │   ├── BeatClock.js        # BPM engine, beat event emitter
│   │   ├── InputManager.js     # Keyboard/mouse input abstraction
│   │   ├── SceneManager.js     # Manages screen transitions
│   │   └── AudioManager.js     # Web Audio API wrapper
│   │
│   ├── /game/
│   │   ├── Player.js           # Player state, movement, health
│   │   ├── BossController.js   # Boss HP, phase transitions, reactions
│   │   ├── BulletPool.js       # Bullet spawning and pooling
│   │   ├── PatternEngine.js    # Reads pattern data, fires bullets on beat
│   │   ├── CounterWindow.js    # Counterattack phase logic, timing grades
│   │   └── FightManager.js     # Orchestrates dodge/counter phase cycling
│   │
│   ├── /ui/
│   │   ├── HUD.js              # In-fight HUD rendering
│   │   ├── StageSelect.js      # Stage select screen
│   │   ├── VictoryScreen.js    # End-of-fight screen
│   │   └── Menus.js            # Main menu, pause, game over
│   │
│   └── /renderer/
│       ├── Canvas.js           # Canvas setup and draw loop
│       ├── BulletRenderer.js   # Draws bullets
│       ├── PlayerRenderer.js   # Draws player + hitbox
│       └── BossRenderer.js     # Draws boss + animations
│
├── /data/
│   ├── /bosses/
│   │   ├── boss_01.json        # Boss 1: stats, patterns, timeline, music ref
│   │   ├── boss_02.json        # Boss 2
│   │   └── ...
│   ├── /patterns/
│   │   ├── radial_burst.json   # Bullet pattern definitions
│   │   ├── spiral.json
│   │   └── ...
│   └── stages.json             # Stage unlock order, metadata
│
├── /assets/
│   ├── /audio/                 # Music files / placeholder beats
│   ├── /sprites/               # Player, boss, bullet sprites
│   └── /fonts/                 # UI fonts
│
└── /docs/
    ├── GDD.md                  # This document
    └── /bosses/                # Individual boss design sheets
```

### 12.2 Data-Driven Design Rules

- **Boss fights are fully defined by JSON** — no fight logic should be hardcoded
- **Patterns are reusable** — any boss can reference any pattern file
- **BeatClock is a singleton** — everything subscribes, nothing runs its own timer
- **Renderer is a separate layer** — game logic never directly draws; it updates state, renderer reads state

---

## 13. HTML Prototype Scope

### 13.1 Must Have (MVP)

- [ ] Beat Clock running at configurable BPM
- [ ] Player: free movement, hitbox collision, health bar
- [ ] Bullet Pool: spawn, move, collide, despawn
- [ ] Pattern Engine: reads JSON, fires patterns on beat
- [ ] At least 2 bullet pattern types (Radial, Aimed)
- [ ] Counterattack Window: beat prompts, timing detection, grade display
- [ ] Boss HP bar responding to player hits
- [ ] Stage Select with 1 playable boss
- [ ] Game Over + Victory screens

### 13.2 Should Have (Pre-Godot)

- [ ] 5 bosses with unique patterns and songs
- [ ] Boss phase transitions (HP thresholds)
- [ ] Full grading and scoring system
- [ ] Combo counter and multiplier
- [ ] Focus mode (slow + hitbox visible)
- [ ] Audio sync using Web Audio API

### 13.3 Nice to Have (If Time Allows)

- [ ] Beat-reactive backgrounds
- [ ] Sprite animations for player and boss
- [ ] Local high score persistence (localStorage)
- [ ] Sound effects on hit/perfect/miss

---

## 14. Godot Migration Notes

### 14.1 Mapping HTML → Godot

| HTML Concept | Godot Equivalent |
|---|---|
| `BeatClock.js` (JS event emitter) | `Node` + `signal beat_fired` |
| `Canvas.js` (2D draw loop) | `Node2D` + `_draw()` or `Sprite2D` nodes |
| `BulletPool.js` | `ObjectPool` pattern or Godot's built-in pooling |
| `InputManager.js` | Godot Input Map (project settings) |
| `PatternEngine.js` | `Node` reading JSON resource files |
| `AudioManager.js` | `AudioStreamPlayer` + Godot audio bus |
| Boss JSON files | Godot `.tres` Resources or JSON (both work) |

### 14.2 Migration Strategy

1. Keep all JSON data files **unchanged** — Godot reads JSON natively
2. Rewrite each JS module as an equivalent Godot Node/Script
3. Replace Canvas rendering with Godot scene tree nodes
4. Preserve the same game state model — only the renderer changes
5. Migrate one system at a time: Beat Clock → Player → Bullets → Boss → UI

---

## 15. Open Questions & Future Features

### Open Questions

- [ ] **Player character identity** — name, lore, design direction?
- [ ] **Boss names and themes** — needs creative pass once core systems are confirmed
- [ ] **Music source** — composed originals, licensed tracks, or procedural?
- [ ] **Mouse support** — should mouse movement be an option alongside WASD?
- [ ] **Invincibility frames** — grant brief iframes after taking damage?
- [ ] **Counterattack key** — single key, or multi-key sequences per boss?

### Future Features (Post-MVP)

- Boss-specific attack animations for the player
- Unlockable alternate characters or skins
- Online leaderboards
- Rhythm difficulty settings (more/fewer beats in windows)
- Story mode with narrative between stages
- A "gauntlet" mode (all bosses back to back, shared HP)
- Modding support (custom bosses via JSON + audio upload)

---

*End of Document — v0.1*  
*Next step: Implement Beat Clock + Player movement in HTML prototype.*
