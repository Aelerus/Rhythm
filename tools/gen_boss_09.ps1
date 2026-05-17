# Generates data/bosses/boss_09.json -- Synthwave World, Slot 2
# "NIGHT PULSE" -> "Rainlane Run" at 105 BPM (~301 beats, song = 172.28s)
#
# Difficulty target: 4/10 (per project_difficulty_curve memory).
# Bumped from earlier version: heavier density, more combo beats,
# tighter counter zones, more bouncers + grid pulses.
#
# === DESIGN INTENT ===
#
# Builds on the synthwave-only attack vocabulary from slot 1, and
# adds the SW_GRID_PULSE mechanic that fires bullets along active
# grid wall positions -- couples walls + bullets in a unique way.
# Speedlines come in pairs (forced lateral movement constantly).
# Wall pairs trigger at 50% HP; sw_grid_pulse turns those walls into
# bullet sources too.
#
# Perfect kill: first prompt of Counter 4 at beat 226 = 74.96% of song.

$ErrorActionPreference = 'Stop'

$timeline = New-Object System.Collections.Generic.List[object]

# ─── Pattern library (9 patterns) ──────────────────────────────────────
# Adds GRID_PULSE to slot 1's library.

$nd_drift     = [ordered]@{ type = 'homing';     count = 1; speed = 145; turnRate = 0.65; radius = 7; color = '#ff00aa' }
$nd_aim       = [ordered]@{ type = 'aimed_shot'; count = 1; speed = 280; radius = 7; color = '#00d4ff' }

# *** SYNTHWAVE-ONLY ***
$nd_arc       = [ordered]@{ type = 'sw_arc';       count = 6; spread = 1.3; speed = 240; curveRate = 1.9; radius = 6; color = '#ff00aa' }
$nd_sine      = [ordered]@{ type = 'sw_sine';      count = 4; spread = 0.28; speed = 220; sineAmp = 60; sineFreq = 1.4; radius = 6; color = '#00d4ff' }
$nd_speed     = [ordered]@{ type = 'sw_speedline'; lanes = 5; bulletsPerLane = 4; speed = 420; orient = 'h'; radius = 6; color = '#00d4ff' }
$nd_speed_v   = [ordered]@{ type = 'sw_speedline'; lanes = 4; bulletsPerLane = 4; speed = 420; orient = 'v'; radius = 6; color = '#00d4ff' }
$nd_bounce    = [ordered]@{ type = 'sw_bounce';    count = 4; spread = 0.40; speed = 260; bounces = 2; radius = 6; color = '#ff00aa' }
$nd_vector    = [ordered]@{ type = 'sw_vector_burst'; sides = 6; rings = 3; ringStep = 18; speed = 200; spin = 0.20; radius = 5; color = '#ff00aa' }

# NEW for slot 2 -- the grid+bullet coupler:
$nd_pulse     = [ordered]@{ type = 'sw_grid_pulse'; bulletsPerLine = 8; speed = 270; radius = 5; color = '#ff00aa' }

# ─── Helpers ──────────────────────────────────────────────────────────
function Add-Drift   ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:nd_drift }) }
function Add-Aim     ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:nd_aim }) }
function Add-Arc     ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:nd_arc }) }
function Add-Sine    ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:nd_sine }) }
function Add-Speed   ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:nd_speed }) }
function Add-SpeedV  ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:nd_speed_v }) }
function Add-Bounce  ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:nd_bounce }) }
function Add-Vector  ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:nd_vector }) }
function Add-Pulse   ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:nd_pulse }) }

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
#  SECTION 1: ARRIVAL  (beats 2-30)
# =====================================================================
Add-Sine   2
Add-Arc    8
Add-Drift  14
Add-Vector 18
Add-Sine   22
Add-Bounce 26                       # *** BOUNCER teased early ***
Add-Arc    30

# ---- Counter 1 @ 32 -- center, r=58 --------------------------------
Add-Counter 32 'center' 58 8 8                       # window [32, 48]

# =====================================================================
#  SECTION 2: STREETLIGHTS  (beats 50-72)
# =====================================================================
Add-Speed  50
Add-Wall   52 'h3' 'v2' 14         # WALL 1 (expires 66)
Add-Pulse  54                      # *** GRID PULSE -- bullets from active walls ***
Add-Sine   58
Add-Arc    60
Add-SpeedV 62
Add-Bounce 65
Add-Pulse  66                      # combo with walls
Add-Vector 68
Add-Aim    72

# ---- Counter 2 @ 78 -- topRight, r=50 ------------------------------
Add-Counter 78 'topRight' 50 6 8                     # window [78, 92]

# =====================================================================
#  SECTION 3: GRID REVEAL  (beats 94-128)
# =====================================================================
Add-Arc    94
Add-Vector 96
Add-Wall   100 'v2' 'h3' 14        # WALL 2 (expires 114)
Add-Pulse  102                     # grid pulse along active walls
Add-Sine   104
Add-Speed  106                     # combo
Add-Bounce 106
Add-Pulse  110
Add-SpeedV 112
Add-Arc    115
Add-Sine   118
Add-Bounce 120                     # combo
Add-Vector 120
Add-Drift  124
Add-Aim    128

# ---- Counter 3 @ 130 -- bottomLeft, r=48, dur=10 ------------------
Add-Counter 130 'bottomLeft' 48 6 10                 # window [130, 146]

# =====================================================================
#  SECTION 4: CLIMAX  (beats 148-218) -- wall pairs + dense grid pulses
# =====================================================================
Add-Wall   148 'h2' 'v1' 14        # WALL 3 (expires 162) -- pair
Add-Pulse  150                     # PULSE during paired walls -- intense
Add-Arc    152
Add-Speed  155                     # combo
Add-Bounce 155
Add-Sine   158
Add-Vector 160
Add-Pulse  162                     # second pulse
Add-Aim    164
Add-Wall   166 'h3' 'v2' 14        # WALL 4 (expires 180) -- pair
Add-Pulse  168                     # pulse during walls
Add-Arc    170
Add-SpeedV 172                     # combo
Add-Bounce 172
Add-Sine   175
Add-Vector 178
Add-Pulse  180
Add-Arc    182
Add-Wall   185 'h2' 'v2' 14        # WALL 5 (expires 199)
Add-Speed  187
Add-Bounce 189                     # combo
Add-Sine   189
Add-Vector 192
Add-Pulse  194
Add-Arc    197
Add-Aim    200
Add-SpeedV 203
Add-Bounce 206
Add-Sine   209
Add-Arc    212
Add-Vector 215
Add-Speed  218

# ---- Counter 4 @ 220 -- center, r=48 -- KILL @ first prompt = 226 --
Add-Counter 220 'center' 48 6 8                      # window [220, 234]

# =====================================================================
#  SECTION 5: COOLDOWN  (beats 238-262)
# =====================================================================
Add-Wall   238 'h2' 'v2' 14        # WALL 6 (expires 252)
Add-Arc    240
Add-Pulse  242
Add-Sine   245
Add-Bounce 248
Add-SpeedV 251
Add-Vector 254
Add-Aim    257
Add-Arc    260

# ---- Counter 5 @ 266 -- right, r=52, dur=10 (safety net) -----------
Add-Counter 266 'right' 52 6 10                      # window [266, 282]

# =====================================================================
#  SECTION 6: FADE  (beats 288-298)
# =====================================================================
Add-Sine   288
Add-Arc    293
Add-Vector 298

$sorted = $timeline | Sort-Object beat

$boss = [ordered]@{
  id                = 'boss_09'
  name              = 'NIGHT PULSE'
  color             = '#3a1c6b'
  bpm               = 105
  maxHP             = 2780
  bulletDamage      = 1
  counterBaseDamage = 60
  music             = 'Music/synthwave/Rainlane Run.wav'
  musicVolume       = 0.9
  musicOffset       = 0
  phaseThresholds   = @()
  patterns          = @()
  timeline          = $sorted
}

$json = $boss | ConvertTo-Json -Depth 12
$out  = 'c:\Users\robbc\OneDrive\Code\Rhythm\data\bosses\boss_09.json'
[System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output ("Wrote " + $out + " with " + $sorted.Count + " timeline events.")
