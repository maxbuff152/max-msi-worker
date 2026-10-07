# Load only function definitions: no production setup, dispatch, filesystem or audio.
$ErrorActionPreference = 'Stop'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile(
  (Join-Path $PSScriptRoot 'desk-dj/Invoke-DeskDJ.ps1'),[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
$functions=$ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst]},$false)
foreach ($fn in $functions) { . ([scriptblock]::Create($fn.Extent.Text)) }
function Assert($ok,$msg) { if (-not $ok) { throw $msg } }
$config=Get-Content (Join-Path $PSScriptRoot 'desk-dj/playlist-config.json') -Raw | ConvertFrom-Json
$script:DefaultPlaybackVolume=0.25
Assert ($config.playback_volume -eq 0.25) 'Default volume changed'
Assert ($config.window.start -eq '09:00' -and $config.window.stop -eq '19:00') 'Window changed'
Assert (($config.rotate_hours -join ',') -eq '9,11,13,15,17') 'Rotations changed'
foreach ($case in @(@{input=$null;want=0.25},@{input=@{};want=0.25},
  @{input=@{playback_volume='invalid'};want=0.25},@{input=@{playback_volume=-1};want=0},
  @{input=@{playback_volume=2};want=1},@{input=@{playback_volume=0};want=0})) {
  Assert ((Get-PlaybackVolumeTarget $case.input) -eq $case.want) 'Volume fallback/clamp failed'
}
$fixture=[pscustomobject]@{sources=@(
  [pscustomobject]@{uri='A';weight=2},[pscustomobject]@{uri='B';weight=1},
  [pscustomobject]@{uri='';weight=8},[pscustomobject]@{uri='ignored';weight=0});
  personal_slots=@([pscustomobject]@{uri='A';weight=3})}
Assert (@(Get-WeightedSources $fixture).Count -eq 6) 'Weighting changed'
function Get-LastUri { 'A' }
Assert ((Select-Source $fixture).uri -eq 'B') 'Prior URI repeated through duplicate slot'
$fixture.sources=@([pscustomobject]@{uri='A';weight=1}); $fixture.personal_slots=@()
Assert ((Select-Source $fixture).uri -eq 'A') 'Sole-source fallback failed'
$fixture.sources=@()
$threw=$false; try { Select-Source $fixture } catch { $threw=$true }
Assert $threw 'Empty pool should fail'
function Get-Date { param($Hour,$Minute,$Second)
  if ($PSBoundParameters.ContainsKey('Hour')) { return [datetime]::new(2026,10,7,$Hour,$Minute,$Second) }
  return $script:clock
}
foreach ($case in @(@{time='08:59:59';want=$false},@{time='09:00:00';want=$true},
  @{time='18:59:59';want=$true},@{time='19:00:00';want=$false})) {
  $script:clock=[datetime]::Parse('2026-10-07T'+$case.time)
  Assert ((Test-InWindow $config) -eq $case.want) 'Window boundary failed'
}
# Capture task arguments; never invoke Task Scheduler.
$script:tasks=[System.Collections.Generic.List[string]]::new()
function schtasks { $script:tasks.Add(($args -join ' ')) }
function Write-Log { param($Message) }
$Root=$PSScriptRoot; $env:SystemRoot=$PSScriptRoot
Install-Schedule
Assert ($script:tasks.Count -eq 6) 'Expected six tasks'
foreach ($pair in @(@('Start','09:00','start'),@('Stop','19:00','stop'),
  @('Rotate-1100','11:00','rotate'),@('Rotate-1300','13:00','rotate'),
  @('Rotate-1500','15:00','rotate'),@('Rotate-1700','17:00','rotate'))) {
  $task=@($script:tasks | Where-Object { $_ -match ('/TN SFHS-DeskDJ-'+$pair[0]+' ') })
  Assert ($task.Count -eq 1 -and $task[0].Contains('/ST '+$pair[1]) -and
    $task[0].Contains('-Action '+$pair[2]) -and $task[0].Contains('/RL LIMITED') -and
    $task[0].Contains('/SC DAILY')) 'Schedule action/time/permissions changed'
}
$script:tasks.Clear(); Uninstall-Schedule
Assert ($script:tasks.Count -eq 6) 'Expected six task removals'
function Get-Config { $config }
function Select-Source { param($Config) $Config.sources[0] }
$script:plays=0
function Invoke-PlayUri { param($Uri,$Label,$Config)
  Assert ($Config.playback_volume -eq 0.25) 'Playback lost volume config'; $script:plays++ }
$script:clock=[datetime]'2026-10-07T10:00:00'; Invoke-Start; Invoke-Rotate
Assert ($script:plays -eq 2) 'Start/rotate did not play'
$script:clock=[datetime]'2026-10-07T20:00:00'; Invoke-Rotate
Assert ($script:plays -eq 2) 'Rotate played outside window'
Invoke-Start
Assert ($script:plays -eq 3) 'Manual start must remain allowed outside window'
$play=($functions | Where-Object Name -eq 'Invoke-PlayUri').Extent.Text
$volumeAt=$play.IndexOf('Set-DeskPlaybackVolume $Config')
Assert ($volumeAt -ge 0 -and $volumeAt -lt $play.IndexOf('Start-Process $Uri')) 'Volume must precede playback'
'PASS parse, weighted anti-repeat, window, schedule, volume and entrypoints'
