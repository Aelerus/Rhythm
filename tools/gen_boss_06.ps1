# Generates data/bosses/boss_06.json -- "APEX", the secret final boss.
# Timed to APEX.wav (~237s) at 180 BPM (~711 beats). Includes:
#   - Black/white floor inversion events (10 across the song)
#   - 7 counter windows aligned to drops/breakdowns
#   - Layered unique attack types: mirror_path, arena_burst, vortex, echo,
#     laser_line, stutter_aim — none of which appear in any other level.

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

function Add-FloorInvert([int]$beat, [string]$to) {
  $timeline.Add([ordered]@{
    beat = $beat
    type = 'floor_invert'
    to = $to
  })
}

# ===== INTRO 0-30s (beats 0-90) =====
# Sparse, all telegraphed. Teaches the mechanics quietly.
Add-Pattern 16 'apex_aimed'
Add-Pattern 32 'apex_mirror'
Add-Pattern 48 'apex_aimed'
Add-Pattern 64 'apex_burst'
Add-Pattern 80 'apex_mirror'

# First inversion: end of atmospheric intro
Add-FloorInvert 90 'black'

# ===== BUILD 30-48s (beats 90-144) =====
$build = @(
   96, 'apex_aimed',
  100, 'apex_mirror',
  104, 'apex_aimed',
  108, 'apex_burst',
  112, 'apex_aimed',
  116, 'apex_mirror',
  120, 'apex_aimed',
  124, 'apex_radial',
  128, 'apex_burst',
  132, 'apex_aimed',
  136, 'apex_mirror_dense',
  140, 'apex_aimed'
)
for ($i = 0; $i -lt $build.Length; $i += 2) { Add-Pattern $build[$i] $build[$i + 1] }

Add-Counter 144 'center' 75 6 8

# ===== Post-counter into mid-build (beats 158-180) =====
Add-Pattern 160 'apex_aimed'
Add-Pattern 164 'apex_burst'
Add-Pattern 168 'apex_aimed'
Add-Pattern 172 'apex_mirror'
Add-Pattern 176 'apex_burst'

Add-FloorInvert 180 'white'

# ===== MID-BUILD 60-96s (beats 180-288) =====
$mid = @(
  184, 'apex_radial',
  188, 'apex_aimed',
  192, 'apex_burst',
  196, 'apex_mirror_dense',
  200, 'apex_aimed',
  204, 'apex_radial',
  208, 'apex_echo',
  212, 'apex_aimed',
  216, 'apex_burst',
  220, 'apex_radial',
  224, 'apex_mirror_dense',
  228, 'apex_aimed',
  232, 'apex_echo',
  236, 'apex_burst',
  240, 'apex_radial',
  244, 'apex_aimed',
  248, 'apex_mirror_dense',
  252, 'apex_burst',
  256, 'apex_aimed',
  260, 'apex_echo',
  264, 'apex_radial',
  268, 'apex_aimed',
  270, 'apex_spiral',
  274, 'apex_burst',
  278, 'apex_mirror_dense',
  282, 'apex_aimed',
  284, 'apex_echo'
)
for ($i = 0; $i -lt $mid.Length; $i += 2) { Add-Pattern $mid[$i] $mid[$i + 1] }

Add-FloorInvert 270 'black'

Add-Counter 288 'topRight' 70 5 8

# ===== APPROACH PEAK 1 (beats 304-360, 100-120s) =====
# Lasers debut. Density rises steeply.
$approach = @(
  304, 'apex_laser_h',
  308, 'apex_aimed',
  312, 'apex_radial',
  316, 'apex_laser_v',
  320, 'apex_burst',
  324, 'apex_aimed',
  328, 'apex_laser_h',
  332, 'apex_echo_wide',
  336, 'apex_radial',
  340, 'apex_burst_chaos',
  344, 'apex_laser_v',
  348, 'apex_aimed',
  350, 'apex_spiral',
  352, 'apex_radial',
  356, 'apex_laser_h',
  358, 'apex_aimed'
)
for ($i = 0; $i -lt $approach.Length; $i += 2) { Add-Pattern $approach[$i] $approach[$i + 1] }

# PEAK 1 DROP — counter + inversion to white
Add-FloorInvert 360 'white'
Add-Counter 360 'center' 70 5 10

# ===== BREAKDOWN 128-142s (beats 384-426) =====
# Slow, deadly. Stutter + echo make every move risky.
Add-FloorInvert 384 'black'

$breakdown = @(
  388, 'apex_stutter',
  394, 'apex_echo',
  400, 'apex_stutter',
  406, 'apex_echo_wide',
  412, 'apex_stutter',
  418, 'apex_mirror_dense',
  424, 'apex_aimed'
)
for ($i = 0; $i -lt $breakdown.Length; $i += 2) { Add-Pattern $breakdown[$i] $breakdown[$i + 1] }

# POST-BREAKDOWN DROP — counter + inversion to white
Add-FloorInvert 432 'white'
Add-Counter 432 'bottomLeft' 65 5 10

# ===== SUSTAINED MAX 144-180s (beats 446-540) =====
# Full assault — all patterns layered.
$sustain = @(
  448, 'apex_radial',
  448, 'apex_burst',
  452, 'apex_laser_h',
  456, 'apex_aimed',
  460, 'apex_vortex',
  464, 'apex_burst',
  468, 'apex_radial',
  472, 'apex_aimed',
  476, 'apex_laser_v',
  480, 'apex_mirror_dense',
  484, 'apex_radial',
  488, 'apex_burst_chaos',
  492, 'apex_aimed',
  496, 'apex_vortex',
  500, 'apex_radial',
  504, 'apex_laser_h',
  508, 'apex_aimed',
  512, 'apex_burst',
  516, 'apex_mirror_dense',
  520, 'apex_echo',
  524, 'apex_radial',
  528, 'apex_aimed',
  532, 'apex_burst_chaos',
  536, 'apex_laser_v'
)
for ($i = 0; $i -lt $sustain.Length; $i += 2) { Add-Pattern $sustain[$i] $sustain[$i + 1] }

Add-FloorInvert 504 'black'

Add-Counter 540 'right' 65 5 8

# ===== SUSTAINED HIGH 184-208s (beats 552-624) =====
$sustain2 = @(
  556, 'apex_vortex_double',
  560, 'apex_laser_cross',
  564, 'apex_radial',
  568, 'apex_burst_chaos',
  572, 'apex_aimed',
  576, 'apex_echo_wide',
  580, 'apex_vortex',
  584, 'apex_mirror_dense',
  588, 'apex_radial',
  592, 'apex_laser_h',
  596, 'apex_burst_chaos',
  600, 'apex_aimed',
  604, 'apex_vortex',
  608, 'apex_radial',
  612, 'apex_burst_chaos',
  616, 'apex_aimed',
  620, 'apex_laser_v'
)
for ($i = 0; $i -lt $sustain2.Length; $i += 2) { Add-Pattern $sustain2[$i] $sustain2[$i + 1] }

Add-FloorInvert 576 'white'

Add-Counter 624 'topLeft' 60 5 8

# ===== FINAL CLIMB (beats 640-688, 213-229s) =====
# Maximum density. Layered hits every other beat.
Add-FloorInvert 648 'black'

$final = @(
  640, 'apex_vortex_double',
  644, 'apex_laser_cross',
  648, 'apex_radial',
  648, 'apex_aimed',
  652, 'apex_burst_chaos',
  656, 'apex_mirror_dense',
  660, 'apex_vortex',
  664, 'apex_laser_h',
  664, 'apex_radial',
  668, 'apex_echo_wide',
  672, 'apex_burst_chaos',
  676, 'apex_radial',
  676, 'apex_aimed',
  680, 'apex_vortex_double',
  684, 'apex_laser_v'
)
for ($i = 0; $i -lt $final.Length; $i += 2) { Add-Pattern $final[$i] $final[$i + 1] }

# FINAL COUNTER — biggest, the climax of the whole game
# At beat 688, lead 5, dur 10 → ends at beat 703. Song ends ~711, leaves 8 beats of dry outro.
Add-FloorInvert 696 'white'
Add-Counter 688 'center' 65 5 10

# --- HP tuned for exact perfect-only-clear ----------------------------
# 7 counter windows, prompts = 8+8+10+10+8+8+10 = 62 total.
# Combo grows over the first 16 prompts, capping at 2x. Perfect chain:
#   prompts 1..16: 38 * sum(1 + i/16) = 38 * 24.5 = 931
#   prompts 17..62 (46 at 2x): 46 * 76 = 3496
# Sum: 4427. Set HP exactly = 4427 so a single GOOD or MISS = loss.
$boss = [ordered]@{
  id = 'boss_06'
  name = 'APEX'
  color = '#ffffff'
  bpm = 180
  maxHP = 4427
  bulletDamage = 13
  counterBaseDamage = 38
  music = 'Music/APEX.wav'
  musicVolume = 0.85
  musicOffset = 0
  phaseThresholds = @(0.75, 0.5, 0.25)
  displayPhase = 'Phase 1'
  useInversion = $true
  startFloor = 'white'
  patterns = @(
    'apex_aimed','apex_radial','apex_spiral','apex_mirror','apex_mirror_dense',
    'apex_burst','apex_burst_chaos','apex_vortex','apex_vortex_double',
    'apex_echo','apex_echo_wide','apex_laser_h','apex_laser_v','apex_laser_cross',
    'apex_stutter'
  )
  timeline = ($timeline | Sort-Object { $_.beat })
}

$json = $boss | ConvertTo-Json -Depth 12
$out = 'c:\Users\robbc\Rhythm\data\bosses\boss_06.json'
[System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output ("Wrote " + $out + " with " + $timeline.Count + " timeline events.")
