# vg-dashboard.ps1 — VisualGasic Browser Dashboard headless launcher (Windows)
#
# PowerShell sibling of ./vg-dashboard.  Runs the embedded HTTP dashboard
# server without opening the VG IDE.
#
# Usage:
#   .\vg-dashboard.ps1 [-Project DIR] [-Port N] [-Bind ADDR] [-Open]

[CmdletBinding()]
param(
    [string]$Project = $env:VG_PROJECT_DIR,
    [int]$Port = 0,
    [string]$Bind = "",
    [switch]$Open
)

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if (-not $Project) {
    if (Test-Path (Join-Path $PWD 'project.godot')) { $Project = (Get-Location).Path }
    elseif (Test-Path (Join-Path $ScriptDir 'test_proj/project.godot')) { $Project = Join-Path $ScriptDir 'test_proj' }
}
if (-not $Project -or -not (Test-Path (Join-Path $Project 'project.godot'))) {
    Write-Error "vg-dashboard: no project.godot found. Pass -Project DIR or set VG_PROJECT_DIR."
}
if (-not (Test-Path (Join-Path $Project 'addons/visual_gasic/vg_dashboard_headless.gd'))) {
    Write-Error "vg-dashboard: addons/visual_gasic/ missing in $Project."
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
    Write-Error "vg-dashboard: Godot binary not found. Set VG_GODOT=path\to\godot.exe."
}

$Pass = @()
if ($Port -gt 0) { $Pass += "--port=$Port" }
if ($Bind)       { $Pass += "--bind=$Bind" }

if ($Open) {
    $p = if ($Port -gt 0) { $Port } else { 8765 }
    $b = if ($Bind) { $Bind } else { '127.0.0.1' }
    $url = "http://${b}:${p}/"
    Start-Job -ScriptBlock {
        param($u, $h, $pt)
        for ($i = 0; $i -lt 60; $i++) {
            try {
                $c = New-Object System.Net.Sockets.TcpClient
                $c.Connect($h, $pt); $c.Close()
                Start-Process $u
                break
            } catch { Start-Sleep -Milliseconds 250 }
        }
    } -ArgumentList $url, $b, $p | Out-Null
}

& $Godot --headless --path $Project `
    -s 'addons/visual_gasic/vg_dashboard_headless.gd' `
    -- @Pass
