# Generates data/bosses/boss_10.json -- Synthwave World, Slot 3
# "GHOST LANE" at 110 BPM
# Target song length: ~155s (~284 beats). UPDATE musicPath + re-verify HP
# once the real Suno song is locked.
#
# Difficulty target: 4-5/10 (per project_difficulty_curve memory).
#
# === DESIGN INTENT ===
#
# Slot 3 introduces ONE new signature mechanic: MIRROR PATH.
#   Bullets fire from positions along the player's recent trail,
#   each aimed at the player's CURRENT position. Telegraphed.
#   Punishes lingering AND punishes predictable straight-line movement.
#
# Returning patterns are the foundational synthwave kit (drift, aim,
# lane, sweep) plus two from slot 2 (tempo grid, stutter aim).
# Split wave gets a slot off; vortex stays slot 1's signature.
#
# Grid wall mechanic unchanged from slots 1-2 (single -> pair at 50% HP).
#
# Perfect kill: first prompt of Counter 4 at beat 213 = ~75% of song.

$ErrorActionPreference = 'Stop'

$timeline = New-Object System.Collections.Generic.List[object]

# ─── Pattern library (6 returning + 1 NEW signature) ──────────────────
# PINK (#ff00aa) tracks/threatens.  CYAN (#00d4ff) is straight-line.

# Returning -- slightly faster/tighter than slot 2:
$gl_drift   = [ordered]@{ type = 'homing';     count = 1; speed = 140; turnRate = 0.62; radius = 7; color = '#ff00aa' }
$gl_aim     = [ordered]@{ type = 'aimed_shot'; count = 1; speed = 280; radius = 7; color = '#00d4ff' }
$gl_sweep_h = [ordered]@{ type = 'laser_line'; orient = 'h'; lanes = 1; speed = 420; telegraph = 0.52; beadCount = 18; count = 4; radius = 6; color = '#ff00aa' }
$gl_sweep_v = [ordered]@{ type = 'laser_line'; orient = 'v'; lanes = 1; speed = 420; telegraph = 0.52; beadCount = 14; count = 4; radius = 6; color = '#ff00aa' }
$gl_grid    = [ordered]@{ type = 'tempo_grid'; cols = 5; rows = 4; arms = 4; speed = 210; telegraph = 0.52; parity = 0; markerRadius = 12; markerColor = '#ff00aa'; radius = 6; color = '#ff00aa' }
$gl_stutter = [ordered]@{ type = 'stutter_aim'; count = 3; spread = 0.32; speed = 340; onTime = 0.30; offTime = 0.20; radius = 6; color = '#ff00aa' }

# NEW SIGNATURE: MIRROR PATH
# Spawns 4 bullets at points along the player's last ~4s of movement.
# Each bullet aims at the player's CURRENT position with a telegraph delay.
# Walk straight = bullets all come from one line (easy). Walk zigzag =
# bullets come from spread positions and converge from multiple angles.
$gl_ghost   = [ordered]@{ type = 'mirror_path'; count = 4; speed = 250; telegraph = 0.40; radius = 7; color = '#ff00aa' }

# ─── Helpers ──────────────────────────────────────────────────────────
function Add-Drift   ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:gl_drift }) }
function Add-Aim     ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:gl_aim }) }
function Add-SweepH  ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:gl_sweep_h }) }
function Add-SweepV  ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:gl_sweep_v }) }
function Add-Grid    ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:gl_grid }) }
function Add-Stutter ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:gl_stutter }) }
function Add-Ghost   ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:gl_ghost }) }

function Add-Wall([int]$beat, [string]$primary, [string]$pair, [int]$dur = 16) {
  $script:timeline.Add([ordered]@{
    beat = $beat; type = 'grid_wall'
    line = $primary; pair_line = $pair
    duration_beats = $dur
  })
}

function Add-Counter([int]$beat, [string]$anchor, [int]$radius, [int]$lead, [int]$dur) {
  $script:timeline.Add([ordered]@{
    beat = $beat; type = 'counterattack_window'
    duration_beats = $dur; lead_beats = $lead
    zone = [ordered]@{ anchor = $anchor; radius = $radius }
  })
}

# =====================================================================
#  SECTION 1: WET ROAD  (beats 2-30)
#  Sparse intro. Single attacks. Reflective vibe.
# =====================================================================
Add-Aim     2
Add-Drift   8
Add-Aim     14
Add-Stutter 20
Add-Drift   26

# ---- Counter 1 @ 32 -- center, r=65 (intro grace) ------------------
Add-Counter 32 'center' 65 8 8                       # window [32, 48]

# =====================================================================
#  SECTION 2: HEADLIGHT TRAILS  (beats 50-78)
#  First grid wall. FIRST GHOST -- the signature mechanic debuts here.
# =====================================================================
Add-Aim     50
Add-Wall    52 'h3' 'v2' 16       # WALL 1 (expires 68)
Add-Aim     54
Add-Drift   58
Add-Ghost   61                    # *** FIRST MIRROR PATH -- showcase ***
Add-Stutter 65
Add-Aim     68                    # walls just expired
Add-SweepH  72                    # first sweep
Add-Drift   76

# ---- Counter 2 @ 80 -- topRight, r=58 ------------------------------
Add-Counter 80 'topRight' 58 6 8                     # window [80, 94]

# =====================================================================
#  SECTION 3: MEMORY DRIVE  (beats 100-140)
#  Tempo grid returns from slot 2. More ghost patterns.
# =====================================================================
Add-Wall    100 'v2' 'h3' 16      # WALL 2 (expires 116)
Add-Grid    102
Add-Aim     105
Add-Ghost   108                   # ghost during walls -- forces awareness
Add-Drift   110
Add-SweepV  113
Add-Aim     117                   # walls expired
Add-Stutter 119
Add-Aim     122
Add-Ghost   125                   # ghost pair
Add-Drift   128
Add-SweepH  132
Add-Aim     135
Add-Stutter 138

# ---- Counter 3 @ 145 -- bottomLeft, r=50, dur=10 -------------------
Add-Counter 145 'bottomLeft' 50 6 10                 # window [145, 161]

# =====================================================================
#  SECTION 4: REAR VIEW  (beats 165-200)
#  Climax. Wall pairs active (HP < 50% by here). Ghost density rises.
# =====================================================================
Add-Wall    165 'h2' 'v1' 16      # WALL 3 (expires 181) -- pair likely
Add-Drift   167
Add-Ghost   170                   # ghost during walls
Add-Stutter 173
Add-Aim     176
Add-Aim     179
Add-Wall    181 'h3' 'v2' 16      # WALL 4 (expires 197) -- pair likely
Add-Ghost   183                   # ghost AGAIN -- the boss is reading you
Add-SweepV  186
Add-Drift   189                   # combo
Add-Aim     189
Add-Grid    192
Add-Stutter 195
Add-Ghost   198                   # final ghost before counter

# ---- Counter 4 @ 207 -- top, r=50 -- KILL @ first prompt beat 213 --
Add-Counter 207 'top' 50 6 8                         # window [207, 221]

# =====================================================================
#  SECTION 5: AFTERIMAGE  (beats 224-248)
#  Safety net for missed kills. Last ghost flurry.
# =====================================================================
Add-Wall    225 'h2' 'v2' 16      # WALL 5 (expires 241)
Add-Aim     227
Add-Ghost   230
Add-Drift   232
Add-Aim     235
Add-SweepH  238
Add-Stutter 242                   # walls expired
Add-Ghost   245
Add-Aim     248

# ---- Counter 5 @ 252 -- right, r=55, dur=10 (safety) ---------------
Add-Counter 252 'right' 55 6 10                      # window [252, 268]

# =====================================================================
#  SECTION 6: FADE  (beats 274-280)
# =====================================================================
Add-Drift   274
Add-Aim     280

$sorted = $timeline | Sort-Object beat

$boss = [ordered]@{
  id                = 'boss_10'
  name              = 'GHOST LANE'
  color             = '#4a2a8a'
  bpm               = 110
  maxHP             = 2780
  bulletDamage      = 8
  counterBaseDamage = 60
  music             = 'Music/synthwave/Ghost Lane.wav'   # UPDATE when Suno song is locked
  musicVolume       = 0.9
  musicOffset       = 0
  phaseThresholds   = @()
  patterns          = @()
  timeline          = $sorted
}

$json = $boss | ConvertTo-Json -Depth 12
$out  = 'c:\Users\robbc\OneDrive\Code\Rhythm\data\bosses\boss_10.json'
[System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output ("Wrote " + $out + " with " + $sorted.Count + " timeline events.")
