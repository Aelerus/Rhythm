# Structure analysis for Phase 2 (Wounded Ultraviolet) and Phase 3 (Apex - Phase 3).
# Same approach as analyze_apex.ps1: per-window tempo + 1s energy bars + transitions.

$ErrorActionPreference = 'Stop'

function Analyze([string]$path) {
  Write-Output "=================================================================="
  Write-Output ("FILE: " + $path)
  Write-Output "=================================================================="
  $fs = [System.IO.File]::OpenRead($path)
  $br = New-Object System.IO.BinaryReader($fs)
  $null = $br.ReadBytes(12)
  $null = $br.ReadBytes(4)
  $fmtSize = $br.ReadUInt32()
  $null = $br.ReadUInt16()
  $numChannels = $br.ReadUInt16()
  $sampleRate = $br.ReadUInt32()
  $byteRate = $br.ReadUInt32()
  $blockAlign = $br.ReadUInt16()
  $bits = $br.ReadUInt16()
  if ($fmtSize -gt 16) { $null = $br.ReadBytes($fmtSize - 16) }

  $dataSize = 0
  while ($true) {
    $cid = [System.Text.Encoding]::ASCII.GetString($br.ReadBytes(4))
    $csz = $br.ReadUInt32()
    if ($cid -eq 'data') { $dataSize = $csz; break }
    $null = $br.ReadBytes($csz)
  }

  $totalSec = $dataSize / $byteRate
  Write-Output ("Duration: " + [Math]::Round($totalSec, 2) + "s")
  Write-Output ""

  $raw = $br.ReadBytes($dataSize)
  $br.Close()

  $samplesPerChannel = $dataSize / $blockAlign
  $bytesPerSample = $bits / 8

  $envFS = 100
  $samplesPerEnv = [int]($sampleRate / $envFS)
  $envLen = [int]($samplesPerChannel / $samplesPerEnv)
  $env = New-Object double[] $envLen

  for ($i = 0; $i -lt $envLen; $i++) {
    $sumSq = 0.0
    $base = $i * $samplesPerEnv * $blockAlign
    for ($j = 0; $j -lt $samplesPerEnv; $j++) {
      $off = $base + $j * $blockAlign
      if ($off + 1 -ge $raw.Length) { break }
      $s = 0.0
      for ($c = 0; $c -lt $numChannels; $c++) {
        $val = [BitConverter]::ToInt16($raw, $off + $c * $bytesPerSample)
        $s += $val
      }
      $s /= $numChannels
      $sumSq += $s * $s
    }
    $env[$i] = [Math]::Sqrt($sumSq / $samplesPerEnv)
  }

  $flux = New-Object double[] $envLen
  for ($i = 1; $i -lt $envLen; $i++) {
    $d = $env[$i] - $env[$i - 1]
    if ($d -gt 0) { $flux[$i] = $d }
  }

  $winSec = 10
  $winLen = $envFS * $winSec
  $bpmLow = 60
  $bpmHigh = 260
  $lagLow = [int]($envFS * 60.0 / $bpmHigh)
  $lagHigh = [int]($envFS * 60.0 / $bpmLow)

  Write-Output "Per-section tempo (10s windows):"
  Write-Output ("Time      Energy       PeakBPM  2ndBPM  3rdBPM")
  for ($w = 0; $w + $winLen -le $envLen; $w += [int]($envFS * 5)) {
    $end = $w + $winLen
    $eSum = 0.0
    for ($i = $w; $i -lt $end; $i++) { $eSum += $env[$i] }
    $eAvg = $eSum / $winLen

    $best = @()
    for ($lag = $lagLow; $lag -le $lagHigh; $lag++) {
      $sum = 0.0
      $count = $winLen - $lag
      for ($i = 0; $i -lt $count; $i++) {
        $sum += $flux[$w + $i] * $flux[$w + $i + $lag]
      }
      $sum /= $count
      $bpm = 60.0 * $envFS / $lag
      $best += [pscustomobject]@{ BPM = [Math]::Round($bpm, 1); Corr = $sum }
    }
    $top3 = $best | Sort-Object Corr -Descending | Select-Object -First 3
    $tSec = $w / $envFS
    $tStr = "{0:D2}:{1:D2}" -f [int]($tSec/60), [int]($tSec%60)
    $line = "{0}     {1,8:N0}     {2,5:N1}    {3,5:N1}    {4,5:N1}" -f $tStr, $eAvg, $top3[0].BPM, $top3[1].BPM, $top3[2].BPM
    Write-Output $line
  }

  Write-Output ""
  Write-Output "Energy timeline (1s avg, normalized 0-9):"
  $secEnv = New-Object double[] ([int]$totalSec)
  for ($s = 0; $s -lt $secEnv.Length; $s++) {
    $a = $s * $envFS
    $b = $a + $envFS
    if ($b -gt $envLen) { $b = $envLen }
    $sum = 0.0
    $cnt = 0
    for ($i = $a; $i -lt $b; $i++) { $sum += $env[$i]; $cnt++ }
    $secEnv[$s] = if ($cnt -gt 0) { $sum / $cnt } else { 0 }
  }
  $maxE = ($secEnv | Measure-Object -Maximum).Maximum
  if ($maxE -le 0) { $maxE = 1 }

  $bar = ""
  for ($s = 0; $s -lt $secEnv.Length; $s++) {
    $level = [int](($secEnv[$s] / $maxE) * 9)
    $bar += $level
    if (($s + 1) % 60 -eq 0) {
      Write-Output ("{0:D2}:00  {1}" -f [int](($s+1-60)/60), $bar)
      $bar = ""
    }
  }
  if ($bar.Length -gt 0) {
    Write-Output ("{0:D2}:{1:D2}  {2}" -f [int]($secEnv.Length/60), [int]($secEnv.Length%60), $bar)
  }
  Write-Output ""
}

Analyze 'c:\Users\robbc\Rhythm\Music\Wounded Ultraviolet.wav'
Analyze 'c:\Users\robbc\Rhythm\Music\Apex - Phase 3.wav'
