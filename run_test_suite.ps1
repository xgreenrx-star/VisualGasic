# VisualGasic automated test suite (Windows)
# Usage: .\run_test_suite.ps1 [-GdOnly] [filter]

param(
    [switch]$GdOnly,
    [string]$Filter = "test_*.vg"
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

$Godot = $env:VG_GODOT
if (-not $Godot) {
    foreach ($c in @(
        (Join-Path $Root 'Godot_v4.6.1-stable_win64.exe'),
        (Join-Path $Root 'Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $Root 'godot.exe')
    )) { if (Test-Path $c) { $Godot = $c; break } }
}
$TestDir = Join-Path $Root 'test_proj/test_suite'
$Runner = 'run_suite.gd'
$TimeoutSec = 20

Write-Host ""
Write-Host "=================================================="
Write-Host "     VisualGasic Automated Test Suite (Windows)"
Write-Host "=================================================="
Write-Host ""

if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "Godot binary not found. Set VG_GODOT or place Godot_v4.6.1-stable_win64.exe in repo root."
    exit 1
}
if (-not (Test-Path $TestDir)) {
    Write-Error "Test directory not found at $TestDir"
    exit 1
}

$TotalPass = 0
$TotalFail = 0
$TotalError = 0
$TotalFiles = 0
$FailedFiles = @()
$ErrorFiles = @()
$ExitCode = 0

if (-not $GdOnly) {
    $TestFiles = Get-ChildItem -Path $TestDir -Filter $Filter -File | Sort-Object Name
    if ($TestFiles.Count -eq 0) {
        Write-Host "No test files matching '$Filter' in $TestDir"
    } else {
        Write-Host "Found $($TestFiles.Count) VG test file(s)"
        Write-Host ""
        foreach ($vg in $TestFiles) {
            $fname = $vg.Name
            $TotalFiles++
            "res://test_suite/$fname" | Set-Content -Path (Join-Path $Root 'test_proj/current_test.txt') -Encoding ASCII

            $job = Start-Job -ScriptBlock {
                param($G, $R, $Run)
                & $G --headless --path $R -s $Run 2>&1 | Out-String
            } -ArgumentList $Godot, (Join-Path $using:Root 'test_proj'), $Runner

            $done = Wait-Job $job -Timeout $TimeoutSec
            if (-not $done) {
                Stop-Job $job -Force -ErrorAction SilentlyContinue
                Remove-Job $job -Force -ErrorAction SilentlyContinue
                Write-Host "  ???  $fname  (timeout)"
                $ErrorFiles += "$fname (timeout)"
                $TotalError++
                continue
            }
            $output = Receive-Job $job
            Remove-Job $job -Force

            $passCount = ([regex]::Matches($output, '(?m)^PASS:')).Count
            $failCount = ([regex]::Matches($output, '(?m)^FAIL:')).Count

            if ($passCount -eq 0 -and $failCount -eq 0) {
                Write-Host "  ???  $fname  (no assertions)"
                $ErrorFiles += "$fname (no assertions)"
                $TotalError++
            } elseif ($failCount -gt 0) {
                Write-Host "  FAIL $fname  ($passCount passed, $failCount failed)"
                ($output -split "`n" | Where-Object { $_ -match '^FAIL:' }) | ForEach-Object { Write-Host "       $_" }
                $FailedFiles += $fname
            } else {
                Write-Host "  OK   $fname  ($passCount passed)"
            }
            $TotalPass += $passCount
            $TotalFail += $failCount
        }

        Write-Host ""
        Write-Host "=================================================="
        Write-Host "VG RESULTS:"
        Write-Host "  Files:      $TotalFiles"
        Write-Host "  Passed:     $TotalPass"
        Write-Host "  Failed:     $TotalFail"
        Write-Host "  Errors:     $TotalError"
        if ($TotalFail -gt 0 -or $TotalError -gt 0) { $ExitCode = 1 }
    }
}

# GDScript suites
$GdPs1 = Join-Path $Root 'tests/run_gd_tests.ps1'
if (Test-Path $GdPs1) {
    Write-Host ""
    Write-Host "-- GDScript suites (tests/) --"
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $GdPs1
    if ($LASTEXITCODE -ne 0) { $ExitCode = 1 }
}

# Narcea golden (requires Git Bash / WSL bash)
$GoldenSh = Join-Path $Root 'scripts/run_narcea_golden.sh'
$bash = Get-Command bash -ErrorAction SilentlyContinue
if ((Test-Path $GoldenSh) -and $bash) {
    Write-Host ""
    Write-Host "-- Narcea Golden Path (Tier A) --"
    & bash $GoldenSh --tier A
    if ($LASTEXITCODE -ne 0) { $ExitCode = 1 }
    Write-Host ""
    Write-Host "-- Narcea Golden Path (Tier B) --"
    & bash $GoldenSh --tier B
    if ($LASTEXITCODE -ne 0) { $ExitCode = 1 }
} elseif (Test-Path $GoldenSh) {
    Write-Host ""
    Write-Host "Skipping Narcea Golden (bash not found — install Git Bash or use WSL)."
}

if ($ExitCode -eq 0) {
    Write-Host ""
    Write-Host "All tests passed!"
}
exit $ExitCode
