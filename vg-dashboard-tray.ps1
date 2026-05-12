# vg-dashboard-tray.ps1 — Browser Dashboard with tray icon (Windows)

[CmdletBinding()]
param(
    [string]$Project = $env:VG_PROJECT_DIR,
    [int]$Port = 0,
    [string]$Bind = ""
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $Project) {
    if (Test-Path (Join-Path $PWD 'project.godot')) { $Project = (Get-Location).Path }
    elseif (Test-Path (Join-Path $ScriptDir 'test_proj/project.godot')) { $Project = Join-Path $ScriptDir 'test_proj' }
}
if (-not $Project -or -not (Test-Path (Join-Path $Project 'project.godot'))) {
    Write-Error "vg-dashboard-tray: no project.godot found. Pass -Project DIR."
}
if (-not (Test-Path (Join-Path $Project 'addons/visual_gasic/vg_dashboard_tray.gd'))) {
    Write-Error "vg-dashboard-tray: addons/visual_gasic/ missing in $Project."
}

$Godot = $env:VG_GODOT
if (-not $Godot) {
    foreach ($c in @(
        (Join-Path $ScriptDir 'Godot_v4.6.1-stable_win64.exe'),
        (Join-Path $ScriptDir 'Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $ScriptDir 'godot.exe')
    )) { if (Test-Path $c) { $Godot = $c; break } }
}
if (-not $Godot -or -not (Test-Path $Godot)) {
    Write-Error "vg-dashboard-tray: Godot binary not found. Set VG_GODOT."
}

$Pass = @()
if ($Port -gt 0) { $Pass += "--port=$Port" }
if ($Bind)       { $Pass += "--bind=$Bind" }

# No --headless: tray icon needs a real display server.
& $Godot --path $Project `
    -s 'addons/visual_gasic/vg_dashboard_tray.gd' `
    -- @Pass
