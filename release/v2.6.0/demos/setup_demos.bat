@echo off
REM setup_demos.bat — Link each demo's addons\ to the shared top-level addon
REM Run this once after extracting the release zip:
REM   cd VisualGasic_v2.5.0
REM   demos\setup_demos.bat
REM
REM Requires Administrator privileges to create directory junctions.

set "SCRIPT_DIR=%~dp0"
set "ROOT_DIR=%SCRIPT_DIR%.."
set "ADDON_SRC=%ROOT_DIR%\addons\visual_gasic"

if not exist "%ADDON_SRC%\plugin.cfg" (
    echo ERROR: Cannot find %ADDON_SRC%
    echo Make sure you run this from the extracted release directory.
    exit /b 1
)

set count=0

for /d %%C in ("%SCRIPT_DIR%*") do (
    for /d %%P in ("%%C\*") do (
        if exist "%%P\project.godot" (
            if not exist "%%P\addons" mkdir "%%P\addons"
            if exist "%%P\addons\visual_gasic" rmdir /s /q "%%P\addons\visual_gasic" 2>nul
            mklink /J "%%P\addons\visual_gasic" "%ADDON_SRC%" >nul
            echo   OK %%~nC/%%~nP
            set /a count+=1
        )
    )
)

echo.
echo Linked %count% demo projects to shared addon.
echo Open any demo's project.godot in Godot 4.5+ to run it.
pause
