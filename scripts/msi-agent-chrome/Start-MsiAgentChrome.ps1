<#
.SYNOPSIS
  Start MSI Agent Chrome (headed) with CDP on 127.0.0.1:9333.

.DESCRIPTION
  Dedicated profile for Cursor agents on MSI. Maxwell signs in here.
  Firefox stays the human browser (tastytrade, personal tabs).
  NEVER wipe the profile directory.
  Default: reuse if CDP already listening. -ForceRestart recycles the process only.

  Not for HAR / Matrix / Hubzu / auctions — those stay on Lenovo CDP.
#>
[CmdletBinding()]
param(
  [switch]$ForceRestart,
  [switch]$Headed = $true,
  [int]$Port = 9333,
  [string]$StartUrl = ''
)

$ErrorActionPreference = 'Stop'
$Root = Join-Path $env:LOCALAPPDATA 'Maxwell\MsiAgentChrome'
$ProfileDir = Join-Path $Root 'profile'
$LogDir = Join-Path $Root 'logs'
$Chrome = Join-Path ${env:ProgramFiles} 'Google\Chrome\Application\chrome.exe'
$DefaultStart = Join-Path $Root 'sign-in.html'

New-Item -ItemType Directory -Force -Path $ProfileDir, $LogDir | Out-Null

if (-not (Test-Path -LiteralPath $Chrome)) {
  throw "Chrome not found at $Chrome"
}

function Test-CdpUp {
  param([int]$ListenPort)
  try {
    $conn = Get-NetTCPConnection -LocalPort $ListenPort -State Listen -ErrorAction SilentlyContinue |
      Where-Object { $_.LocalAddress -eq '127.0.0.1' }
    return [bool]$conn
  } catch {
    return $false
  }
}

function Get-AgentChromeProcs {
  Get-CimInstance Win32_Process -Filter "Name='chrome.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -and ($_.CommandLine -like "*MsiAgentChrome*profile*") }
}

if ((Test-CdpUp -ListenPort $Port) -and -not $ForceRestart) {
  Write-Host "CHROME_REUSED — CDP :$Port already listening (profile left alone)"
  exit 0
}

if ($ForceRestart) {
  Write-Host "FORCE_CHROME_RESTART — profile directory kept; killing MsiAgentChrome processes only"
  Get-AgentChromeProcs | ForEach-Object {
    try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {}
  }
  Start-Sleep -Seconds 1
}

if (-not $StartUrl) {
  if (Test-Path -LiteralPath $DefaultStart) {
    $StartUrl = ('file:///{0}' -f ($DefaultStart -replace '\\', '/'))
  } else {
    $StartUrl = 'https://www.youtube.com/'
  }
}

$chromeArgs = @(
  "--remote-debugging-port=$Port"
  '--remote-debugging-address=127.0.0.1'
  "--user-data-dir=$ProfileDir"
  '--no-first-run'
  '--no-default-browser-check'
  '--disable-sync-preferences'
  '--new-window'
  $StartUrl
)

Write-Host "Starting headed Agent Chrome — CDP http://127.0.0.1:$Port"
Write-Host "Profile: $ProfileDir"
Write-Host "Start:   $StartUrl"

$chromeProc = Start-Process -FilePath $Chrome -ArgumentList $chromeArgs -PassThru
$startLog = Join-Path $LogDir ("start-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))
@(
  "pid=$($chromeProc.Id)"
  "port=$Port"
  "profile=$ProfileDir"
  "url=$StartUrl"
  "forceRestart=$ForceRestart"
) | Set-Content -LiteralPath $startLog -Encoding UTF8

$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline) {
  if (Test-CdpUp -ListenPort $Port) {
    Write-Host "CDP_OK http://127.0.0.1:$Port"
    exit 0
  }
  Start-Sleep -Milliseconds 400
}

Write-Host "CDP_WAIT — Chrome started but :$Port not listening yet (check window)"
exit 0
