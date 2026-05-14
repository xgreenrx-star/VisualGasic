# VisualGasic Installer for Windows (PowerShell)
# Installs the VisualGasic addon globally and the `vg` CLI tool
#
# Usage:
#   irm https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.ps1 | iex
#
# Or run locally:
#   .\install.ps1
#
# After installation:
#   vg new MyGame
#   cd MyGame ; godot .

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║     VisualGasic Installer             ║" -ForegroundColor Cyan
Write-Host "  ║    VB6-style language for Godot 4     ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# ── Paths ───────────────────────────────────────────────────────────────────
$VG_GLOBAL_DIR = Join-Path $env:APPDATA "VisualGasic"
$BIN_DIR = Join-Path $env:USERPROFILE ".local\bin"
$VG_ADDON_DIR = Join-Path $VG_GLOBAL_DIR "addons\visual_gasic"

Write-Host "  Platform:  Windows" -ForegroundColor Gray
Write-Host "  Install:   $VG_GLOBAL_DIR" -ForegroundColor Gray
Write-Host "  CLI tool:  $BIN_DIR\vg.cmd" -ForegroundColor Gray
Write-Host ""

# ── Download ────────────────────────────────────────────────────────────────
$REPO_URL = "https://github.com/xgreenrx-star/VisualGasic"
$TEMP_DIR = Join-Path $env:TEMP "vg_install_$(Get-Random)"

# Default: download the latest release (including pre-releases/Beta tags).
# Override with $env:VG_INSTALL_TAG = "vX.Y.Z" or $env:VG_INSTALL_REF = "main".
$Tag = $env:VG_INSTALL_TAG
$Ref = $env:VG_INSTALL_REF

try {
    New-Item -ItemType Directory -Path $TEMP_DIR -Force | Out-Null
    $zipPath = Join-Path $TEMP_DIR "visualgasic.zip"

    if (-not $Tag -and -not $Ref) {
        Write-Host "  Looking up latest release..." -ForegroundColor Cyan
        try {
            $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/xgreenrx-star/VisualGasic/releases" -UseBasicParsing
            if ($releases -and $releases.Count -gt 0) {
                $Tag = $releases[0].tag_name
            }
        } catch {
            Write-Host "  ⚠ Could not query latest release; falling back to main." -ForegroundColor Yellow
        }
    }

    if ($Tag) {
        $ARCHIVE_URL = "$REPO_URL/archive/refs/tags/$Tag.zip"
        $SOURCE_SUBDIR = "VisualGasic-" + ($Tag -replace '^v','')
        Write-Host "  Downloading release $Tag from GitHub..." -ForegroundColor Cyan
    } else {
        if (-not $Ref) { $Ref = "main" }
        $ARCHIVE_URL = "$REPO_URL/archive/refs/heads/$Ref.zip"
        $SOURCE_SUBDIR = "VisualGasic-$Ref"
        Write-Host "  Downloading $Ref branch from GitHub..." -ForegroundColor Cyan
    }

    Invoke-WebRequest -Uri $ARCHIVE_URL -OutFile $zipPath -UseBasicParsing

    Write-Host "  Extracting..." -ForegroundColor Cyan
    Expand-Archive -Path $zipPath -DestinationPath $TEMP_DIR -Force
    $SOURCE_DIR = Join-Path $TEMP_DIR $SOURCE_SUBDIR
    if (-not (Test-Path $SOURCE_DIR)) {
        $SOURCE_DIR = (Get-ChildItem -Path $TEMP_DIR -Directory | Select-Object -First 1).FullName
    }

    # ── Install addon globally ──────────────────────────────────────────────
    Write-Host "  Installing addon..." -ForegroundColor Cyan

    $addonParent = Join-Path $VG_GLOBAL_DIR "addons"
    New-Item -ItemType Directory -Path $addonParent -Force | Out-Null

    # Remove old install
    if (Test-Path $VG_ADDON_DIR) {
        Remove-Item -Recurse -Force $VG_ADDON_DIR
    }

    # Copy addon
    $srcAddon = Join-Path $SOURCE_DIR "addons\visual_gasic"
    Copy-Item -Recurse -Path $srcAddon -Destination $VG_ADDON_DIR

    # Remove .uid files
    Get-ChildItem -Path $VG_ADDON_DIR -Recurse -Filter "*.uid" | Remove-Item -Force

    # Copy VERSION
    $verSrc = Join-Path $SOURCE_DIR "VERSION"
    if (Test-Path $verSrc) {
        Copy-Item $verSrc (Join-Path $VG_GLOBAL_DIR "VERSION")
    }

    # ── Install vg CLI tool ─────────────────────────────────────────────────
    Write-Host "  Installing 'vg' CLI tool..." -ForegroundColor Cyan
    New-Item -ItemType Directory -Path $BIN_DIR -Force | Out-Null

    # Copy the bash script
    $vgSrc = Join-Path $SOURCE_DIR "vg"
    if (Test-Path $vgSrc) {
        Copy-Item $vgSrc (Join-Path $BIN_DIR "vg")
    }

    # Create Windows .cmd wrapper (works without WSL/bash for basic commands)
    $vgCmd = Join-Path $BIN_DIR "vg.cmd"
    @"
@echo off
REM VisualGasic CLI for Windows
REM If you have Git Bash or WSL installed, this wraps the bash script.
REM Otherwise it handles 'vg new' and 'vg install' natively.

setlocal enabledelayedexpansion

if "%~1"=="" goto :help
if "%~1"=="help" goto :help
if "%~1"=="--help" goto :help
if "%~1"=="version" goto :version
if "%~1"=="new" goto :new
if "%~1"=="install" goto :install
if "%~1"=="update" goto :update

echo Unknown command: %~1
echo Run: vg help
exit /b 1

:help
echo.
echo   VisualGasic CLI
echo   Usage:
echo     vg new ^<project-name^>    Create a new VG-ready Godot project
echo     vg install               Install VG into the current Godot project
echo     vg update                Update global VG installation
echo     vg version               Show version info
echo     vg help                  Show this help
echo.
exit /b 0

:version
set "VG_VER=unknown"
if exist "%APPDATA%\VisualGasic\VERSION" set /p VG_VER=<"%APPDATA%\VisualGasic\VERSION"
echo VisualGasic CLI
echo   Version: %VG_VER%
echo   Addon: %APPDATA%\VisualGasic
exit /b 0

:new
if "%~2"=="" (
    echo Error: Usage: vg new ^<project-name^>
    exit /b 1
)

set "PROJ=%~2"
set "VG_SRC=%APPDATA%\VisualGasic\addons\visual_gasic"

if not exist "%VG_SRC%\plugin.cfg" (
    echo Error: VisualGasic is not installed globally.
    echo   Re-run the installer: install.ps1
    exit /b 1
)

if exist "%PROJ%" (
    echo Error: Directory '%PROJ%' already exists.
    exit /b 1
)

echo Creating project: %PROJ%
mkdir "%PROJ%\addons"
xcopy /E /I /Q "%VG_SRC%" "%PROJ%\addons\visual_gasic" >nul

(
echo config_version=5
echo.
echo [application]
echo.
echo config/name="%PROJ%"
echo config/features=PackedStringArray^("4.6", "Forward Plus"^)
echo config/icon="res://icon.svg"
echo.
echo [autoload]
echo.
echo VGDebugHandler="*res://addons/visual_gasic/vg_debug_handler.gd"
echo.
echo [editor_plugins]
echo.
echo enabled=PackedStringArray^("res://addons/visual_gasic/plugin.cfg"^)
) > "%PROJ%\project.godot"

(
echo ' Form1.vg -- Your first VisualGasic form
echo Option Explicit
echo.
echo Private Sub Form_Load^(^)
echo     Me.Caption = "Hello World"
echo     Me.Width = 800
echo     Me.Height = 600
echo     Print "Welcome to VisualGasic!"
echo End Sub
) > "%PROJ%\Form1.vg"

echo.
echo   Project '%PROJ%' created!
echo.

REM Auto-launch Godot editor (skip with --no-open)
set "NO_OPEN=0"
if "%~3"=="--no-open" set "NO_OPEN=1"

if "%NO_OPEN%"=="1" (
    echo   Next: cd %PROJ% ^&^& godot --path . --editor
    echo.
    exit /b 0
)

REM Locate Godot binary
set "GODOT_BIN="
if defined VG_GODOT (
    set "GODOT_BIN=%VG_GODOT%"
) else (
    for %%G in (godot.exe Godot.exe godot) do (
        where %%G >nul 2>&1 && set "GODOT_BIN=%%G" && goto :godot_found
    )
    for %%G in (
        "%APPDATA%\VisualGasic\Godot.exe"
        "%LOCALAPPDATA%\Programs\Godot\Godot.exe"
        "C:\Program Files\Godot\Godot.exe"
    ) do (
        if exist %%G set "GODOT_BIN=%%G" && goto :godot_found
    )
)
:godot_found

if defined GODOT_BIN (
    echo   Opening project in Godot editor...  (use --no-open to skip)
    echo.
    start "" "%GODOT_BIN%" --path "%CD%\%PROJ%" --editor
) else (
    echo   Next: cd %PROJ% ^&^& godot --path . --editor
    echo   (Godot not found in PATH -- install Godot 4.6 to enable auto-open)
    echo.
)
exit /b 0

:install
if not exist "project.godot" (
    echo Error: No project.godot in current directory.
    exit /b 1
)

set "VG_SRC=%APPDATA%\VisualGasic\addons\visual_gasic"
if not exist "%VG_SRC%\plugin.cfg" (
    echo Error: VisualGasic is not installed globally.
    exit /b 1
)

if not exist "addons" mkdir addons
if exist "addons\visual_gasic" rmdir /s /q "addons\visual_gasic"
xcopy /E /I /Q "%VG_SRC%" "addons\visual_gasic" >nul

echo VisualGasic installed into current project.
echo Enable it in Project ^> Project Settings ^> Plugins if needed.
exit /b 0

:update
echo Use install.ps1 or install.py to update the global installation.
exit /b 0
"@ | Out-File -Encoding ASCII $vgCmd

    # ── Check PATH ──────────────────────────────────────────────────────────
    $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
    if ($userPath -notlike "*$BIN_DIR*") {
        Write-Host ""
        Write-Host "  ⚠ $BIN_DIR is not in your PATH." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  To add it permanently, run:" -ForegroundColor Gray
        Write-Host "    [Environment]::SetEnvironmentVariable('Path', `$env:Path + ';$BIN_DIR', 'User')" -ForegroundColor White
        Write-Host ""

        # Offer to add automatically
        $addPath = Read-Host "  Add to PATH now? (y/N)"
        if ($addPath -eq "y" -or $addPath -eq "Y") {
            [Environment]::SetEnvironmentVariable("Path", "$userPath;$BIN_DIR", "User")
            $env:Path = "$env:Path;$BIN_DIR"
            Write-Host "  ✅ Added to PATH. Restart your terminal to take effect." -ForegroundColor Green
        }
    }

    # ── Summary ─────────────────────────────────────────────────────────────
    $vgVer = "unknown"
    $verFile = Join-Path $VG_GLOBAL_DIR "VERSION"
    if (Test-Path $verFile) { $vgVer = Get-Content $verFile -Raw }

    $fileCount = (Get-ChildItem -Recurse -File $VG_ADDON_DIR | Measure-Object).Count
    $dirSize = "{0:N0} MB" -f ((Get-ChildItem -Recurse -File $VG_ADDON_DIR | Measure-Object -Property Length -Sum).Sum / 1MB)

    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "  ║     ✅ Installation Complete!         ║" -ForegroundColor Green
    Write-Host "  ╚══════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Version:  $vgVer"
    Write-Host "  Files:    $fileCount files ($dirSize)"
    Write-Host "  Addon:    $VG_GLOBAL_DIR"
    Write-Host "  CLI:      $vgCmd"
    Write-Host ""
    Write-Host "  Quick Start:" -ForegroundColor White
    Write-Host "    vg new MyGame        # Create a new VG project"
    Write-Host "    cd MyGame ; godot .  # Open in Godot"
    Write-Host ""
    Write-Host "  Add VG to existing project:" -ForegroundColor White
    Write-Host "    cd C:\path\to\project"
    Write-Host "    vg install"
    Write-Host ""
}
finally {
    # Cleanup
    if (Test-Path $TEMP_DIR) {
        Remove-Item -Recurse -Force $TEMP_DIR -ErrorAction SilentlyContinue
    }
}
