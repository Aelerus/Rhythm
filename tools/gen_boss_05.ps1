# Generates data/bosses/boss_05.json -- "PULSE", a cyberpunk techno level
# timed to "Restless Heart" at 175 BPM (~158s = ~461 beats).
#
# The timeline mirrors the song's structural markers:
#   Intro    0:00-0:20   beats   0..56    sparse atmospheric pings
#   Build    0:20-1:00   beats  56..144   density grows toward first counter
#   Counter1  beat 144                    early teach of the parry mechanic
#   Buildup  1:00-1:18   beats 158..228   risers, snare-roll feel via fast spirals
#   DROP     beat 228                     three layered patterns at the drop
#   Counter2  beat 232                    cash in the drop with a punchy parry
#   Mid      1:18-2:09   beats 246..374   sustained heavy density
#   Counter3  beat 296                    mid-section parry
#   Counter4  beat 360                    pre-second-drop parry
#   2nd Drop 2:09-2:28   beats 374..432   chaotic glitchy section
#   Counter5  beat 408                    at the second drop
#   Outro    2:28-2:38   beats 432..461   strip layers + final counter
#   Counter6  beat 440                    closing parry; song ends ~beat 461

$ErrorActionPreference = 'Stop'

$timeline = New-Object System.Collections.Generic.List[object]

function Add-Pattern([int]$beat, [string]$id) {
  $timeline.Add([ordered]@{ beat = $beat; type = 'pattern'; id = $id })
}

function Add-Counter([int]$beat, [string]$anchor, [int]$radius, [int]$leadBeats, [int]$durationBeats) {
  $timeline.Add([ordered]@{
    beat = $beat
    type = 'counterattack_window'
    duration_beats = $durationBeats
    lead_beats = $leadBeats
    zone = [ordered]@{ anchor = $anchor; radius = $radius }
  })
}

# -------- INTRO (sparse pings) --------
Add-Pattern 16 'aimed_shot'
Add-Pattern 32 'pulse_radial'
Add-Pattern 40 'aimed_shot'
Add-Pattern 48 'pulse_radial'

# -------- BUILD (kick enters, growing density) --------
$buildEvents = @(
  64, 'pulse_radial',
  68, 'aimed_shot',
  72, 'pulse_radial',
  76, 'digital_cross',
  80, 'aimed_shot',
  84, 'pulse_radial',
  88, 'aimed_shot',
  92, 'pulse_radial',
  96, 'digital_cross',
  98, 'aimed_shot',
 100, 'pulse_radial',
 104, 'aimed_shot',
 106, 'digital_cross',
 108, 'pulse_radial',
 112, 'aimed_shot',
 114, 'digital_cross',
 116, 'pulse_radial',
 120, 'aimed_shot',
 122, 'pulse_radial',
 124, 'digital_cross',
 128, 'aimed_shot',
 130, 'pulse_radial',
 132, 'digital_cross',
 134, 'aimed_shot',
 136, 'pulse_radial',
 138, 'aimed_shot',
 140, 'digital_cross'
)
for ($i = 0; $i -lt $buildEvents.Length; $i += 2) { Add-Pattern $buildEvents[$i] $buildEvents[$i + 1] }

Add-Counter 144 'center' 80 6 8

# -------- BUILDUP (risers, faster, snare-roll feel) --------
$buildupEvents = @(
 160, 'circuit_spiral',
 162, 'aimed_shot',
 164, 'pulse_radial',
 168, 'circuit_spiral',
 170, 'glitch_aimed',
 172, 'digital_cross',
 176, 'circuit_spiral',
 178, 'pulse_radial',
 180, 'glitch_aimed',
 184, 'grid_radial',
 186, 'aimed_shot',
 188, 'digital_cross',
 192, 'circuit_spiral',
 194, 'glitch_aimed',
 196, 'pulse_radial',
 200, 'grid_radial',
 202, 'aimed_shot',
 204, 'digital_cross',
 208, 'circuit_spiral',
 210, 'glitch_aimed',
 212, 'pulse_radial',
 216, 'grid_radial',
 218, 'aimed_shot',
 220, 'digital_cross',
 224, 'glitch_aimed',
 226, 'circuit_spiral'
)
for ($i = 0; $i -lt $buildupEvents.Length; $i += 2) { Add-Pattern $buildupEvents[$i] $buildupEvents[$i + 1] }

# -------- DROP: three layered patterns at the same beat = visual explosion --------
Add-Pattern 228 'grid_radial'
Add-Pattern 228 'digital_cross'
Add-Pattern 228 'glitch_aimed'

Add-Counter 232 'center' 75 4 10

# -------- MID (1:18-2:09 sustained heavy density) --------
$midEvents = @(
 248, 'pulse_radial',
 250, 'glitch_aimed',
 252, 'digital_cross',
 254, 'data_rain',
 256, 'circuit_spiral',
 258, 'pulse_radial',
 260, 'glitch_aimed',
 262, 'grid_radial',
 264, 'aimed_shot',
 266, 'digital_cross',
 268, 'circuit_spiral',
 270, 'glitch_aimed',
 272, 'pulse_radial',
 274, 'data_rain',
 276, 'digital_cross',
 278, 'circuit_spiral',
 280, 'grid_radial',
 282, 'glitch_aimed',
 284, 'pulse_radial',
 286, 'aimed_shot',
 288, 'circuit_spiral',
 290, 'digital_cross'
)
for ($i = 0; $i -lt $midEvents.Length; $i += 2) { Add-Pattern $midEvents[$i] $midEvents[$i + 1] }

Add-Counter 296 'right' 70 5 8

# -------- MID continues toward Counter 4 --------
$mid2Events = @(
 310, 'pulse_radial',
 312, 'circuit_spiral',
 314, 'data_rain',
 316, 'glitch_aimed',
 318, 'grid_radial',
 320, 'digital_cross',
 322, 'pulse_radial',
 324, 'circuit_spiral',
 326, 'glitch_aimed',
 328, 'aimed_shot',
 330, 'data_rain',
 332, 'digital_cross',
 334, 'pulse_radial',
 336, 'circuit_spiral',
 338, 'grid_radial',
 340, 'glitch_aimed',
 342, 'digital_cross',
 344, 'pulse_radial',
 346, 'circuit_spiral',
 348, 'data_rain',
 350, 'aimed_shot',
 352, 'digital_cross',
 354, 'glitch_aimed'
)
for ($i = 0; $i -lt $mid2Events.Length; $i += 2) { Add-Pattern $mid2Events[$i] $mid2Events[$i + 1] }

Add-Counter 360 'left' 70 5 8

# -------- 2ND BUILDUP/DROP (chaos, glitchy) --------
$drop2Events = @(
 374, 'surge_converging',
 376, 'glitch_aimed',
 378, 'grid_radial',
 380, 'digital_cross',
 382, 'data_rain',
 384, 'circuit_spiral',
 386, 'surge_converging',
 388, 'glitch_aimed',
 390, 'pulse_radial',
 392, 'grid_radial',
 394, 'data_rain',
 396, 'digital_cross',
 398, 'surge_converging',
 400, 'glitch_aimed',
 402, 'circuit_spiral',
 404, 'grid_radial'
)
for ($i = 0; $i -lt $drop2Events.Length; $i += 2) { Add-Pattern $drop2Events[$i] $drop2Events[$i + 1] }

# Layered second drop
Add-Pattern 405 'data_rain'
Add-Pattern 405 'surge_converging'

Add-Counter 408 'center' 70 4 10

# -------- OUTRO (strip layers, final counter) --------
Add-Pattern 424 'pulse_radial'
Add-Pattern 426 'glitch_aimed'
Add-Pattern 428 'digital_cross'
Add-Pattern 430 'pulse_radial'
Add-Pattern 432 'aimed_shot'
Add-Pattern 434 'glitch_aimed'

Add-Counter 440 'center' 75 4 10

# Boss config
$boss = [ordered]@{
  id = 'boss_05'
  name = 'PULSE'
  color = '#00e5ff'
  bpm = 175
  maxHP = 5265
  bulletDamage = 8
  counterBaseDamage = 114
  music = 'Music/techno/Restless Heart.wav'
  musicVolume = 0.85
  musicOffset = 0
  phaseThresholds = @(0.66, 0.33)
  patterns = @(
    'aimed_shot','pulse_radial','grid_radial','circuit_spiral','neon_wall',
    'glitch_aimed','digital_cross','data_rain','surge_converging'
  )
  timeline = ($timeline | Sort-Object { $_.beat })
}

$json = $boss | ConvertTo-Json -Depth 12
$out = 'c:\Users\robbc\OneDrive\Code\Rhythm\data\bosses\boss_05.json'
[System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output ("Wrote " + $out + " with " + $timeline.Count + " timeline events.")
