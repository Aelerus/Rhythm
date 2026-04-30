# Generates data/bosses/boss_06.json — APEX, the secret final boss with
# three phases (one song each).
#
#   Phase 1 — APEX.wav,                ~237s, 180 BPM, 711 beats
#   Phase 2 — Wounded Ultraviolet.wav, ~203s, 130 BPM, ~440 beats
#   Phase 3 — Apex - Phase 3.wav,      ~208s, 176 BPM, ~609 beats
#
# Difficulty curve is CONTINUOUS — Phase 2 opens at Phase 1's final-climb
# density and grows from there; Phase 3 opens at Phase 2's late-peak density.
# Each phase introduces new mechanics over time:
#   Phase 2 — phase_locked bullets (only damage during one floor color),
#             tether (beam + sliding bullets that follow the player)
#   Phase 3 — gravity_well (pulls player toward a point),
#             expanding_radial (bullets that grow over time),
#             reality_tear (stationary line that bleeds bullets perpendicularly)
#
# HP per phase = exact perfect-clear damage with a fresh combo, so a single
# GOOD or MISS in any phase = the boss survives.

$ErrorActionPreference = 'Stop'

function Perfect-Damage([int]$count, [double]$base = 38.0) {
  $sum = 0.0
  for ($i = 1; $i -le $count; $i++) {
    $mult = 1.0 + ([Math]::Min(1.0, $i / 16.0))
    $sum += $base * 1.0 * $mult
  }
  return $sum
}

function New-Phase {
  param(
    [string]$name, [string]$music, [int]$bpm, [int]$bulletDamage, [int]$hp,
    [bool]$useInversion, [bool]$redCracks, [bool]$fullRedFloor,
    [string]$bossColorMode, [bool]$fallOnDeath, [string]$startFloor, [object]$timeline
  )
  return [ordered]@{
    displayPhase = $name
    music = $music
    bpm = $bpm
    musicVolume = 0.85
    musicOffset = 0
    useInversion = $useInversion
    redCracks = $redCracks
    fullRedFloor = $fullRedFloor
    bossColorMode = $bossColorMode
    fallOnDeath = $fallOnDeath
    startFloor = $startFloor
    hp = $hp
    bulletDamage = $bulletDamage
    timeline = ($timeline | Sort-Object { $_.beat })
  }
}

# Fills a beat range with a rotating pattern pool at a fixed cadence.
function Fill-Range($list, [int]$startBeat, [int]$endBeat, [int]$cadence, [string[]]$pool) {
  $idx = 0
  for ($b = $startBeat; $b -lt $endBeat; $b += $cadence) {
    $list.Add([ordered]@{ beat=$b; type='pattern'; id=$pool[$idx % $pool.Length] })
    $idx++
  }
}

# ============================================================
# PHASE 1 — unchanged (cold above-it-all, b/w inversion)
# ============================================================
$tl1 = New-Object System.Collections.Generic.List[object]
function P1-Pat([int]$b, [string]$id) { $tl1.Add([ordered]@{ beat=$b; type='pattern'; id=$id }) }
function P1-Counter([int]$b, [string]$a, [int]$r, [int]$lead, [int]$dur) {
  $tl1.Add([ordered]@{ beat=$b; type='counterattack_window'; duration_beats=$dur; lead_beats=$lead; zone=[ordered]@{ anchor=$a; radius=$r } })
}
function P1-Invert([int]$b, [string]$to) { $tl1.Add([ordered]@{ beat=$b; type='floor_invert'; to=$to }) }

P1-Pat 16 'apex_aimed'; P1-Pat 32 'apex_mirror'; P1-Pat 48 'apex_aimed'; P1-Pat 64 'apex_burst'; P1-Pat 80 'apex_mirror'
P1-Invert 90 'black'
$build1 = @(96,'apex_aimed', 100,'apex_mirror', 104,'apex_aimed', 108,'apex_burst', 112,'apex_aimed', 116,'apex_mirror', 120,'apex_aimed', 124,'apex_radial', 128,'apex_burst', 132,'apex_aimed', 136,'apex_mirror_dense', 140,'apex_aimed')
for ($i=0; $i -lt $build1.Length; $i+=2) { P1-Pat $build1[$i] $build1[$i+1] }
P1-Counter 144 'center' 75 6 8
P1-Pat 160 'apex_aimed'; P1-Pat 164 'apex_burst'; P1-Pat 168 'apex_aimed'; P1-Pat 172 'apex_mirror'; P1-Pat 176 'apex_burst'
P1-Invert 180 'white'
$mid1 = @(184,'apex_radial', 188,'apex_aimed', 192,'apex_burst', 196,'apex_mirror_dense', 200,'apex_aimed', 204,'apex_radial', 208,'apex_echo', 212,'apex_aimed', 216,'apex_burst', 220,'apex_radial', 224,'apex_mirror_dense', 228,'apex_aimed', 232,'apex_echo', 236,'apex_burst', 240,'apex_radial', 244,'apex_aimed', 248,'apex_mirror_dense', 252,'apex_burst', 256,'apex_aimed', 260,'apex_echo', 264,'apex_radial', 268,'apex_aimed', 270,'apex_spiral', 274,'apex_burst', 278,'apex_mirror_dense', 282,'apex_aimed', 284,'apex_echo')
for ($i=0; $i -lt $mid1.Length; $i+=2) { P1-Pat $mid1[$i] $mid1[$i+1] }
P1-Invert 270 'black'
P1-Counter 288 'topRight' 70 5 8
$app1 = @(304,'apex_laser_h', 308,'apex_aimed', 312,'apex_radial', 316,'apex_laser_v', 320,'apex_burst', 324,'apex_aimed', 328,'apex_laser_h', 332,'apex_echo_wide', 336,'apex_radial', 340,'apex_burst_chaos', 344,'apex_laser_v', 348,'apex_aimed', 350,'apex_spiral', 352,'apex_radial', 356,'apex_laser_h', 358,'apex_aimed')
for ($i=0; $i -lt $app1.Length; $i+=2) { P1-Pat $app1[$i] $app1[$i+1] }
P1-Invert 360 'white'
P1-Counter 360 'center' 70 5 10
P1-Invert 384 'black'
$bk1 = @(388,'apex_stutter', 394,'apex_echo', 400,'apex_stutter', 406,'apex_echo_wide', 412,'apex_stutter', 418,'apex_mirror_dense', 424,'apex_aimed')
for ($i=0; $i -lt $bk1.Length; $i+=2) { P1-Pat $bk1[$i] $bk1[$i+1] }
P1-Invert 432 'white'
P1-Counter 432 'bottomLeft' 65 5 10
$sus1 = @(448,'apex_radial', 448,'apex_burst', 452,'apex_laser_h', 456,'apex_aimed', 460,'apex_vortex', 464,'apex_burst', 468,'apex_radial', 472,'apex_aimed', 476,'apex_laser_v', 480,'apex_mirror_dense', 484,'apex_radial', 488,'apex_burst_chaos', 492,'apex_aimed', 496,'apex_vortex', 500,'apex_radial', 504,'apex_laser_h', 508,'apex_aimed', 512,'apex_burst', 516,'apex_mirror_dense', 520,'apex_echo', 524,'apex_radial', 528,'apex_aimed', 532,'apex_burst_chaos', 536,'apex_laser_v')
for ($i=0; $i -lt $sus1.Length; $i+=2) { P1-Pat $sus1[$i] $sus1[$i+1] }
P1-Invert 504 'black'
P1-Counter 540 'right' 65 5 8
$sus1b = @(556,'apex_vortex_double', 560,'apex_laser_cross', 564,'apex_radial', 568,'apex_burst_chaos', 572,'apex_aimed', 576,'apex_echo_wide', 580,'apex_vortex', 584,'apex_mirror_dense', 588,'apex_radial', 592,'apex_laser_h', 596,'apex_burst_chaos', 600,'apex_aimed', 604,'apex_vortex', 608,'apex_radial', 612,'apex_burst_chaos', 616,'apex_aimed', 620,'apex_laser_v')
for ($i=0; $i -lt $sus1b.Length; $i+=2) { P1-Pat $sus1b[$i] $sus1b[$i+1] }
P1-Invert 576 'white'
P1-Counter 624 'topLeft' 60 5 8
P1-Invert 648 'black'
$fin1 = @(640,'apex_vortex_double', 644,'apex_laser_cross', 648,'apex_radial', 648,'apex_aimed', 652,'apex_burst_chaos', 656,'apex_mirror_dense', 660,'apex_vortex', 664,'apex_laser_h', 664,'apex_radial', 668,'apex_echo_wide', 672,'apex_burst_chaos', 676,'apex_radial', 676,'apex_aimed', 680,'apex_vortex_double', 684,'apex_laser_v')
for ($i=0; $i -lt $fin1.Length; $i+=2) { P1-Pat $fin1[$i] $fin1[$i+1] }
P1-Invert 696 'white'
P1-Counter 688 'center' 65 5 10

$phase1HP = [int](Perfect-Damage 62)  # 4427
$phase1 = New-Phase -name 'Phase 1' `
  -music 'Music/APEX.wav' -bpm 180 -bulletDamage 13 -hp $phase1HP `
  -useInversion $true -redCracks $false -fullRedFloor $false `
  -bossColorMode 'inversion' -fallOnDeath $false -startFloor 'white' -timeline $tl1

# ============================================================
# PHASE 2 — opens at Phase 1's final-climb density.
# ============================================================
$tl2 = New-Object System.Collections.Generic.List[object]
function P2-Pat([int]$b, [string]$id) { $tl2.Add([ordered]@{ beat=$b; type='pattern'; id=$id }) }
function P2-Counter([int]$b, [string]$a, [int]$r, [int]$lead, [int]$dur) {
  $tl2.Add([ordered]@{ beat=$b; type='counterattack_window'; duration_beats=$dur; lead_beats=$lead; zone=[ordered]@{ anchor=$a; radius=$r } })
}
function P2-Invert([int]$b, [string]$to) { $tl2.Add([ordered]@{ beat=$b; type='floor_invert'; to=$to }) }

# Pattern pools used for filler — each pool escalates over the phase.
$p2pool_open  = @('apex_radial','apex2_radial','apex_aimed','apex_burst','apex2_burst','apex_mirror_dense','apex_echo','apex_vortex','apex2_vortex','apex_laser_h','apex2_echo','apex_burst_chaos')
$p2pool_mid   = @('apex2_radial','apex_burst_chaos','apex2_echo','apex_mirror_dense','apex2_vortex','apex_laser_v','apex2_burst','apex_radial','apex2_phase_radial','apex_aimed','apex_vortex','apex2_laser','apex2_phase_aimed')
$p2pool_late  = @('apex2_radial','apex2_burst','apex2_vortex','apex2_phase_radial','apex2_phase_radial_b','apex2_phase_aimed','apex2_laser','apex_burst_chaos','apex_mirror_dense','apex2_echo','apex_vortex','apex_laser_cross')
$p2pool_final = @('apex2_phase_radial','apex2_phase_radial_b','apex2_phase_aimed','apex2_phase_aimed_b','apex2_radial','apex2_vortex','apex2_burst','apex_burst_chaos','apex2_laser','apex_mirror_dense','apex2_echo')

# --- Section 1 (beats 0..56): immediate Phase-1-end density --------------
Fill-Range $tl2 4 56 3 $p2pool_open
# Layered hits to start at Phase 1's final-climb intensity
P2-Pat 12 'apex_burst'
P2-Pat 28 'apex_aimed'
P2-Pat 44 'apex_mirror_dense'
# First phase_locked introduction at beat 24 — quiet, single fire
P2-Pat 24 'apex2_phase_radial'
P2-Counter 56 'center' 70 5 8

# --- Section 2 (64..112): introduces phase_locked aimed -----------------
P2-Invert 70 'black'
Fill-Range $tl2 65 112 3 $p2pool_mid
P2-Pat 84 'apex2_phase_aimed_b'   # locked to BLACK (current floor) — visible damaging
P2-Pat 100 'apex2_phase_radial_b' # locked to BLACK
P2-Counter 112 'topLeft' 65 5 8

# --- Section 3 (120..176): tether debut --------------------------------
P2-Invert 130 'white'
Fill-Range $tl2 122 176 3 $p2pool_mid
P2-Pat 136 'apex2_tether'         # FIRST tether
P2-Pat 156 'apex2_phase_radial'   # white-locked while floor IS white = active
P2-Pat 168 'apex2_phase_aimed'
P2-Counter 176 'bottomRight' 60 5 8

# --- Section 4 (184..240): tether + phase_locked layered ---------------
P2-Invert 180 'black'
Fill-Range $tl2 186 240 3 $p2pool_late
P2-Pat 196 'apex2_tether'
P2-Pat 212 'apex2_phase_aimed_b'
P2-Pat 224 'apex2_tether_long'    # long tether
P2-Counter 240 'right' 60 5 8

# --- Section 5 (250..304): peak section, dual phase_lock pressure -------
P2-Invert 250 'white'
Fill-Range $tl2 250 304 2 $p2pool_late
# Layered phase_locks: white AND black at the same beat. Half are inert.
P2-Pat 258 'apex2_phase_radial'
P2-Pat 258 'apex2_phase_radial_b'
P2-Pat 274 'apex2_phase_aimed'
P2-Pat 274 'apex2_phase_aimed_b'
P2-Pat 290 'apex2_tether'
P2-Counter 304 'topRight' 60 5 8

# --- Section 6 (314..360): post-counter density continues ---------------
P2-Invert 320 'black'
Fill-Range $tl2 314 360 2 $p2pool_late
P2-Pat 330 'apex2_phase_radial_b'
P2-Pat 346 'apex2_tether_long'
P2-Counter 360 'left' 55 5 8

# --- Section 7 (370..396): final pre-final density ----------------------
P2-Invert 372 'white'
Fill-Range $tl2 370 396 2 $p2pool_final
P2-Pat 384 'apex2_tether'
P2-Counter 396 'bottom' 55 4 10

# --- Section 8 (410..424): final stretch --------------------------------
P2-Invert 410 'black'
Fill-Range $tl2 410 424 2 $p2pool_final
P2-Counter 424 'center' 60 4 10

$phase2HP = [int](Perfect-Damage 68)  # 4883
$phase2 = New-Phase -name 'Phase 2' `
  -music 'Music/Wounded Ultraviolet.wav' -bpm 130 -bulletDamage 14 -hp $phase2HP `
  -useInversion $true -redCracks $true -fullRedFloor $false `
  -bossColorMode 'inversion' -fallOnDeath $false -startFloor 'white' -timeline $tl2

# ============================================================
# PHASE 3 — opens at Phase 2's late-peak density.
# Introduces gravity_well (early), expanding_radial (slow stretch),
# reality_tear (last-ditch ramp).
# ============================================================
$tl3 = New-Object System.Collections.Generic.List[object]
function P3-Pat([int]$b, [string]$id) { $tl3.Add([ordered]@{ beat=$b; type='pattern'; id=$id }) }
function P3-Counter([int]$b, [string]$a, [int]$r, [int]$lead, [int]$dur) {
  $tl3.Add([ordered]@{ beat=$b; type='counterattack_window'; duration_beats=$dur; lead_beats=$lead; zone=[ordered]@{ anchor=$a; radius=$r } })
}

# Phase 3 has no floor inversion — phase_locked attacks are NOT used here.
# Pools rotate phase-1 + phase-2 attacks as the baseline (continuity), and
# phase-3-specific attacks are introduced section by section.
$p3pool_open  = @('apex2_radial','apex2_burst','apex2_vortex','apex_burst_chaos','apex_mirror_dense','apex2_echo','apex_vortex','apex2_laser','apex_radial','apex_aimed')
$p3pool_grief = @('apex2_vortex','apex_burst_chaos','apex2_echo','apex3_radial','apex2_burst','apex3_vortex','apex_mirror_dense','apex3_burst')
$p3pool_slow  = @('apex_stutter','apex2_echo','apex3_expanding','apex2_vortex','apex3_burst','apex_mirror_dense','apex3_expanding_dense','apex2_radial')
$p3pool_burst = @('apex3_radial','apex3_burst','apex3_mirror','apex3_vortex','apex3_echo','apex3_stutter','apex3_laser','apex_burst_chaos','apex2_burst','apex2_vortex','apex2_radial','apex_mirror_dense')
$p3pool_peak  = @('apex3_radial','apex3_burst','apex3_vortex','apex3_laser','apex3_mirror','apex3_echo','apex3_stutter','apex3_expanding_dense','apex_burst_chaos','apex2_vortex','apex_mirror_dense')

# --- Section 1 (4..80): opens at Phase 2 late density. Well intro at b16 -
Fill-Range $tl3 4 80 3 $p3pool_open
P3-Pat 16 'apex3_well'             # FIRST gravity well
P3-Pat 36 'apex2_tether'           # carryover from phase 2
P3-Pat 60 'apex3_well_topright'
P3-Counter 80 'center' 60 5 8

# --- Section 2 (94..160): worry, well used as positional pressure -------
Fill-Range $tl3 94 160 3 $p3pool_grief
P3-Pat 108 'apex3_well_bottomleft'
P3-Pat 130 'apex2_tether_long'
P3-Pat 144 'apex3_well_strong'     # well AT the player
P3-Counter 160 'topRight' 55 5 8

# --- Section 3 (174..240): slow-deadly. expanding_radial introduced -----
P3-Pat 176 'apex3_expanding'       # FIRST expanding bullets
P3-Pat 184 'apex_stutter'
P3-Pat 192 'apex3_expanding_dense'
P3-Pat 200 'apex2_echo'
P3-Pat 208 'apex3_well'
P3-Pat 216 'apex3_expanding'
P3-Pat 224 'apex2_vortex'
P3-Pat 232 'apex3_burst'
P3-Counter 240 'bottomRight' 55 5 8

# --- Section 4 (254..320): worry intensifies ----------------------------
Fill-Range $tl3 254 320 3 $p3pool_slow
P3-Pat 270 'apex3_well_strong'
P3-Pat 286 'apex3_tear_h'          # FIRST reality tear (slow stretch end)
P3-Pat 304 'apex3_expanding_dense'
P3-Counter 320 'left' 55 5 8

# --- Section 5 (336..400): LAST-DITCH RAMP — every 2 beats, fully layered
Fill-Range $tl3 336 400 2 $p3pool_burst
P3-Pat 344 'apex3_tear_v'
P3-Pat 358 'apex3_well_strong'
P3-Pat 372 'apex3_tear_h'
P3-Pat 386 'apex3_expanding_dense'
P3-Counter 400 'topLeft' 50 5 8

# --- Section 6 (414..460): pre-peak --------------------------------------
Fill-Range $tl3 414 460 2 $p3pool_burst
P3-Pat 422 'apex3_tear_diag'
P3-Pat 436 'apex3_well_strong'
P3-Pat 448 'apex3_expanding_dense'
P3-Counter 460 'right' 50 4 8

# --- Section 7 (472..520): PEAK — every 2 beats with layered hits -------
Fill-Range $tl3 472 520 2 $p3pool_peak
P3-Pat 478 'apex3_tear_h'
P3-Pat 484 'apex3_expanding_dense'
P3-Pat 492 'apex3_well_strong'
P3-Pat 500 'apex3_tear_v'
P3-Pat 510 'apex3_tear_diag'
P3-Counter 520 'bottom' 50 4 12

# --- Section 8 (537..568): final climb to the realization moment --------
Fill-Range $tl3 537 568 2 $p3pool_peak
P3-Pat 542 'apex3_tear_h'
P3-Pat 552 'apex3_well_strong'
P3-Pat 560 'apex3_expanding_dense'
P3-Counter 568 'center' 55 5 16   # FINAL — 16 prompts of realization

$phase3HP = [int](Perfect-Damage 76)  # 5491
$phase3 = New-Phase -name 'Phase 3' `
  -music 'Music/Apex - Phase 3.wav' -bpm 176 -bulletDamage 15 -hp $phase3HP `
  -useInversion $false -redCracks $false -fullRedFloor $true `
  -bossColorMode 'drainGold' -fallOnDeath $true -startFloor 'white' -timeline $tl3

# ============================================================
$boss = [ordered]@{
  id = 'boss_06'
  name = 'APEX'
  color = '#ffffff'
  counterBaseDamage = 38
  phaseThresholds = @(0.75, 0.5, 0.25)
  phases = @($phase1, $phase2, $phase3)
}

$json = $boss | ConvertTo-Json -Depth 14
$out = 'c:\Users\robbc\Rhythm\data\bosses\boss_06.json'
[System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))

Write-Output ("Wrote " + $out)
Write-Output ("  Phase 1: HP=$phase1HP  events=" + $tl1.Count)
Write-Output ("  Phase 2: HP=$phase2HP  events=" + $tl2.Count)
Write-Output ("  Phase 3: HP=$phase3HP  events=" + $tl3.Count)
$total = $tl1.Count + $tl2.Count + $tl3.Count
Write-Output ("  Total events: $total")
$totalHP = $phase1HP + $phase2HP + $phase3HP
Write-Output ("  Total perfect-clear damage required: $totalHP")
