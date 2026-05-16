# scripts/run_pipeline.ps1
#
# Windows PowerShell equivalent of run_pipeline.sh.
# Runs MATLAB headlessly, verifies figures, then stages, commits, and pushes.
#
# Usage:
#   .\scripts\run_pipeline.ps1
#   .\scripts\run_pipeline.ps1 -NoPush
#   .\scripts\run_pipeline.ps1 -NoCommit
#   .\scripts\run_pipeline.ps1 -MatlabPath "C:\Program Files\MATLAB\R2024a\bin\matlab.exe"
#   .\scripts\run_pipeline.ps1 -Message "Updated LC2 results"

param(
  [switch]$NoPush,
  [switch]$NoCommit,
  [string]$MatlabPath = "",
  [string]$Message = "Automated pipeline run: refresh figures and results"
)

$ErrorActionPreference = "Stop"

# ---- locate repo root ----
$RepoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $RepoRoot
Write-Host "[pipeline] repo root: $RepoRoot"

# ---- locate MATLAB ----
if (-not $MatlabPath) {
  $cmd = Get-Command matlab -ErrorAction SilentlyContinue
  if ($cmd) {
    $MatlabPath = $cmd.Source
  } else {
    $candidates = @(
      "C:\Program Files\MATLAB\R2024a\bin\matlab.exe",
      "C:\Program Files\MATLAB\R2023b\bin\matlab.exe",
      "C:\Program Files\MATLAB\R2023a\bin\matlab.exe"
    )
    foreach ($c in $candidates) {
      if (Test-Path $c) { $MatlabPath = $c; break }
    }
  }
}

if (-not (Test-Path $MatlabPath)) {
  Write-Error "MATLAB binary not found. Pass it via -MatlabPath."
}
Write-Host "[pipeline] matlab: $MatlabPath"

# ---- snapshot figures before run ----
$FigDir = Join-Path $RepoRoot "docs\figures"
New-Item -ItemType Directory -Force -Path $FigDir | Out-Null
$Before = Get-ChildItem $FigDir -Filter *.png -ErrorAction SilentlyContinue | Select-Object Name, LastWriteTime

# ---- run MATLAB ----
Write-Host "[pipeline] running main.m headless. 30 to 120 seconds typical."
$LogFile = Join-Path $RepoRoot "data\last_run.log"
New-Item -ItemType Directory -Force -Path (Split-Path $LogFile) | Out-Null

& $MatlabPath -batch "addpath(genpath('src')); main" 2>&1 | Tee-Object -FilePath $LogFile

# ---- verify ----
$After = Get-ChildItem $FigDir -Filter *.png -ErrorAction SilentlyContinue
if ($After.Count -eq 0) {
  Write-Error "No figures landed in docs/figures. Check $LogFile."
}
Write-Host "[pipeline] figure inventory:"
$After | ForEach-Object { Write-Host "  $($_.Name)" }

# ---- git ----
if (-not $NoCommit) {
  git add docs/figures/ docs/REPORT.md data/last_run.log
  git add data/*.csv -ErrorAction SilentlyContinue

  $staged = git diff --cached --name-only
  if (-not $staged) {
    Write-Host "[pipeline] nothing staged."
  } else {
    git commit -m $Message
    Write-Host "[pipeline] committed."
    if (-not $NoPush) {
      $branch = git rev-parse --abbrev-ref HEAD
      git push origin $branch
      Write-Host "[pipeline] pushed branch $branch."
    }
  }
}

Write-Host "[pipeline] done."
