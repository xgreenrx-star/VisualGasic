# Install Piper neural TTS + the five voices VG personas use.
#
# Total download: ~340 MB.  Files land in %LOCALAPPDATA%\VisualGasic\piper\.
# VG auto-detects them on next launch — no further configuration needed.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\install_piper.ps1

$ErrorActionPreference = 'Stop'

$Dest = if ($Env:PIPER_DIR) { $Env:PIPER_DIR } else { Join-Path $Env:LOCALAPPDATA 'VisualGasic\piper' }
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Set-Location $Dest

$PiperVersion = '2023.11.14-2'
# Piper Windows release ships as a zip with a top-level piper\ folder.
$PiperZip = "piper_windows_amd64.zip"
$PiperUrl = "https://github.com/rhasspy/piper/releases/download/$PiperVersion/$PiperZip"

Write-Host "[1/2] Installing Piper binary into $Dest\piper\ ..."
if (-not (Test-Path "$Dest\piper\piper.exe")) {
    Invoke-WebRequest -Uri $PiperUrl -OutFile $PiperZip -UseBasicParsing
    Expand-Archive -Path $PiperZip -DestinationPath $Dest -Force
    Remove-Item $PiperZip
    Write-Host "      done."
} else {
    Write-Host "      already installed."
}

$Voices = @(
    'en_US-amy-medium',                      # default
    'en_US-hfc_female-medium',               # Narcea
    'en_US-ryan-medium',                     # Bob
    'en_GB-alan-medium',                     # Skippy
    'en_GB-northern_english_male-medium',    # Orac
    'en_US-lessac-medium'                    # HAL 9000
)

Write-Host "[2/2] Downloading voice models (6 x ~63 MB)..."
foreach ($v in $Voices) {
    if (Test-Path "$Dest\$v.onnx") {
        Write-Host "      $v  (already installed)"
        continue
    }
    $parts = $v.Split('-')
    $langRegion = $parts[0]                   # en_US
    $name       = $parts[1]                   # amy
    $quality    = $parts[2]                   # medium
    $lang       = $langRegion.Split('_')[0]   # en
    $base       = "https://huggingface.co/rhasspy/piper-voices/resolve/main/$lang/$langRegion/$name/$quality/$v"
    Write-Host "      $v ..."
    Invoke-WebRequest -Uri "$base.onnx"      -OutFile "$Dest\$v.onnx"      -UseBasicParsing
    Invoke-WebRequest -Uri "$base.onnx.json" -OutFile "$Dest\$v.onnx.json" -UseBasicParsing
}

Write-Host ""
Write-Host "  Piper installed at $Dest"
Write-Host "  Voices: $($Voices -join ', ')"
Write-Host ""

# Pre-configure VG's voice settings so Piper is used immediately on next
# launch — without this the user would have to flip tts_backend in the
# Voice Settings dialog manually.  Each Godot project keeps its own
# user:// folder under app_userdata; we write the config into every
# project we can find so the change "just works" on the first project
# the user opens after install.
$GodotData = Join-Path $Env:APPDATA 'Godot\app_userdata'
if (Test-Path $GodotData) {
    $PiperBin = Join-Path $Dest 'piper\piper.exe'
    $PiperVoice = Join-Path $Dest 'en_US-amy-medium.onnx'
    $Cfg = @"
[voice]

stt_backend="openai"
tts_backend="piper"
tts_voice="alloy"
auto_speak_replies=true
whisper_cpp_path="whisper"
whisper_cpp_model=""
piper_path="$($PiperBin -replace '\\','\\')"
piper_voice_path="$($PiperVoice -replace '\\','\\')"
"@
    Get-ChildItem $GodotData -Directory | ForEach-Object {
        $cfgPath = Join-Path $_.FullName 'vg_ai_voice.cfg'
        Set-Content -Path $cfgPath -Value $Cfg -Encoding UTF8
        Write-Host "  Configured: $cfgPath"
    }
}

Write-Host ""
Write-Host "Restart Godot and switch any AI Pair persona -- voice mode now uses"
Write-Host "Piper neural TTS automatically (no extra config needed)."
