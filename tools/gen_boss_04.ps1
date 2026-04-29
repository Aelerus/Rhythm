# Generates data/bosses/boss_04.json -- a long, very-hard fight timed to
# the song "Eien Chi Afurueru" at 185 BPM (~272s = ~838 beats).
#
# Design intent:
#   - 4 escalating phases (HP thresholds 75/50/25)
#   - 10 counterattack windows; each requires entering a parry circle
#   - Layered patterns during dodge phases for high bullet density
#   - Counter zones cycle around the arena to force movement

$ErrorActionPreference = 'Stop'

$timeline = New-Object System.Collections.Generic.List[object]

function Add-Pattern([int]$beat, [string]$id) {
  $timeline.Add([ordered]@{ beat = $beat; type = 'pattern'; id = $id })
}

function Add-Counter([int]$beat, [string]$anchor, [int]$radius = 60, [int]$leadBeats = 3, [int]$durationBeats = 8) {
  $timeline.Add([ordered]@{
    beat = $beat
    type = 'counterattack_window'
    duration_beats = $durationBeats
    lead_beats = $leadBeats
    zone = [ordered]@{ anchor = $anchor; radius = $radius }
  })
}

# Section schedule (open-beat of each counter window).
# Patterns must end at least 4 beats before each open-beat so the field clears.
# 10 counter windows. Smaller circles + shorter leads make finding the parry
# zone in time genuinely punishing. The radius shrinks as the song escalates.
$counters = @(
  @{ beat =  64; anchor = 'center';      lead = 4; dur = 8;  radius = 70 }
  @{ beat = 144; anchor = 'topLeft';     lead = 4; dur = 8;  radius = 65 }
  @{ beat = 224; anchor = 'bottomRight'; lead = 4; dur = 8;  radius = 60 }
  @{ beat = 304; anchor = 'right';       lead = 3; dur = 8;  radius = 60 }
  @{ beat = 384; anchor = 'topRight';    lead = 3; dur = 8;  radius = 55 }
  @{ beat = 464; anchor = 'bottom';      lead = 3; dur = 8;  radius = 55 }
  @{ beat = 544; anchor = 'left';        lead = 3; dur = 8;  radius = 50 }
  @{ beat = 624; anchor = 'top';         lead = 3; dur = 8;  radius = 50 }
  @{ beat = 704; anchor = 'bottomLeft';  lead = 4; dur = 10; radius = 50 }
  @{ beat = 800; anchor = 'center';      lead = 5; dur = 12; radius = 60 }
)

# Phrase libraries per section (each phrase is 8 beats long; emits a list of (offset, patternId)).
# Each phrase is 8 beats. Density grows from a couple of events to nearly one
# per beat in the bridge. The "comma-prefix" (,(...)) returns the array as one
# value rather than splatting it.
function Phrase-Sparse {
  ,(@{o=0;id='aimed_shot'},@{o=2;id='cross'},@{o=4;id='aimed_shot'},@{o=6;id='pulse_aimed'})
}
function Phrase-Intro {
  ,(@{o=0;id='aimed_shot'},@{o=2;id='wide_wall'},@{o=3;id='cross'},@{o=4;id='pulse_aimed'},@{o=6;id='aimed_shot'},@{o=7;id='spiral'})
}
function Phrase-Verse1 {
  ,(@{o=0;id='wide_wall'},@{o=2;id='pulse_aimed'},@{o=3;id='cross'},@{o=4;id='vein_radial'},@{o=6;id='spiral'},@{o=7;id='aimed_shot'})
}
function Phrase-Verse1B {
  ,(@{o=0;id='vein_radial'},@{o=2;id='spiral'},@{o=3;id='wide_wall'},@{o=4;id='pulse_aimed'},@{o=5;id='aimed_shot'},@{o=7;id='crimson_rain'})
}
function Phrase-PreChorus {
  ,(@{o=0;id='vein_radial'},@{o=1;id='pulse_aimed'},@{o=2;id='bleed_spiral'},@{o=4;id='crimson_wall'},@{o=5;id='blood_homing'},@{o=6;id='aimed_shot'},@{o=7;id='dread_converging'})
}
function Phrase-Chorus1 {
  ,(@{o=0;id='vein_radial'},@{o=1;id='crimson_fan'},@{o=2;id='slash_cross'},@{o=3;id='pulse_aimed'},@{o=4;id='crimson_wall'},@{o=5;id='bleed_spiral'},@{o=6;id='crimson_rain'},@{o=7;id='shred_cross'})
}
function Phrase-Chorus1B {
  ,(@{o=0;id='crimson_wall'},@{o=1;id='bleed_spiral'},@{o=2;id='vein_radial'},@{o=3;id='slash_cross'},@{o=4;id='dread_converging'},@{o=5;id='pulse_aimed'},@{o=6;id='crimson_fan'},@{o=7;id='blood_homing'})
}
function Phrase-Verse2 {
  ,(@{o=0;id='storm_spiral'},@{o=1;id='pulse_aimed'},@{o=2;id='needle_wall'},@{o=3;id='crimson_fan'},@{o=4;id='swarm_homing'},@{o=5;id='slash_cross'},@{o=6;id='vein_radial'},@{o=7;id='crimson_rain'})
}
function Phrase-Verse2B {
  ,(@{o=0;id='flood_radial'},@{o=1;id='pulse_aimed'},@{o=2;id='shred_cross'},@{o=3;id='storm_spiral'},@{o=4;id='dread_converging'},@{o=5;id='crimson_fan'},@{o=6;id='needle_wall'},@{o=7;id='swarm_homing'})
}
function Phrase-Bridge {
  ,(@{o=0;id='carnage_radial'},@{o=1;id='shred_cross'},@{o=2;id='crimson_fan'},@{o=3;id='storm_spiral'},@{o=4;id='blood_storm'},@{o=5;id='pulse_aimed'},@{o=6;id='needle_wall'},@{o=7;id='swarm_homing'})
}

# Section schedule: ranges of beats and which phrase generator to use, repeated.
# (startBeat, endBeatExclusive, phraseFunc)
$sections = @(
  @{ start =   4; endX =  64; func = 'Phrase-Sparse'     }
  @{ start =  80; endX = 144; func = 'Phrase-Intro'      }
  @{ start = 160; endX = 224; func = 'Phrase-Verse1'     }
  @{ start = 240; endX = 304; func = 'Phrase-Verse1B'    }
  @{ start = 320; endX = 384; func = 'Phrase-PreChorus'  }
  @{ start = 400; endX = 464; func = 'Phrase-Chorus1'    }
  @{ start = 480; endX = 544; func = 'Phrase-Chorus1B'   }
  @{ start = 560; endX = 624; func = 'Phrase-Verse2'     }
  @{ start = 640; endX = 704; func = 'Phrase-Verse2B'    }
  @{ start = 720; endX = 800; func = 'Phrase-Bridge'     }
)

# Materialize patterns from each section.
foreach ($sec in $sections) {
  $beat = $sec.start
  while ($beat -lt $sec.endX) {
    $phrase = & $sec.func
    foreach ($p in $phrase) {
      $b = $beat + $p.o
      if ($b -lt $sec.endX) { Add-Pattern $b $p.id }
    }
    $beat += 8
  }
}

# Add a final outro burst right before the closing counter (732..744 padded around prompts that start at 712+6=718)
# The final counter opens at beat 712 with lead=6 dur=12, prompts 718..729; window closes ~730.
# Allow a brief outro after final counter (no patterns; let song play out).

# Insert counter windows (per-window radius / lead / duration).
foreach ($c in $counters) {
  Add-Counter $c.beat $c.anchor $c.radius $c.lead $c.dur
}

# Sort by beat for cleanliness.
$timelineSorted = $timeline | Sort-Object beat

$boss = [ordered]@{
  id = 'boss_04'
  name = 'EIEN'
  color = '#d4133b'
  bpm = 185
  maxHP = 4800
  bulletDamage = 11
  counterBaseDamage = 38
  music = 'Music/Eien Chi Afurueru.wav'
  musicVolume = 0.85
  musicOffset = 0
  phaseThresholds = @(0.75, 0.5, 0.25)
  patterns = @(
    'aimed_shot','cross','spiral','pulse_aimed','crimson_fan','crimson_wall',
    'wide_wall','vein_radial','flood_radial','bleed_spiral','slash_cross','blood_homing',
    'carnage_radial','needle_wall','storm_spiral','shred_cross','swarm_homing',
    'crimson_rain','dread_converging','blood_storm'
  )
  timeline = $timelineSorted
}

$json = $boss | ConvertTo-Json -Depth 12
$out = 'c:\Users\robbc\Rhythm\data\bosses\boss_04.json'
[System.IO.File]::WriteAllText($out, $json, [System.Text.UTF8Encoding]::new($false))
Write-Output ("Wrote " + $out + " with " + $timelineSorted.Count + " timeline events.")
