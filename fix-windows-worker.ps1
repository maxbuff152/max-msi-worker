# Max-MSI — Windows ABI patch + start My Machines worker
# Unofficial workaround for Cursor Windows better-sqlite3 127 vs 137 bug.
# Prefer WSL (official). Use this if you want to stay on native Windows.
#
# Usage (PowerShell):
#   irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/fix-windows-worker.ps1 | iex
# Or:
#   Set-ExecutionPolicy -Scope Process Bypass -Force
#   .\fix-windows-worker.ps1

$ErrorActionPreference = "Stop"
$WorkerName = "Max-MSI"
$RepoUrl = "https://github.com/maxbuff152/max-msi-worker.git"
$WorkDir = Join-Path $env:USERPROFILE "projects\max-msi-worker"
$PrebuildUrl = "https://github.com/WiseLibs/better-sqlite3/releases/download/v12.12.0/better-sqlite3-v12.12.0-node-v137-win32-x64.tar.gz"

Write-Host "==> Max-MSI Windows worker patch" -ForegroundColor Cyan

# Ensure Agent CLI exists
if (-not (Get-Command agent -ErrorAction SilentlyContinue)) {
  Write-Host "Installing Cursor Agent CLI (Windows)..."
  irm 'https://cursor.com/install?win32=true' | iex
  $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

if (-not (Get-Command agent -ErrorAction SilentlyContinue)) {
  throw "'agent' not found on PATH after install. Open a new PowerShell and re-run."
}

Write-Host "==> agent --version"
agent --version

# Patch every installed cursor-agent version that has better-sqlite3
$agentRoot = Join-Path $env:LOCALAPPDATA "cursor-agent\versions"
if (-not (Test-Path $agentRoot)) {
  throw "No cursor-agent versions under $agentRoot. Run 'agent --version' once first."
}

$tmp = Join-Path $env:TEMP ("better-sqlite3-v137-" + [guid]::NewGuid().ToString("n"))
New-Item -ItemType Directory -Path $tmp | Out-Null
$tgz = Join-Path $tmp "prebuild.tgz"
Write-Host "==> Downloading Node ABI 137 better-sqlite3 prebuild"
Invoke-WebRequest -Uri $PrebuildUrl -OutFile $tgz

# Expand .tar.gz (Windows 10+ tar)
Push-Location $tmp
try {
  tar -xzf $tgz
  $srcNode = Join-Path $tmp "build\Release\better_sqlite3.node"
  if (-not (Test-Path $srcNode)) { throw "Prebuild extract missing better_sqlite3.node" }

  $patched = 0
  Get-ChildItem $agentRoot -Directory | ForEach-Object {
    $dest = Join-Path $_.FullName "node_modules\better-sqlite3\build\Release\better_sqlite3.node"
    if (Test-Path $dest) {
      Copy-Item -Force $srcNode $dest
      Write-Host "    patched: $dest" -ForegroundColor Green
      $patched++
    }
  }
  if ($patched -eq 0) {
    throw "Found cursor-agent versions but no better_sqlite3.node paths to patch."
  }
  Write-Host "==> Patched $patched install(s)"
}
finally {
  Pop-Location
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

# Ensure a git repo for My Machines routing
if (-not (Test-Path (Join-Path $WorkDir ".git"))) {
  New-Item -ItemType Directory -Force -Path (Split-Path $WorkDir) | Out-Null
  if (Test-Path $WorkDir) { Remove-Item -Recurse -Force $WorkDir }
  Write-Host "==> Cloning $RepoUrl"
  git clone $RepoUrl $WorkDir
} else {
  Write-Host "==> Using existing repo $WorkDir"
}

Set-Location $WorkDir

Write-Host "==> Login (SAME Cursor account as iPhone)" -ForegroundColor Yellow
agent login

Write-Host "==> agent worker debug"
try { agent worker debug } catch { Write-Host $_ }

Write-Host "==> Starting worker $WorkerName (leave this window open; keep MSI awake)" -ForegroundColor Cyan
agent worker start --name $WorkerName --idle-release-timeout 0
