# SFHS Desk DJ — Spotify only (9am-7pm America/Chicago)
param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('start','stop','status','rotate','install-schedule','uninstall-schedule')]
  [string]$Action,
  [string]$ConfigPath = ''
)

$ErrorActionPreference = 'Stop'
$Root = Join-Path $env:LOCALAPPDATA 'Maxwell\DeskDJ'
$LogDir = Join-Path $Root 'logs'
$StatePath = Join-Path $Root 'state.json'
$DefaultConfig = Join-Path $Root 'playlist-config.json'
if (-not $ConfigPath) { $ConfigPath = $DefaultConfig }

New-Item -ItemType Directory -Force -Path $Root, $LogDir | Out-Null

function Write-Log([string]$Message) {
  $line = '{0} {1}' -f (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'), $Message
  Add-Content -LiteralPath (Join-Path $LogDir 'desk-dj.log') -Value $line -Encoding UTF8
  Write-Host $line
}

function Get-Config {
  if (-not (Test-Path -LiteralPath $ConfigPath)) { throw "Missing config: $ConfigPath" }
  return (Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json)
}

function Get-WeightedSources($Config) {
  $items = @()
  foreach ($s in @($Config.sources) + @($Config.personal_slots)) {
    if (-not $s) { continue }
    if (-not $s.uri) { continue }
    $w = 0
    try { $w = [int]$s.weight } catch { $w = 0 }
    if ($w -le 0) { continue }
    for ($i = 0; $i -lt $w; $i++) { $items += $s }
  }
  return $items
}

function Get-LastUri {
  if (Test-Path -LiteralPath $StatePath) {
    try {
      $st = Get-Content -LiteralPath $StatePath -Raw -Encoding UTF8 | ConvertFrom-Json
      return [string]$st.uri
    } catch { return '' }
  }
  return ''
}

function Select-Source($Config) {
  $pool = @(Get-WeightedSources $Config)
  if ($pool.Count -eq 0) { throw 'No weighted sources with URIs in config' }
  $last = Get-LastUri
  if ($last) {
    $filtered = @($pool | Where-Object { [string]$_.uri -ne $last })
    if ($filtered.Count -gt 0) { $pool = $filtered }
  }
  $daySeed = [int](Get-Date -Format 'yyyyMMdd')
  $hour = [int](Get-Date -Format 'HH')
  $rng = New-Object System.Random (($daySeed * 17) + ($hour * 31) + 7)
  $idx = $rng.Next(0, $pool.Count)
  return $pool[$idx]
}

function Test-InWindow($Config) {
  $now = Get-Date
  $startParts = $Config.window.start.Split(':')
  $stopParts = $Config.window.stop.Split(':')
  $start = Get-Date -Hour ([int]$startParts[0]) -Minute ([int]$startParts[1]) -Second 0
  $stop = Get-Date -Hour ([int]$stopParts[0]) -Minute ([int]$stopParts[1]) -Second 0
  return ($now -ge $start -and $now -lt $stop)
}

function Ensure-Spotify {
  $sp = Get-Process Spotify -ErrorAction SilentlyContinue | Select-Object -First 1
  if (-not $sp) {
    $exe = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\Spotify.exe'
    if (Test-Path -LiteralPath $exe) { Start-Process -FilePath $exe }
    else { Start-Process 'spotify:' }
    Start-Sleep -Seconds 4
  }
}

Add-Type -AssemblyName System.Runtime.WindowsRuntime | Out-Null
$asTaskGeneric = ([System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
  $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
})[0]
function Await-WinRT($WinRtTask, $ResultType) {
  $asTask = $asTaskGeneric.MakeGenericMethod($ResultType)
  $netTask = $asTask.Invoke($null, @($WinRtTask))
  $netTask.Wait(-1) | Out-Null
  return $netTask.Result
}

function Get-SmtcManager {
  [Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager,Windows.Media.Control,ContentType=WindowsRuntime] | Out-Null
  return Await-WinRT ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager]::RequestAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionManager])
}

function Get-SpotifySession($Manager) {
  foreach ($session in $Manager.GetSessions()) {
    if ($session.SourceAppUserModelId -match 'Spotify') { return $session }
  }
  return $null
}

function Show-Status {
  $mgr = Get-SmtcManager
  $found = $false
  foreach ($session in $mgr.GetSessions()) {
    if ($session.SourceAppUserModelId -notmatch 'Spotify') { continue }
    $found = $true
    $info = Await-WinRT ($session.TryGetMediaPropertiesAsync()) ([Windows.Media.Control.GlobalSystemMediaTransportControlsSessionMediaProperties])
    $status = $session.GetPlaybackInfo().PlaybackStatus
    Write-Host ("STATUS={0} | {1} - {2}" -f $status, $info.Artist, $info.Title)
  }
  if (-not $found) { Write-Host 'STATUS=no Spotify SMTC session' }
}

function Invoke-Stop {
  $mgr = Get-SmtcManager
  $session = Get-SpotifySession $mgr
  if ($null -eq $session) { Write-Log 'STOP skipped — Spotify SMTC missing'; return }
  $ok = Await-WinRT ($session.TryPauseAsync()) ([bool])
  Write-Log ("STOP pause={0}" -f $ok)
  Show-Status
}

function Invoke-PlayUri([string]$Uri, [string]$Label) {
  Ensure-Spotify
  Write-Log ("PLAY uri={0} label={1}" -f $Uri, $Label)
  Start-Process $Uri
  Start-Sleep -Seconds 3
  $mgr = Get-SmtcManager
  $session = Get-SpotifySession $mgr
  if ($null -ne $session) {
    $ok = Await-WinRT ($session.TryPlayAsync()) ([bool])
    Write-Log ("PLAY TryPlayAsync={0}" -f $ok)
  } else {
    Write-Log 'PLAY warning — no SMTC session yet (Spotify may still autoplay)'
  }
  @{ uri = $Uri; label = $Label; at = (Get-Date -Format 'o') } | ConvertTo-Json | Set-Content -LiteralPath $StatePath -Encoding UTF8
  Show-Status
}

function Invoke-Start([switch]$ForceOutsideWindow) {
  $config = Get-Config
  if (-not $ForceOutsideWindow -and -not (Test-InWindow $config)) {
    Write-Log 'START skipped — outside 09:00-19:00 window (use rotate -Force only via start outside for manual)'
    # Allow explicit start always when Action=start from human/agent
  }
  $source = Select-Source $config
  Invoke-PlayUri -Uri ([string]$source.uri) -Label ([string]$source.label)
}

function Invoke-Rotate {
  $config = Get-Config
  if (-not (Test-InWindow $config)) {
    Write-Log 'ROTATE skipped — outside window'
    return
  }
  $source = Select-Source $config
  Invoke-PlayUri -Uri ([string]$source.uri) -Label ([string]$source.label)
}

function Install-Schedule {
  $ps1 = Join-Path $Root 'Invoke-DeskDJ.ps1'
  $pwsh = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
  # Start 09:00
  schtasks /Create /F /TN 'SFHS-DeskDJ-Start' /SC DAILY /ST 09:00 /RL LIMITED /TR "`"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$ps1`" -Action start" | Out-Host
  # Stop 19:00
  schtasks /Create /F /TN 'SFHS-DeskDJ-Stop' /SC DAILY /ST 19:00 /RL LIMITED /TR "`"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$ps1`" -Action stop" | Out-Host
  # Rotates
  foreach ($h in @('11:00','13:00','15:00','17:00')) {
    $name = 'SFHS-DeskDJ-Rotate-' + ($h.Replace(':',''))
    schtasks /Create /F /TN $name /SC DAILY /ST $h /RL LIMITED /TR "`"$pwsh`" -NoProfile -ExecutionPolicy Bypass -File `"$ps1`" -Action rotate" | Out-Host
  }
  Write-Log 'SCHEDULE installed (Start 09:00, Rotate 11/13/15/17, Stop 19:00)'
}

function Uninstall-Schedule {
  foreach ($tn in @('SFHS-DeskDJ-Start','SFHS-DeskDJ-Stop','SFHS-DeskDJ-Rotate-1100','SFHS-DeskDJ-Rotate-1300','SFHS-DeskDJ-Rotate-1500','SFHS-DeskDJ-Rotate-1700')) {
    schtasks /Delete /F /TN $tn 2>$null | Out-Null
  }
  Write-Log 'SCHEDULE removed'
}

switch ($Action) {
  'start' { Invoke-Start }
  'stop' { Invoke-Stop }
  'status' { Show-Status }
  'rotate' { Invoke-Rotate }
  'install-schedule' { Install-Schedule }
  'uninstall-schedule' { Uninstall-Schedule }
}
