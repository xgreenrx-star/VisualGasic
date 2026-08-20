# VisualGasic GDScript test runner (Windows)
# Usage: .\tests\run_gd_tests.ps1 [filter]

param(
    [string]$Filter = "test_*.gd"
)

$ErrorActionPreference = 'Continue'
$Root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$Godot = $env:VG_GODOT
if (-not $Godot) {
    foreach ($c in @(
        (Join-Path $Root 'Godot_v4.6.1-stable_win64.exe'),
        (Join-Path $Root 'Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $Root 'godot.exe')
    )) { if (Test-Path $c) { $Godot = $c; break } }
}
$HostProject = Join-Path $Root 'game_projects/AGCK_Tests'
$TestsDir = Join-Path $Root 'tests'
$TimeoutSec = 45

if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "Godot binary not found. Set VG_GODOT or place Godot_v4.6.1-stable_win64.exe in repo root."
    exit 2
}
if (-not (Test-Path (Join-Path $HostProject 'project.godot'))) {
    Write-Error "Host project not found at $HostProject"
    exit 2
}

$TestFiles = Get-ChildItem -Path $TestsDir -Filter $Filter -File | Sort-Object Name
if ($TestFiles.Count -eq 0) {
    Write-Host "No GD tests matching '$Filter' in $TestsDir"
    exit 0
}

$TotalPass = 0
$TotalFail = 0
$SuitesOk = 0
$SuitesBad = 0
$FailedSuites = @()

foreach ($tf in $TestFiles) {
    $name = $tf.Name
    $staged = Join-Path $HostProject '_gd_test_running.gd'
    Copy-Item -Force $tf.FullName $staged
    $fixturesStaged = Join-Path $HostProject '_gd_fixtures'
    if (Test-Path $fixturesStaged) { Remove-Item -Recurse -Force $fixturesStaged }
    $fixturesSrc = Join-Path $TestsDir 'fixtures'
    if (Test-Path $fixturesSrc) { Copy-Item -Recurse $fixturesSrc $fixturesStaged }

    $head = Get-Content -Path $staged -TotalCount 5 -ErrorAction SilentlyContinue
    $isSceneTree = $head -match '^extends\s+SceneTree\b'

    $job = Start-Job -ScriptBlock {
        param($G, $HP, $Script)
        & $G --headless --path $HP -s $Script 2>&1 | Out-String
    } -ArgumentList $Godot, $HostProject, $(if ($isSceneTree) { '_gd_test_running.gd' } else { '_gd_test_runner.gd' })

    if (-not $isSceneTree) {
        $wrapper = Join-Path $HostProject '_gd_test_runner.gd'
        @'
extends SceneTree
func _init():
    var s = load("res://_gd_test_running.gd")
    if s == null:
        printerr("[gd-runner] cannot load staged test")
        quit(1)
        return
    var n: Node = s.new()
    root.add_child(n)
'@ | Set-Content -Path $wrapper -Encoding UTF8
    }

    $completed = Wait-Job $job -Timeout $TimeoutSec
    if (-not $completed) {
        Stop-Job $job -Force -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
        Write-Host "  ??? $name (timeout)"
        $SuitesBad++
        $FailedSuites += "$name (timeout)"
        continue
    }
    $output = Receive-Job $job
    Remove-Job $job -Force

    Remove-Item -Force $staged -ErrorAction SilentlyContinue
    Remove-Item -Force (Join-Path $HostProject '_gd_test_runner.gd') -ErrorAction SilentlyContinue
    if (Test-Path $fixturesStaged) { Remove-Item -Recurse -Force $fixturesStaged }

    $line = ($output -split "`n" | Where-Object { $_ -match '^RESULTS: \d+/\d+ passed, \d+ failed' } | Select-Object -Last 1)
    if (-not $line) {
        Write-Host "  ??? $name (no RESULTS line)"
        $SuitesBad++
        $FailedSuites += "$name (no results)"
        ($output -split "`n" | Select-Object -Last 5) | ForEach-Object { Write-Host "      $_" }
        continue
    }
    if ($line -match '^RESULTS: (\d+)/(\d+) passed, (\d+) failed') {
        $p = [int]$Matches[1]
        $t = [int]$Matches[2]
        $f = [int]$Matches[3]
        $TotalPass += $p
        $TotalFail += $f
        if ($f -gt 0) {
            Write-Host "  FAIL $name  ($p/$t passed, $f failed)"
            $SuitesBad++
            $FailedSuites += $name
        } else {
            Write-Host "  OK   $name  ($p/$t passed)"
            $SuitesOk++
        }
    }
}

Write-Host ""
Write-Host "=================================================="
Write-Host "GD TESTS: $($TestFiles.Count) suite(s)  |  $TotalPass passed  |  $TotalFail failed"
if ($SuitesBad -gt 0) {
    Write-Host "Failing suites:"
    foreach ($s in $FailedSuites) { Write-Host "  - $s" }
    exit 1
}
exit 0
