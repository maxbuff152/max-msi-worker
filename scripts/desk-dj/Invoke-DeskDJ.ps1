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

# Default desk playback level — Maxwell: always set on start/rotate (silent at 2% was the 2026-09-17 miss).
$script:DefaultPlaybackVolume = 0.25

function Ensure-DeskDjVolumeType {
  if ('DeskDjAudioVolume' -as [type]) { return }
  Add-Type -TypeDefinition @'
using System.Runtime.InteropServices;
[Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAudioEndpointVolume {
  int NotImpl1(); int NotImpl2();
  int GetChannelCount(out uint count);
  int SetMasterVolumeLevel(float level, System.Guid guid);
  int SetMasterVolumeLevelScalar(float level, System.Guid guid);
  int GetMasterVolumeLevel(out float level);
  int GetMasterVolumeLevelScalar(out float level);
  int SetChannelVolumeLevel(uint n, float level, System.Guid guid);
  int SetChannelVolumeLevelScalar(uint n, float level, System.Guid guid);
  int GetChannelVolumeLevel(uint n, out float level);
  int GetChannelVolumeLevelScalar(uint n, out float level);
  int SetMute([MarshalAs(UnmanagedType.Bool)] bool mute, System.Guid guid);
  int GetMute(out bool mute);
}
[Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDevice {
  int Activate(ref System.Guid iid, uint dwClsCtx, System.IntPtr pActivationParams, [MarshalAs(UnmanagedType.IUnknown)] out object ppInterface);
}
[Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IMMDeviceEnumerator {
  int NotImpl1();
  int GetDefaultAudioEndpoint(int dataFlow, int role, out IMMDevice ppDevice);
}
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")]
class MMDeviceEnumeratorComObject {}
public static class DeskDjAudioVolume {
  static void Check(int hr, string step) {
    if (hr < 0) throw new System.InvalidOperationException(string.Format("{0} failed HRESULT=0x{1:X8}", step, hr));
  }
  public static string Set(float target) {
    if (target < 0f) target = 0f;
    if (target > 1f) target = 1f;
    var enumerator = (IMMDeviceEnumerator)(object)new MMDeviceEnumeratorComObject();
    IMMDevice device;
    Check(enumerator.GetDefaultAudioEndpoint(0, 1, out device), "GetDefaultAudioEndpoint");
    var iid = typeof(IAudioEndpointVolume).GUID;
    object activated;
    Check(device.Activate(ref iid, 1, System.IntPtr.Zero, out activated), "Activate");
    var volume = (IAudioEndpointVolume)activated;
    Check(volume.SetMute(false, System.Guid.Empty), "SetMute");
    Check(volume.SetMasterVolumeLevelScalar(target, System.Guid.Empty), "SetMasterVolumeLevelScalar");
    float scalar;
    bool mute;
    Check(volume.GetMasterVolumeLevelScalar(out scalar), "GetMasterVolumeLevelScalar");
    Check(volume.GetMute(out mute), "GetMute");
    if (System.Math.Abs(scalar - target) > 0.02f) {
      throw new System.InvalidOperationException(string.Format("volume mismatch target={0:P0} actual={1:P0}", target, scalar));
    }
    if (mute) {
      throw new System.InvalidOperationException("mute still true after unmute");
    }
    return string.Format("mute={0} master={1:P0}", mute, scalar);
  }
}
'@
}

function Get-PlaybackVolumeTarget($Config) {
  $target = $script:DefaultPlaybackVolume
  if ($null -ne $Config -and $null -ne $Config.playback_volume) {
    try { $target = [double]$Config.playback_volume } catch { $target = $script:DefaultPlaybackVolume }
  }
  if ($target -lt 0) { $target = 0 }
  if ($target -gt 1) { $target = 1 }
  return [float]$target
}

function Set-DeskPlaybackVolume($Config) {
  $target = Get-PlaybackVolumeTarget $Config
  Ensure-DeskDjVolumeType
  $result = [DeskDjAudioVolume]::Set($target)
  Write-Log ("VOLUME set target={0:P0} result={1}" -f $target, $result)
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

function Invoke-PlayUri([string]$Uri, [string]$Label, $Config) {
  Ensure-Spotify
  Set-DeskPlaybackVolume $Config
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
  Invoke-PlayUri -Uri ([string]$source.uri) -Label ([string]$source.label) -Config $config
}

function Invoke-Rotate {
  $config = Get-Config
  if (-not (Test-InWindow $config)) {
    Write-Log 'ROTATE skipped — outside window'
    return
  }
  $source = Select-Source $config
  Invoke-PlayUri -Uri ([string]$source.uri) -Label ([string]$source.label) -Config $config
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
