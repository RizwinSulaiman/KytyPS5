<#Requires -Version 5.1
<#
.SYNOPSIS
  Local Demon's Souls smoke-benchmark harness (engineering infrastructure, not a perf optimization).

.DESCRIPTION
  Launches the locally built kyty_emulator against the owner's existing
  directly-launchable dump (opaque local input), samples process stats at
  ~1 Hz, captures screenshots at configurable times, and stores everything
  in a timestamped _Build/benchmarks folder (git-ignored via _Build/).

  - Game root comes from -GameRoot or $env:DS_GAME_ROOT. Never hardcoded.
  - Never writes to, lists, or modifies game files. Read-only launch.
  - Terminates ONLY the spawned emulator process after the timeout.
  - Screenshots use System.Drawing screen capture (no OCR).
  - Optional input schedule (-InputSchedule "sec:key,...", default OFF) focuses
    ONLY the spawned emulator window (by PID) and sends keystrokes at the given
    times. With no --keymap args the emulator's built-in default applies, where
    the J key = DualSense Cross (hostInput.cpp DefaultKeyboardButton), i.e. the
    safe confirm keystroke for the highlighted menu entry is J with no navigation.

.EXAMPLE
  $env:DS_GAME_ROOT = '<path-to-your-app0-parent>'
  .\scripts\Run-DsBenchmark.ps1 -Width 480 -Height 270 -PresentMode Immediate -TimeoutSec 60
  .\scripts\Run-DsBenchmark.ps1 -TimeoutSec 90 -InputSchedule '25:j'
#>
[CmdletBinding()]
param(
  [string]$GameRoot = $env:DS_GAME_ROOT,
  [string]$EmulatorExe = '',
  [int]$Width = 480,
  [int]$Height = 270,
  [ValidateSet('Fifo', 'Mailbox', 'Immediate')][string]$PresentMode = 'Immediate',
  [int]$TimeoutSec = 60,
  [int[]]$ShotAt = @(2, 5, 10, 15),
  [string]$ExtraArgs = '--shader-optimization-type Performance --vulkan-validation false --shader-validation false --command-buffer-dump false --graphics-debug-dump false --playgo-hack',
  [string]$InputSchedule = '',
  [string]$OutRoot = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($EmulatorExe)) {
  $EmulatorExe = Join-Path $repoRoot '_Build\win-tests\kyty_emulator.exe'
}
if ([string]::IsNullOrWhiteSpace($OutRoot)) {
  $OutRoot = Join-Path $repoRoot '_Build\benchmarks'
}
if ([string]::IsNullOrWhiteSpace($GameRoot)) {
  throw 'Game root missing: pass -GameRoot or set $env:DS_GAME_ROOT. No path is hardcoded in this script.'
}
if (-not (Test-Path -LiteralPath $GameRoot)) { throw "Game root not found: $GameRoot" }
if (-not (Test-Path -LiteralPath $EmulatorExe)) { throw "Emulator not found: $EmulatorExe (build it first; this script never builds)" }

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$runDir = Join-Path $OutRoot $stamp
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$argList = @('--game', $GameRoot, '--screen-width', "$Width", '--screen-height', "$Height",
  '--present-mode', $PresentMode) + @($ExtraArgs -split '\s+' | Where-Object { $_ })
$cmdLine = "`"$EmulatorExe`" " + ($argList -join ' ')
$cmdLine | Out-File -LiteralPath (Join-Path $runDir 'command.txt') -Encoding utf8

Add-Type -AssemblyName System.Drawing
try { Add-Type -AssemblyName System.Windows.Forms } catch { }
try {
  Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);' -Name Win32Fg -Namespace Harness -ErrorAction Stop
} catch { }
function Save-Screenshot([string]$Path) {
  $vs = [System.Windows.Forms.SystemInformation]::VirtualScreen
  $bmp = New-Object System.Drawing.Bitmap($vs.Width, $vs.Height)
  try {
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try { $g.CopyFromScreen($vs.Location, [System.Drawing.Point]::Empty, $vs.Size) }
    finally { $g.Dispose() }
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  } finally { $bmp.Dispose() }
}

$startUtc = (Get-Date).ToUniversalTime().ToString('o')
$sw = [Diagnostics.Stopwatch]::StartNew()
$proc = Start-Process -FilePath $EmulatorExe -ArgumentList $argList `
  -WorkingDirectory (Split-Path -Parent $EmulatorExe) `
  -RedirectStandardOutput (Join-Path $runDir 'stdout.log') `
  -RedirectStandardError (Join-Path $runDir 'stderr.log') -PassThru
$samples = @('t_sec,working_set_mb,cpu_pct,threads,gpu_3d_engines_pct')
$shotsTaken = @{}
$inputsFired = @()
$exitReason = 'timeout'
$cores = [int]$env:NUMBER_OF_PROCESSORS
if ($cores -le 0) { $cores = 1 }
$inputs = @()
foreach ($item in ($InputSchedule -split ',' | Where-Object { $_ -match '\S' })) {
  $kv = $item -split ':'
  if ($kv.Count -ne 2) { throw "Bad -InputSchedule entry '$item' (want sec:key, e.g. '25:J')" }
  $inputs += [pscustomobject]@{ At = [double]$kv[0]; Key = $kv[1].Trim(); Fired = $false }
}
$prevCpu = $null
$prevTick = $null
try {
  while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
    Start-Sleep -Seconds 1
    $t = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    $p = $null
    try { $p = Get-Process -Id $proc.Id -ErrorAction Stop } catch { }
    $wsMb = ''
    $thr = ''
    if ($p) {
      $wsMb = [math]::Round($p.WorkingSet64 / 1MB, 1)
      $thr = $p.Threads.Count
    }
    $cpuPct = ''
    $now = Get-Date
    if ($p -and $null -ne $prevCpu -and $null -ne $prevTick) {
      $dt = ($now - $prevTick).TotalSeconds
      if ($dt -gt 0) {
        $cpuPct = [math]::Round((($p.TotalProcessorTime - $prevCpu).TotalSeconds / $dt) / $cores * 100, 1)
      }
    }
    if ($p) { $prevCpu = $p.TotalProcessorTime; $prevTick = $now }
    $gpu = 'n/a'
    try {
      $c = Get-Counter -Counter '\GPU Engine(*engtype_3D*)\Utilization Percentage' -ErrorAction Stop
      $gpu = [math]::Round(($c.CounterSamples | Measure-Object CookedValue -Sum).Sum, 1)
    } catch { }
    $samples += "$t,$wsMb,$cpuPct,$thr,$gpu"
    foreach ($in in $inputs) {
      if (-not $in.Fired -and $t -ge $in.At -and -not $proc.HasExited) {
        $in.Fired = $true
        try {
          $h = (Get-Process -Id $proc.Id -ErrorAction Stop).MainWindowHandle
          if ($h -eq 0) { throw 'spawned emulator has no main window yet' }
          [Harness.Win32Fg]::SetForegroundWindow($h) | Out-Null
          [System.Windows.Forms.SendKeys]::SendWait($in.Key)
          $inputsFired += ("{0}:{1}" -f $in.At, $in.Key)
        } catch { $inputsFired += ("{0}:{1}:FAILED:{2}" -f $in.At, $in.Key, $_) }
      }
    }
    foreach ($s in $ShotAt) {
      if ($t -ge $s -and -not $shotsTaken.ContainsKey($s) -and -not $proc.HasExited) {
        $shotPath = Join-Path $runDir ("shot-t{0}.png" -f $s)
        try { Save-Screenshot $shotPath; $shotsTaken["$s"] = ("shot-t{0}.png" -f $s) }
        catch { $shotsTaken["$s"] = "failed: $_" }
      }
    }
    if ($proc.HasExited) { $exitReason = 'process-exited'; break }
  }
} finally {
  if (-not $proc.HasExited) {
    try { Stop-Process -Id $proc.Id -Force -ErrorAction Stop }
    catch { $exitReason = "stop-failed: $_" }
  } else {
    $exitReason = 'process-exited'
  }
}
$sw.Stop()
$samples | Out-File -LiteralPath (Join-Path $runDir 'samples.csv') -Encoding utf8

$exitCode = $null
try { $exitCode = $proc.ExitCode } catch { }

$meta = [ordered]@{
  emulator           = $EmulatorExe
  command            = $cmdLine
  width              = $Width
  height             = $Height
  present_mode       = $PresentMode
  timeout_sec        = $TimeoutSec
  shot_at_sec        = $ShotAt
  extra_args         = $ExtraArgs
  input_schedule     = $InputSchedule
  inputs_fired       = $inputsFired
  logical_cores      = $cores
  start_utc          = $startUtc
  end_utc            = (Get-Date).ToUniversalTime().ToString('o')
  lifetime_sec       = [math]::Round($sw.Elapsed.TotalSeconds, 1)
  exit_code          = $exitCode
  exit_reason        = $exitReason
  screenshots        = $shotsTaken
  game_files_touched = $false
}
$meta | ConvertTo-Json -Depth 4 | Out-File -LiteralPath (Join-Path $runDir 'meta.json') -Encoding utf8
Write-Output "run dir: $runDir | exit: $exitReason | lifetime_s: $($meta.lifetime_sec)"
