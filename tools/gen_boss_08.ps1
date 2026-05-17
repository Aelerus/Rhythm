# Generates data/bosses/boss_08.json -- Synthwave World, Slot 1
# "CRUISE CONTROL" -> "Open Highway" at 90 BPM (~239 beats)
#
# Difficulty target: 3-4/10.
# Bumped: more bullets per attack, denser timeline, tighter counter zones.
#
# === DESIGN INTENT ===
#
# SYNTHWAVE-EXCLUSIVE attacks introduce themselves here:
#   - SW_ARC: curving neon-trail bullets that bend toward each other
#   - SW_SINE: bullets in sine-wave motion (neon snake)
#   - SW_SPEEDLINE: parallel "highway lanes" with one safe gap
#   - SW_BOUNCE: bullets that ricochet off arena walls
#   - SW_GRID_PULSE: bullets fired ALONG active grid lines
#   - SW_VECTOR_BURST: geometric polygon rings expanding outward
#
# Only 2 foundational fallbacks: drift (slow homing) and aim (single shot).
# Everything else is synthwave-specific.
#
# Grid wall mechanic unchanged (single -> pair @ 50% HP).
# Perfect kill: first prompt of Counter 4 at beat 179 = 74.77%.

$ErrorActionPreference = 'Stop'

$timeline = New-Object System.Collections.Generic.List[object]

# ─── Pattern library (8 patterns: 2 foundational + 6 synthwave-only) ──
# PINK (#ff00aa) tracks/threatens.  CYAN (#00d4ff) is straight-line.

$cc_drift     = [ordered]@{ type = 'homing';     count = 1; speed = 130; turnRate = 0.65; radius = 7; color = '#ff00aa' }
$cc_aim       = [ordered]@{ type = 'aimed_shot'; count = 1; speed = 250; radius = 7; color = '#00d4ff' }

# *** SYNTHWAVE-ONLY ***
$cc_arc       = [ordered]@{ type = 'sw_arc';       count = 5; spread = 1.4; speed = 220; curveRate = 1.8; radius = 6; color = '#ff00aa' }
$cc_sine      = [ordered]@{ type = 'sw_sine';      count = 3; spread = 0.30; speed = 200; sineAmp = 50; sineFreq = 1.2; radius = 6; color = '#00d4ff' }
$cc_speedline = [ordered]@{ type = 'sw_speedline'; lanes = 5; bulletsPerLane = 4; speed = 380; orient = 'h'; radius = 6; color = '#00d4ff' }
$cc_speedline_v = [ordered]@{ type = 'sw_speedline'; lanes = 4; bulletsPerLane = 4; speed = 380; orient = 'v'; radius = 6; color = '#00d4ff' }
$cc_bounce    = [ordered]@{ type = 'sw_bounce';    count = 3; spread = 0.45; speed = 240; bounces = 2; radius = 6; color = '#ff00aa' }
$cc_vector    = [ordered]@{ type = 'sw_vector_burst'; sides = 6; rings = 2; ringStep = 18; speed = 180; spin = 0.20; radius = 5; color = '#ff00aa' }

# ─── Helpers ──────────────────────────────────────────────────────────
function Add-Drift     ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:cc_drift }) }
function Add-Aim       ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:cc_aim }) }
function Add-Arc       ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:cc_arc }) }
function Add-Sine      ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:cc_sine }) }
function Add-Speed     ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:cc_speedline }) }
function Add-SpeedV    ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:cc_speedline_v }) }
function Add-Bounce    ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:cc_bounce }) }
function Add-Vector    ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:cc_vector }) }

function Add-Wall([int]$beat, [string]$primary, [string]$pair, [int]$dur = 14) {
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
#  SECTION 1: CRUISE IN  (beats 2-30)  -- teach with the new attacks
# =====================================================================
Add-Aim    2
Add-Sine   6                       # *** SINE motion -- first synthwave attack ***
Add-Aim    10
Add-Arc    14                      # *** ARC -- curving neon bullets ***
Add-Drift  18
Add-Sine   22
Add-Vector 26                      # *** VECTOR BURST -- geometric ring ***
Add-Arc    30

# ---- Counter 1 @ 32 -- center, r=60 (TIGHTER than before) ----------
Add-Counter 32 'center' 60 8 8                          # window [32, 48]

# =====================================================================
#  SECTION 2: LANE DISCIPLINE  (beats 50-68)  -- speedlines + walls
# =====================================================================
Add-Speed  50                      # *** SPEEDLINE -- 4 parallel lanes ***
Add-Wall   52 'h3' 'v2' 14         # WALL 1 (expires 66)
Add-Sine   54
Add-Drift  58
Add-Arc    60
Add-Speed  62
Add-Sine   64
Add-Vector 66
Add-Aim    68

# ---- Counter 2 @ 70 -- topRight, r=50 (tight) ----------------------
Add-Counter 70 'topRight' 50 6 8                        # window [70, 84]

# =====================================================================
#  SECTION 3: NIGHT DRIVE  (beats 85-113)  -- bouncers + vertical lanes
# =====================================================================
Add-Bounce 85                      # *** BOUNCER -- bullets ricochet off walls ***
Add-Aim    87
Add-SpeedV 90                      # vertical lanes
Add-Wall   92 'v2' 'h3' 14         # WALL 2 (expires 106)
Add-Arc    94
Add-Sine   96
Add-Bounce 100
Add-Drift  102
Add-Vector 104
Add-Arc    106
Add-Speed  108
Add-Sine   110
Add-Aim    112

# ---- Counter 3 @ 115 -- bottomLeft, r=50 ---------------------------
Add-Counter 115 'bottomLeft' 50 6 10                    # window [115, 131]

# =====================================================================
#  SECTION 4: HIGHWAY CLIMAX  (beats 134-171)  -- wall pairs, combos
# =====================================================================
Add-Wall   135 'h2' 'v1' 14        # WALL 3 (expires 149) -- PAIR likely
Add-Arc    134
Add-Bounce 137
Add-Speed  139                     # speedline through walls -- TIGHT
Add-Sine   141
Add-Drift  143                     # combo
Add-Vector 143
Add-SpeedV 146
Add-Wall   150 'h3' 'v2' 14        # WALL 4 (expires 164) -- PAIR likely
Add-Arc    151
Add-Bounce 154
Add-Sine   156
Add-Speed  158                     # combo
Add-Vector 158
Add-Aim    160
Add-Arc    162
Add-Sine   165
Add-Bounce 168                     # combo
Add-Vector 168
Add-Speed  171

# ---- Counter 4 @ 173 -- top, r=50 -- KILL @ beat 179 ---------------
Add-Counter 173 'top' 50 6 8                            # window [173, 187]

# =====================================================================
#  SECTION 5: COAST OUT  (beats 190-213)
# =====================================================================
Add-Wall   190 'h2' 'v2' 14        # WALL 5 (expires 204)
Add-Sine   192
Add-Arc    194
Add-Speed  196
Add-Bounce 199
Add-Vector 202
Add-SpeedV 205                     # walls expired
Add-Drift  208
Add-Arc    210
Add-Sine   213

# ---- Counter 5 @ 215 -- right, r=55, dur=10 (safety net) -----------
Add-Counter 215 'right' 55 6 10                         # window [215, 231]

# =====================================================================
#  SECTION 6: OUTRO  (beats 232-234)
# =====================================================================
Add-Sine   232
Add-Arc    234

$sorted = $timeline | Sort-Object beat

$boss = [ordered]@{
  id                = 'boss_08'
  name              = 'CRUISE CONTROL'
  color             = '#162e6e'
  bpm               = 90
  maxHP             = 2700
  bulletDamage      = 1
  counterBaseDamage = 60
  music             = 'Music/synthwave/Open Highway.wav'
  musicVolume       = 0.9
  musicOffset       = 0
  phaseThresholds   = @()
  patterns          = @()
  timeline          = $sorted
}

$json = $boss | ConvertTo-Json -Depth 12
$out  = 'c:\Users\robbc\OneDrive\Code\Rhythm\data\bosses\boss_08.json'
[System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output ("Wrote " + $out + " with " + $sorted.Count + " timeline events.")
