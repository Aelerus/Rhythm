# Generates data/bosses/boss_06.json — APEX, the secret final boss with
# three phases (one song each).
#
#   Phase 1 — APEX.wav,                ~237s, 180 BPM, 711 beats
#   Phase 2 — Wounded Ultraviolet.wav, ~203s, 130 BPM, ~440 beats
#   Phase 3 — Apex - Phase 3.wav,      ~208s, 176 BPM, ~609 beats
#
# HP per phase is set to the EXACT damage sum of a flawless run in that
# phase, so missing a single PERFECT (or breaking combo) anywhere in the
# fight = the boss survives. Combo resets between phases.

$ErrorActionPreference = 'Stop'

# Returns the cumulative-perfect-damage from `count` PERFECT prompts in a row,
# starting with combo 1 (combo grows 1..16 then caps at 2x).
function Perfect-Damage([int]$count, [double]$base = 38.0) {
  $sum = 0.0
  for ($i = 1; $i -le $count; $i++) {
    $mult = 1.0 + ([Math]::Min(1.0, $i / 16.0))
    $sum += $base * 1.0 * $mult
  }
  return $sum
}

# Helper to build a phase timeline.
function New-Phase {
  param(
    [string]$name,
    [string]$music,
    [int]$bpm,
    [int]$bulletDamage,
    [int]$hp,
    [bool]$useInversion,
    [bool]$redCracks,
    [bool]$fullRedFloor,
    [string]$bossColorMode,
    [bool]$fallOnDeath,
    [string]$startFloor,
    [object]$timeline
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

# ============================================================
# PHASE 1 — APEX (cold above-it-all, b/w inversion)
# ============================================================
$tl1 = New-Object System.Collections.Generic.List[object]
function P1-Pat([int]$b, [string]$id) { $tl1.Add([ordered]@{ beat=$b; type='pattern'; id=$id }) }
function P1-Counter([int]$b, [string]$a, [int]$r, [int]$lead, [int]$dur) {
  $tl1.Add([ordered]@{ beat=$b; type='counterattack_window'; duration_beats=$dur; lead_beats=$lead; zone=[ordered]@{ anchor=$a; radius=$r } })
}
function P1-Invert([int]$b, [string]$to) { $tl1.Add([ordered]@{ beat=$b; type='floor_invert'; to=$to }) }

# Intro
P1-Pat 16 'apex_aimed'; P1-Pat 32 'apex_mirror'; P1-Pat 48 'apex_aimed'; P1-Pat 64 'apex_burst'; P1-Pat 80 'apex_mirror'
P1-Invert 90 'black'

# Build
$build1 = @(96,'apex_aimed', 100,'apex_mirror', 104,'apex_aimed', 108,'apex_burst', 112,'apex_aimed', 116,'apex_mirror', 120,'apex_aimed', 124,'apex_radial', 128,'apex_burst', 132,'apex_aimed', 136,'apex_mirror_dense', 140,'apex_aimed')
for ($i=0; $i -lt $build1.Length; $i+=2) { P1-Pat $build1[$i] $build1[$i+1] }
P1-Counter 144 'center' 75 6 8

# Post-counter
P1-Pat 160 'apex_aimed'; P1-Pat 164 'apex_burst'; P1-Pat 168 'apex_aimed'; P1-Pat 172 'apex_mirror'; P1-Pat 176 'apex_burst'
P1-Invert 180 'white'

# Mid-build
$mid1 = @(184,'apex_radial', 188,'apex_aimed', 192,'apex_burst', 196,'apex_mirror_dense', 200,'apex_aimed', 204,'apex_radial', 208,'apex_echo', 212,'apex_aimed', 216,'apex_burst', 220,'apex_radial', 224,'apex_mirror_dense', 228,'apex_aimed', 232,'apex_echo', 236,'apex_burst', 240,'apex_radial', 244,'apex_aimed', 248,'apex_mirror_dense', 252,'apex_burst', 256,'apex_aimed', 260,'apex_echo', 264,'apex_radial', 268,'apex_aimed', 270,'apex_spiral', 274,'apex_burst', 278,'apex_mirror_dense', 282,'apex_aimed', 284,'apex_echo')
for ($i=0; $i -lt $mid1.Length; $i+=2) { P1-Pat $mid1[$i] $mid1[$i+1] }
P1-Invert 270 'black'
P1-Counter 288 'topRight' 70 5 8

# Approach Peak 1
$app1 = @(304,'apex_laser_h', 308,'apex_aimed', 312,'apex_radial', 316,'apex_laser_v', 320,'apex_burst', 324,'apex_aimed', 328,'apex_laser_h', 332,'apex_echo_wide', 336,'apex_radial', 340,'apex_burst_chaos', 344,'apex_laser_v', 348,'apex_aimed', 350,'apex_spiral', 352,'apex_radial', 356,'apex_laser_h', 358,'apex_aimed')
for ($i=0; $i -lt $app1.Length; $i+=2) { P1-Pat $app1[$i] $app1[$i+1] }
P1-Invert 360 'white'
P1-Counter 360 'center' 70 5 10

# Breakdown
P1-Invert 384 'black'
$bk1 = @(388,'apex_stutter', 394,'apex_echo', 400,'apex_stutter', 406,'apex_echo_wide', 412,'apex_stutter', 418,'apex_mirror_dense', 424,'apex_aimed')
for ($i=0; $i -lt $bk1.Length; $i+=2) { P1-Pat $bk1[$i] $bk1[$i+1] }

# Post-breakdown
P1-Invert 432 'white'
P1-Counter 432 'bottomLeft' 65 5 10

# Sustained max
$sus1 = @(448,'apex_radial', 448,'apex_burst', 452,'apex_laser_h', 456,'apex_aimed', 460,'apex_vortex', 464,'apex_burst', 468,'apex_radial', 472,'apex_aimed', 476,'apex_laser_v', 480,'apex_mirror_dense', 484,'apex_radial', 488,'apex_burst_chaos', 492,'apex_aimed', 496,'apex_vortex', 500,'apex_radial', 504,'apex_laser_h', 508,'apex_aimed', 512,'apex_burst', 516,'apex_mirror_dense', 520,'apex_echo', 524,'apex_radial', 528,'apex_aimed', 532,'apex_burst_chaos', 536,'apex_laser_v')
for ($i=0; $i -lt $sus1.Length; $i+=2) { P1-Pat $sus1[$i] $sus1[$i+1] }
P1-Invert 504 'black'
P1-Counter 540 'right' 65 5 8

# Sustained high
$sus1b = @(556,'apex_vortex_double', 560,'apex_laser_cross', 564,'apex_radial', 568,'apex_burst_chaos', 572,'apex_aimed', 576,'apex_echo_wide', 580,'apex_vortex', 584,'apex_mirror_dense', 588,'apex_radial', 592,'apex_laser_h', 596,'apex_burst_chaos', 600,'apex_aimed', 604,'apex_vortex', 608,'apex_radial', 612,'apex_burst_chaos', 616,'apex_aimed', 620,'apex_laser_v')
for ($i=0; $i -lt $sus1b.Length; $i+=2) { P1-Pat $sus1b[$i] $sus1b[$i+1] }
P1-Invert 576 'white'
P1-Counter 624 'topLeft' 60 5 8

# Final climb
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
# PHASE 2 — WOUNDED ULTRAVIOLET (red cracks grow with HP loss)
# Song: 130 BPM, ~440 beats. 8 counters totaling 68 prompts.
# Mechanics: keeps b/w inversion, red cracks reveal as damage taken.
# ============================================================
$tl2 = New-Object System.Collections.Generic.List[object]
function P2-Pat([int]$b, [string]$id) { $tl2.Add([ordered]@{ beat=$b; type='pattern'; id=$id }) }
function P2-Counter([int]$b, [string]$a, [int]$r, [int]$lead, [int]$dur) {
  $tl2.Add([ordered]@{ beat=$b; type='counterattack_window'; duration_beats=$dur; lead_beats=$lead; zone=[ordered]@{ anchor=$a; radius=$r } })
}
function P2-Invert([int]$b, [string]$to) { $tl2.Add([ordered]@{ beat=$b; type='floor_invert'; to=$to }) }

# Open: rage from Phase 2's "you dared" — patterns hit hard from bar 1.
P2-Pat 4 'apex_radial'
P2-Pat 8 'apex2_radial'
P2-Pat 12 'apex_aimed'
P2-Pat 16 'apex2_burst'
P2-Pat 20 'apex_mirror_dense'
P2-Pat 24 'apex_radial'
P2-Pat 28 'apex2_echo'
P2-Pat 32 'apex_burst'
P2-Pat 36 'apex_aimed'
P2-Pat 40 'apex2_radial'
P2-Pat 44 'apex_burst_chaos'
P2-Pat 48 'apex2_echo'
P2-Pat 52 'apex_aimed'
P2-Counter 56 'center' 70 5 8

# Mid build with floor inversions
P2-Invert 70 'black'
P2-Pat 72 'apex_radial'
P2-Pat 76 'apex2_burst'
P2-Pat 80 'apex_aimed'
P2-Pat 84 'apex_mirror_dense'
P2-Pat 88 'apex2_radial'
P2-Pat 92 'apex_burst_chaos'
P2-Pat 96 'apex_aimed'
P2-Pat 100 'apex2_echo'
P2-Pat 104 'apex2_burst'
P2-Pat 108 'apex_aimed'
P2-Counter 112 'topLeft' 65 5 8

# Section approaching peak 1 — lasers reintroduced
P2-Invert 130 'white'
P2-Pat 128 'apex2_laser'
P2-Pat 132 'apex_aimed'
P2-Pat 136 'apex_radial'
P2-Pat 140 'apex_laser_v'
P2-Pat 144 'apex2_burst'
P2-Pat 148 'apex_aimed'
P2-Pat 152 'apex2_laser'
P2-Pat 156 'apex2_echo'
P2-Pat 160 'apex_burst_chaos'
P2-Pat 164 'apex_radial'
P2-Pat 168 'apex_aimed'
P2-Pat 172 'apex2_vortex'
P2-Counter 176 'bottomRight' 60 5 8

# Pre-peak
P2-Invert 180 'black'
P2-Pat 192 'apex_radial'; P2-Pat 192 'apex_burst'
P2-Pat 196 'apex2_laser'
P2-Pat 200 'apex_aimed'
P2-Pat 204 'apex2_vortex'
P2-Pat 208 'apex_burst_chaos'
P2-Pat 212 'apex_aimed'
P2-Pat 216 'apex2_radial'
P2-Pat 220 'apex_mirror_dense'
P2-Pat 224 'apex2_echo'
P2-Pat 228 'apex_aimed'
P2-Pat 232 'apex2_burst'
P2-Pat 236 'apex_laser_h'
P2-Counter 240 'right' 60 5 8

# At-peak: heaviest density. Layered events.
P2-Invert 250 'white'
P2-Pat 256 'apex2_radial'; P2-Pat 256 'apex_aimed'
P2-Pat 260 'apex2_vortex'
P2-Pat 264 'apex2_laser'
P2-Pat 268 'apex_burst_chaos'
P2-Pat 272 'apex_aimed'
P2-Pat 276 'apex2_burst'
P2-Pat 280 'apex_mirror_dense'
P2-Pat 284 'apex2_echo'
P2-Pat 288 'apex_radial'
P2-Pat 292 'apex2_laser'
P2-Pat 296 'apex_aimed'
P2-Pat 300 'apex2_vortex'
P2-Counter 304 'topRight' 60 5 8

# The brief "wound hurts" breakdown around 2:08-2:22 → beats 270-282 in 130 BPM (already passed)
# Actually 2:25-2:35 → beats 292-305
# Let me drop the local density right before counter 5 → counter 5 is the breakdown counter (gentler)

# Post-breakdown drop section
P2-Invert 320 'black'
P2-Pat 320 'apex_burst_chaos'; P2-Pat 320 'apex2_radial'
P2-Pat 324 'apex2_vortex'
P2-Pat 328 'apex2_laser'
P2-Pat 332 'apex_aimed'
P2-Pat 336 'apex_mirror_dense'
P2-Pat 340 'apex2_burst'
P2-Pat 344 'apex_radial'
P2-Pat 348 'apex2_echo'
P2-Pat 352 'apex_aimed'
P2-Pat 356 'apex_burst_chaos'
P2-Counter 360 'left' 55 5 8

# Sustained final
P2-Invert 372 'white'
P2-Pat 364 'apex2_vortex'
P2-Pat 368 'apex_aimed'
P2-Pat 372 'apex2_laser'
P2-Pat 376 'apex_burst_chaos'
P2-Pat 380 'apex_mirror_dense'
P2-Pat 384 'apex2_radial'
P2-Pat 388 'apex2_burst'
P2-Pat 392 'apex2_echo'
P2-Counter 396 'bottom' 55 4 10

# Final stretch — final counter at 424
P2-Invert 410 'black'
P2-Pat 410 'apex2_vortex'
P2-Pat 414 'apex_burst_chaos'
P2-Pat 418 'apex2_laser'
P2-Pat 422 'apex2_radial'
P2-Counter 424 'center' 60 4 10

$phase2HP = [int](Perfect-Damage 68)  # 4883
$phase2 = New-Phase -name 'Phase 2' `
  -music 'Music/Wounded Ultraviolet.wav' -bpm 130 -bulletDamage 14 -hp $phase2HP `
  -useInversion $true -redCracks $true -fullRedFloor $false `
  -bossColorMode 'inversion' -fallOnDeath $false -startFloor 'white' -timeline $tl2

# ============================================================
# PHASE 3 — APEX PHASE 3 (full red, gold->grey boss, fall-off-screen death)
# Song: 176 BPM, ~609 beats. 9 counters totaling 76 prompts.
# Emotional arc: sad → worry → last-ditch → realization (all in one fight).
# ============================================================
$tl3 = New-Object System.Collections.Generic.List[object]
function P3-Pat([int]$b, [string]$id) { $tl3.Add([ordered]@{ beat=$b; type='pattern'; id=$id }) }
function P3-Counter([int]$b, [string]$a, [int]$r, [int]$lead, [int]$dur) {
  $tl3.Add([ordered]@{ beat=$b; type='counterattack_window'; duration_beats=$dur; lead_beats=$lead; zone=[ordered]@{ anchor=$a; radius=$r } })
}

# Opening (slow grief, sparse)
P3-Pat 16 'apex_aimed'
P3-Pat 32 'apex_mirror'
P3-Pat 48 'apex_burst'
P3-Pat 64 'apex_aimed'
P3-Counter 80 'center' 65 5 8

# Worry / building
P3-Pat 96 'apex2_echo'
P3-Pat 104 'apex_radial'
P3-Pat 112 'apex_aimed'
P3-Pat 120 'apex2_burst'
P3-Pat 128 'apex_stutter'
P3-Pat 136 'apex_aimed'
P3-Pat 144 'apex2_radial'
P3-Counter 160 'topRight' 60 5 8

# Slow-deadly stretch (sparse but hard)
P3-Pat 176 'apex_stutter'
P3-Pat 188 'apex2_echo'
P3-Pat 200 'apex2_vortex'
P3-Pat 212 'apex2_burst'
P3-Pat 224 'apex_mirror_dense'
P3-Counter 240 'bottomRight' 55 5 8

# Worry intensifies
P3-Pat 256 'apex2_radial'
P3-Pat 264 'apex_burst_chaos'
P3-Pat 272 'apex_aimed'
P3-Pat 280 'apex2_vortex'
P3-Pat 288 'apex_laser_h'
P3-Pat 296 'apex2_echo'
P3-Pat 304 'apex_radial'
P3-Pat 312 'apex_aimed'
P3-Counter 320 'left' 55 5 8

# Last-ditch ramp (FAST: pattern every 2 beats with layers)
P3-Pat 336 'apex3_radial'
P3-Pat 338 'apex3_burst'
P3-Pat 340 'apex3_mirror'
P3-Pat 342 'apex_aimed'
P3-Pat 344 'apex3_laser'
P3-Pat 346 'apex3_vortex'
P3-Pat 348 'apex3_echo'
P3-Pat 350 'apex3_stutter'
P3-Pat 352 'apex3_radial'
P3-Pat 354 'apex3_burst'
P3-Pat 356 'apex_burst_chaos'
P3-Pat 358 'apex3_mirror'
P3-Pat 360 'apex_laser_v'
P3-Pat 362 'apex_aimed'
P3-Pat 364 'apex3_vortex'
P3-Pat 366 'apex3_burst'
P3-Pat 368 'apex_radial'
P3-Pat 370 'apex3_echo'
P3-Pat 372 'apex3_stutter'
P3-Pat 374 'apex3_radial'
P3-Pat 376 'apex_burst_chaos'
P3-Pat 378 'apex3_laser'
P3-Pat 380 'apex_mirror_dense'
P3-Pat 382 'apex3_burst'
P3-Pat 384 'apex_aimed'
P3-Pat 386 'apex3_radial'
P3-Pat 388 'apex_laser_h'
P3-Pat 390 'apex3_mirror'
P3-Pat 392 'apex3_vortex'
P3-Pat 394 'apex3_echo'
P3-Pat 396 'apex3_burst'
P3-Counter 400 'topLeft' 50 5 8

# Pre-peak
P3-Pat 416 'apex3_radial'; P3-Pat 416 'apex3_burst'
P3-Pat 420 'apex3_laser'
P3-Pat 424 'apex_burst_chaos'
P3-Pat 428 'apex3_vortex'
P3-Pat 432 'apex3_mirror'
P3-Pat 436 'apex_aimed'
P3-Pat 440 'apex3_echo'
P3-Pat 444 'apex3_burst'
P3-Pat 448 'apex_laser_v'
P3-Pat 452 'apex3_radial'
P3-Pat 456 'apex_mirror_dense'
P3-Counter 460 'right' 50 4 8

# Peak: hardest moment of the song — every pattern, every beat
P3-Pat 472 'apex3_radial'; P3-Pat 472 'apex3_burst'
P3-Pat 474 'apex3_laser'
P3-Pat 476 'apex3_vortex'
P3-Pat 478 'apex_burst_chaos'
P3-Pat 480 'apex3_mirror'
P3-Pat 482 'apex3_echo'
P3-Pat 484 'apex3_burst'
P3-Pat 486 'apex_laser_h'
P3-Pat 488 'apex3_radial'
P3-Pat 490 'apex3_stutter'
P3-Pat 492 'apex_burst_chaos'
P3-Pat 494 'apex3_vortex'
P3-Pat 496 'apex3_burst'
P3-Pat 498 'apex_radial'
P3-Pat 500 'apex3_laser'
P3-Pat 502 'apex3_mirror'
P3-Pat 504 'apex3_echo'
P3-Pat 506 'apex_burst_chaos'
P3-Pat 508 'apex3_burst'
P3-Pat 510 'apex3_radial'
P3-Pat 512 'apex_laser_v'
P3-Pat 514 'apex3_vortex'
P3-Pat 516 'apex3_mirror'
P3-Counter 520 'bottom' 50 4 12

# Final climb
P3-Pat 536 'apex3_radial'; P3-Pat 536 'apex3_burst'
P3-Pat 540 'apex3_laser'
P3-Pat 544 'apex3_vortex'
P3-Pat 548 'apex3_echo'
P3-Pat 552 'apex_burst_chaos'
P3-Pat 556 'apex3_radial'
P3-Pat 560 'apex3_burst'
P3-Pat 564 'apex3_mirror'

# Final counter — the realization moment, lead 5 dur 16 → ends at beat 589
P3-Counter 568 'center' 55 5 16

# After 589 the song trails off and the death-fall plays as the boss falls.

$phase3HP = [int](Perfect-Damage 76)  # 5491
$phase3 = New-Phase -name 'Phase 3' `
  -music 'Music/Apex - Phase 3.wav' -bpm 176 -bulletDamage 15 -hp $phase3HP `
  -useInversion $false -redCracks $false -fullRedFloor $true `
  -bossColorMode 'drainGold' -fallOnDeath $true -startFloor 'white' -timeline $tl3

# ============================================================
# Final boss object
# ============================================================
$boss = [ordered]@{
  id = 'boss_06'
  name = 'APEX'
  color = '#ffffff'
  counterBaseDamage = 38
  phaseThresholds = @(0.75, 0.5, 0.25)  # legacy field; not used by multi-phase
  phases = @($phase1, $phase2, $phase3)
}

$json = $boss | ConvertTo-Json -Depth 14
$out = 'c:\Users\robbc\Rhythm\data\bosses\boss_06.json'
[System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))

$total = $tl1.Count + $tl2.Count + $tl3.Count
Write-Output ("Wrote " + $out)
Write-Output ("  Phase 1: HP=$phase1HP  events=" + $tl1.Count)
Write-Output ("  Phase 2: HP=$phase2HP  events=" + $tl2.Count)
Write-Output ("  Phase 3: HP=$phase3HP  events=" + $tl3.Count)
Write-Output ("  Total events: $total")
$totalHP = $phase1HP + $phase2HP + $phase3HP
Write-Output ("  Total perfect-clear damage required: $totalHP")
