# vg-ide.ps1 — VisualGasic IDE launcher (Windows)
#
# PowerShell counterpart of the POSIX `vg-ide` script.
#
# Skips Godot's Project Manager. On launch:
#   1. If a project path is provided as an arg, opens that.
#   2. Else, by default, opens the VG Welcome shell so the user can pick
#      a recent project, browse, or ask Narcea to scaffold a new one.
#   3. With -Last (or $env:VG_OPEN_LAST = '1'), reopens the most-recent
#      project directly without showing the welcome window.
#
# Usage:
#   .\vg-ide.ps1
#   .\vg-ide.ps1 -Last
#   .\vg-ide.ps1 'C:\path\to\MyProject'
#
# Override discovery with environment variables:
#   $env:VG_GODOT       = 'C:\Tools\Godot.exe'
#   $env:VG_OPEN_LAST   = '1'

[CmdletBinding()]
param(
    [switch]$Last,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

$ErrorActionPreference = 'Stop'

if ($env:VG_OPEN_LAST -eq '1') { $Last = $true }

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

# ── Locate the Godot binary ─────────────────────────────────────────────────
$GodotBin = $env:VG_GODOT
if (-not $GodotBin) {
    $candidates = @(
        (Join-Path $ScriptDir 'Godot_v4.6.1-stable_win64.exe'),
        (Join-Path $ScriptDir 'Godot_v4.5.1-stable_win64.exe'),
        (Join-Path $ScriptDir 'godot.exe'),
        (Join-Path $ScriptDir 'Godot.exe'),
        'C:\Program Files\Godot\Godot.exe',
        'C:\Program Files\VisualGasic\Godot.exe',
        (Join-Path $env:LOCALAPPDATA 'Programs\Godot\Godot.exe'),
        (Join-Path $env:LOCALAPPDATA 'visual_gasic\Godot.exe')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c -PathType Leaf) {
            $GodotBin = $c
            break
        }
    }
}
if (-not $GodotBin) {
    $cmd = Get-Command -Name 'godot','godot.exe','Godot.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($cmd) { $GodotBin = $cmd.Source }
}
if (-not $GodotBin -or -not (Test-Path -LiteralPath $GodotBin -PathType Leaf)) {
    Write-Error "vg-ide: could not locate the Godot binary. Set `$env:VG_GODOT or place Godot.exe next to this script."
    exit 1
}

# ── Recent-projects config ──────────────────────────────────────────────────
function Get-FirstRecent {
    $cfg = Join-Path $env:APPDATA 'VisualGasic\recent_projects.cfg'
    if (-not (Test-Path -LiteralPath $cfg -PathType Leaf)) { return $null }
    $line = Select-String -LiteralPath $cfg -Pattern '"path"\s*:\s*"([^"]+)"' -List -ErrorAction SilentlyContinue |
            Select-Object -First 1
    if ($line -and $line.Matches.Count -gt 0) {
        return $line.Matches[0].Groups[1].Value
    }
    return $null
}

# ── Dispatch ────────────────────────────────────────────────────────────────
function Start-Editor {
    param([string]$Path, [string[]]$Extra)
    $argList = @('--path', $Path, '--editor') + ($Extra | Where-Object { $_ })
    & $GodotBin @argList
    exit $LASTEXITCODE
}

# 1. Explicit project-dir arg.
if ($Args.Count -gt 0) {
    $first = $Args[0]
    if ((Test-Path -LiteralPath $first -PathType Container) -and
        (Test-Path -LiteralPath (Join-Path $first 'project.godot') -PathType Leaf)) {
        Start-Editor -Path $first -Extra ($Args | Select-Object -Skip 1)
    }
}

# 2. -Last / $env:VG_OPEN_LAST=1 → most-recent project directly.
if ($Last) {
    $lastDir = Get-FirstRecent
    if ($lastDir -and (Test-Path -LiteralPath (Join-Path $lastDir 'project.godot') -PathType Leaf)) {
        Start-Editor -Path $lastDir -Extra $Args
    }
    Write-Warning "vg-ide: -Last requested but no usable recent project found."
}

# 3. Default: open the bundled Welcome shell.
$welcomeCandidates = @(
    (Join-Path $ScriptDir 'welcome_shell'),
    'C:\Program Files\VisualGasic\welcome_shell',
    (Join-Path $env:LOCALAPPDATA 'visual_gasic\welcome_shell')
)
$WelcomeDir = $null
foreach ($c in $welcomeCandidates) {
    if (Test-Path -LiteralPath (Join-Path $c 'project.godot') -PathType Leaf) {
        $WelcomeDir = $c
        break
    }
}
if ($WelcomeDir) {
    & $GodotBin '--path' $WelcomeDir @Args
    exit $LASTEXITCODE
}

# 4. Fallbacks: most-recent project, then bare Godot PM.
$lastDir = Get-FirstRecent
if ($lastDir -and (Test-Path -LiteralPath (Join-Path $lastDir 'project.godot') -PathType Leaf)) {
    Start-Editor -Path $lastDir -Extra $Args
}
& $GodotBin @Args
exit $LASTEXITCODE
