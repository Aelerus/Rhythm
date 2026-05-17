# Generates data/bosses/boss_14.json -- Synthwave World, Slot 7 (BOSS)
# "GHOST" -> "Glitchline Run" at 120 BPM (~480 beats, song = 240.24s)
#
# Difficulty target: 8/10.
#
# === DESIGN INTENT ===
#
# Heavy density and combo beats. Boss combines EVERY synthwave-only
# attack the player has seen across slots 1-6, plus two boss-only
# tightened variants:
#   - GHOST_ARC: 9-bullet arc with stronger curve and longer maxLife
#   - PULSE_STORM: grid_pulse with double bullets per line
# Plus the LINE STORM event for grid chaos.

$ErrorActionPreference = 'Stop'

$timeline = New-Object System.Collections.Generic.List[object]

# ─── Pattern library (12 synthwave-only patterns) ─────────────────────
# PINK (#ff00aa) tracks/threatens.  CYAN (#00d4ff) is straight-line.

$g_drift     = [ordered]@{ type = 'homing';     count = 1; speed = 170; turnRate = 0.75; radius = 7; color = '#ff00aa' }
$g_aim       = [ordered]@{ type = 'aimed_shot'; count = 1; speed = 320; radius = 7; color = '#00d4ff' }

# Synthwave returnees (faster/denser than earlier slots):
$g_arc       = [ordered]@{ type = 'sw_arc';       count = 7; spread = 1.5; speed = 270; curveRate = 2.2; radius = 6; color = '#ff00aa' }
$g_sine      = [ordered]@{ type = 'sw_sine';      count = 5; spread = 0.30; speed = 250; sineAmp = 70; sineFreq = 1.6; radius = 6; color = '#00d4ff' }
$g_speed     = [ordered]@{ type = 'sw_speedline'; lanes = 6; bulletsPerLane = 5; speed = 480; orient = 'h'; radius = 6; color = '#00d4ff' }
$g_speed_v   = [ordered]@{ type = 'sw_speedline'; lanes = 5; bulletsPerLane = 5; speed = 480; orient = 'v'; radius = 6; color = '#00d4ff' }
$g_bounce    = [ordered]@{ type = 'sw_bounce';    count = 5; spread = 0.45; speed = 300; bounces = 2; radius = 6; color = '#ff00aa' }
$g_vector    = [ordered]@{ type = 'sw_vector_burst'; sides = 8; rings = 3; ringStep = 18; speed = 230; spin = 0.18; radius = 5; color = '#ff00aa' }
$g_pulse     = [ordered]@{ type = 'sw_grid_pulse'; bulletsPerLine = 10; speed = 310; radius = 5; color = '#ff00aa' }

# *** BOSS-ONLY VARIANTS ***
$g_ghost_arc  = [ordered]@{ type = 'sw_arc';       count = 9; spread = 1.7; speed = 290; curveRate = 2.6; radius = 6; color = '#ff00aa' }
$g_storm_pulse = [ordered]@{ type = 'sw_grid_pulse'; bulletsPerLine = 14; speed = 340; radius = 5; color = '#ff00aa' }
$g_chaos_bounce = [ordered]@{ type = 'sw_bounce';   count = 6; spread = 0.55; speed = 320; bounces = 3; radius = 6; color = '#ff00aa' }

# ─── Helpers ──────────────────────────────────────────────────────────
function Add-Drift   ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_drift }) }
function Add-Aim     ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_aim }) }
function Add-Arc     ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_arc }) }
function Add-Sine    ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_sine }) }
function Add-Speed   ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_speed }) }
function Add-SpeedV  ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_speed_v }) }
function Add-Bounce  ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_bounce }) }
function Add-Vector  ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_vector }) }
function Add-Pulse   ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_pulse }) }
function Add-GhostArc ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_ghost_arc }) }
function Add-StormPulse ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_storm_pulse }) }
function Add-ChaosBounce ([int]$b) { $script:timeline.Add([ordered]@{ beat = $b; type = 'pattern'; patternData = $script:g_chaos_bounce }) }

function Add-Wall([int]$beat, [string]$primary, [string]$pair, [int]$dur = 16) {
  $script:timeline.Add([ordered]@{
    beat = $beat; type = 'grid_wall'
    line = $primary; pair_line = $pair
    duration_beats = $dur
  })
}

function Add-LineStorm([int]$beat, [string[]]$lines, [int]$dur = 6) {
  $script:timeline.Add([ordered]@{
    beat = $beat; type = 'line_storm'
    lines = $lines; duration_beats = $dur
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
#  SECTION 1: BOOT SEQUENCE  (beats 2-30)
# =====================================================================
Add-Sine   2
Add-Arc    8
Add-Vector 14
Add-Bounce 18
Add-Sine   22
Add-Arc    26
Add-Drift  30

# ---- Counter 1 @ 32 -- center, r=55 --------------------------------
Add-Counter 32 'center' 55 8 8                       # window [32, 48]

# =====================================================================
#  SECTION 2: FIRST GLITCH  (beats 50-100)
# =====================================================================
Add-Speed  50
Add-Wall   54 'h3' 'v2' 16          # WALL 1 (expires 70)
Add-Pulse  56                       # grid pulse
Add-Arc    58
Add-Sine   60                       # combo
Add-Vector 60
Add-Bounce 64
Add-Pulse  66
Add-SpeedV 68
Add-Arc    70
Add-Sine   74
Add-Vector 76                       # combo
Add-Speed  76
Add-Drift  80
Add-Bounce 84
Add-Arc    88                       # combo
Add-Pulse  88
Add-Sine   92
Add-SpeedV 96
Add-Aim    100

# ---- Counter 2 @ 105 -- topRight, r=48 -----------------------------
Add-Counter 105 'topRight' 48 6 8                    # window [105, 119]

# =====================================================================
#  SECTION 3: BREACH  (beats 125-205) -- wall PAIRS active
# =====================================================================
Add-Wall   125 'v2' 'h3' 16         # WALL 2 (expires 141) -- pair
Add-StormPulse 127                  # *** STORM PULSE -- dense grid pulse ***
Add-Arc    130
Add-Sine   132                      # combo
Add-Vector 132
Add-Bounce 135
Add-Pulse  137
Add-Speed  139
Add-Wall   142 'h2' 'v1' 16         # WALL 3 (expires 158)
Add-GhostArc 144                    # *** GHOST ARC -- 9-bullet wider arc ***
Add-Sine   146
Add-Bounce 148                      # combo
Add-Vector 148
Add-Pulse  150
Add-SpeedV 153
Add-Arc    156
Add-Sine   158
Add-Wall   162 'h3' 'v2' 16         # WALL 4 (expires 178)
Add-StormPulse 164
Add-Bounce 166
Add-Arc    169                      # combo
Add-Vector 169
Add-Sine   172
Add-Speed  175
Add-Pulse  178
Add-GhostArc 181
Add-ChaosBounce 184                 # *** CHAOS BOUNCE -- 6 bullets, 3 bounces ***
Add-SpeedV 188
Add-Arc    192
Add-Sine   195                      # combo
Add-Vector 195
Add-Pulse  198
Add-Bounce 202

# ---- Counter 3 @ 210 -- bottomLeft, r=45, dur=10 ------------------
Add-Counter 210 'bottomLeft' 45 6 10                 # window [210, 226]

# =====================================================================
#  SECTION 4: MEMORY STORM  (beats 230-348)
# =====================================================================
Add-Wall   230 'h3' 'v2' 16         # WALL 5 (expires 246)
Add-StormPulse 232
Add-GhostArc 235
Add-Sine   238                      # combo
Add-Speed  238
Add-Bounce 241
Add-Vector 244
Add-LineStorm 250 @('h0','h2','h4','v1','v3') 6  # *** LINE STORM 1 ***
Add-Pulse  252                      # storm + pulse during it
Add-Arc    255
Add-ChaosBounce 258
Add-Wall   264 'h2' 'v2' 16         # WALL 6 (expires 280)
Add-StormPulse 266
Add-Sine   268                      # combo
Add-Vector 268
Add-GhostArc 272
Add-SpeedV 275
Add-Bounce 278
Add-Aim    282
Add-Arc    284
Add-Pulse  286
Add-LineStorm 290 @('h1','h3','h5','v0','v2') 6  # *** LINE STORM 2 ***
Add-StormPulse 292
Add-Sine   295
Add-Vector 298                      # combo
Add-Bounce 298
Add-GhostArc 302
Add-Speed  305
Add-ChaosBounce 308
Add-Arc    312
Add-Pulse  315
Add-Sine   318                      # combo
Add-Vector 318
Add-SpeedV 322
Add-GhostArc 325
Add-Bounce 328
Add-Arc    331                      # combo
Add-StormPulse 331
Add-Sine   335
Add-Vector 338
Add-Speed  342
Add-Pulse  346

# ---- Counter 4 @ 354 -- center, r=45 -- KILL @ first prompt = 360 --
Add-Counter 354 'center' 45 6 8                      # window [354, 368]

# =====================================================================
#  SECTION 5: SYSTEM FAILURE  (beats 372-455)
# =====================================================================
Add-Wall   372 'h2' 'v1' 16         # WALL 7 (expires 388)
Add-StormPulse 374
Add-GhostArc 377
Add-ChaosBounce 380
Add-Sine   383                      # combo
Add-Vector 383
Add-LineStorm 388 @('h0','h1','h2','h3','h4','h5','v0','v1','v2','v3') 4  # *** STORM 3 -- ALL LINES ***
Add-StormPulse 390
Add-Speed  392
Add-Arc    395
Add-Bounce 398
Add-Wall   402 'h3' 'v2' 16         # WALL 8 (expires 418)
Add-Pulse  404
Add-GhostArc 407
Add-Sine   410                      # combo
Add-SpeedV 410
Add-Vector 413
Add-ChaosBounce 416
Add-StormPulse 420
Add-Arc    423
Add-Bounce 426                      # combo
Add-Pulse  426
Add-Speed  430
Add-Sine   433
Add-GhostArc 436
Add-Vector 440
Add-StormPulse 444
Add-Bounce 448
Add-Arc    451                      # combo
Add-SpeedV 451

# ---- Counter 5 @ 460 -- right, r=52, dur=10 (safety net) -----------
Add-Counter 460 'right' 52 6 10                      # window [460, 476]

# =====================================================================
#  SECTION 6: FADE  (beats 478-480)
# =====================================================================
Add-Sine   478
Add-Arc    480

$sorted = $timeline | Sort-Object beat

$boss = [ordered]@{
  id                = 'boss_14'
  name              = 'GHOST'
  color             = '#6e3aff'
  bpm               = 120
  maxHP             = 3450
  bulletDamage      = 1
  counterBaseDamage = 75
  music             = 'Music/synthwave/Glitchline Run.wav'
  musicVolume       = 0.9
  musicOffset       = 0
  phaseThresholds   = @()
  patterns          = @()
  timeline          = $sorted
}

$json = $boss | ConvertTo-Json -Depth 12
$out  = 'c:\Users\robbc\OneDrive\Code\Rhythm\data\bosses\boss_14.json'
[System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output ("Wrote " + $out + " with " + $sorted.Count + " timeline events.")
