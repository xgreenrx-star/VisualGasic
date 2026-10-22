# Install Sherpa-ONNX + Kokoro-82M English voices for Visual Gasic TTS.
#
# Total download: ~350 MB.  Files land in %LOCALAPPDATA%\VisualGasic\tts.
# VG auto-detects them on next launch — no extra Voice Settings step.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\install_kokoro.ps1

$ErrorActionPreference = 'Stop'

$SherpaVersion = if ($Env:SHERPA_VERSION) { $Env:SHERPA_VERSION } else { '1.13.8' }
$ModelName = 'kokoro-en-v0_19'
$Dest = if ($Env:KOKORO_DIR) { $Env:KOKORO_DIR } else { Join-Path $Env:LOCALAPPDATA 'VisualGasic\tts' }
$RuntimeArchive = "sherpa-onnx-v$SherpaVersion-win-x64-shared-MD-Release.tar.bz2"
$BinName = 'sherpa-onnx-offline-tts.exe'

New-Item -ItemType Directory -Force -Path (Join-Path $Dest 'runtime') | Out-Null
New-Item -ItemType Directory -Force -Path (Join-Path $Dest 'models') | Out-Null
Set-Location $Dest

Write-Host "[1/3] Installing Sherpa-ONNX runtime into $Dest\runtime ..."
$existing = Get-ChildItem -Path (Join-Path $Dest 'runtime') -Recurse -Filter $BinName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $existing) {
    $url = "https://github.com/k2-fsa/sherpa-onnx/releases/download/v$SherpaVersion/$RuntimeArchive"
    $archive = Join-Path $Dest $RuntimeArchive
    Invoke-WebRequest -Uri $url -OutFile $archive -UseBasicParsing
    tar -xjf $archive -C (Join-Path $Dest 'runtime') --strip-components=1
    Remove-Item $archive
    Write-Host "      done."
} else {
    Write-Host "      already installed."
}

$BinPath = Get-ChildItem -Path (Join-Path $Dest 'runtime') -Recurse -Filter $BinName | Select-Object -First 1
if (-not $BinPath) {
    throw "Could not find $BinName after extract."
}
$LibDir = Join-Path $Dest 'runtime\lib'
if (-not (Test-Path $LibDir)) {
    $LibDir = Join-Path $Dest 'runtime'
}

Write-Host "[2/4] Writing $Dest\vg-tts.cmd launcher ..."
$cmdPath = Join-Path $Dest 'vg-tts.cmd'
@"
@echo off
set PATH=$LibDir;%PATH%
"$($BinPath.FullName)" %*
"@ | Set-Content -Path $cmdPath -Encoding ASCII

Write-Host "[3/4] Building persistent Kokoro daemon ..."
$DaemonSrc = Join-Path $PSScriptRoot 'vg_tts_daemon.c'
$DaemonBin = Join-Path $Dest 'runtime\bin\vg-tts-daemon.exe'
$IncludeDir = Join-Path $Dest 'runtime\include'
New-Item -ItemType Directory -Force -Path (Join-Path $Dest 'runtime\bin') | Out-Null
$Gcc = Get-Command gcc -ErrorAction SilentlyContinue
if ((Test-Path $DaemonSrc) -and $Gcc) {
    & $Gcc.Source -O2 -o $DaemonBin $DaemonSrc "-I$IncludeDir" "-L$LibDir" -lsherpa-onnx-c-api
    $daemonCmd = Join-Path $Dest 'vg-tts-daemon.cmd'
    @"
@echo off
set PATH=$LibDir;%PATH%
"$DaemonBin" %*
"@ | Set-Content -Path $daemonCmd -Encoding ASCII
    Write-Host "      daemon ready."
} else {
    Write-Host "      skipped (need gcc and vg_tts_daemon.c). One-shot vg-tts still works, but each line reloads the model."
}

Write-Host "[4/4] Downloading Kokoro English pack (~320 MB) ..."
$modelOnnx = Join-Path $Dest "models\$ModelName\model.onnx"
if (Test-Path $modelOnnx) {
    Write-Host "      $ModelName  (already installed)"
} else {
    $modelUrl = "https://github.com/k2-fsa/sherpa-onnx/releases/download/tts-models/$ModelName.tar.bz2"
    $modelArchive = Join-Path $Dest "$ModelName.tar.bz2"
    Invoke-WebRequest -Uri $modelUrl -OutFile $modelArchive -UseBasicParsing
    tar -xjf $modelArchive -C (Join-Path $Dest 'models')
    Remove-Item $modelArchive
    Write-Host "      done."
}

if (-not (Test-Path $modelOnnx)) {
    throw "Kokoro model files missing after extract."
}

Write-Host ""
Write-Host "  Kokoro TTS installed at $Dest"
Write-Host "  Voices: af_bella, am_michael, bm_george, bm_lewis, ... (11 English speakers)"

$GodotData = Join-Path $Env:APPDATA 'Godot\app_userdata'
if (Test-Path $GodotData) {
    $Cfg = @"
[voice]

stt_backend="openai"
tts_backend="kokoro"
tts_voice="alloy"
auto_speak_replies=true
whisper_cpp_path="whisper"
whisper_cpp_model=""
piper_path="piper"
piper_voice_path=""
"@
    Get-ChildItem $GodotData -Directory | ForEach-Object {
        Set-Content -Path (Join-Path $_.FullName 'vg_ai_voice.cfg') -Value $Cfg -Encoding UTF8
        Write-Host "  Configured: $($_.FullName)\vg_ai_voice.cfg"
    }
}

Write-Host ""
Write-Host "Restart Godot. Vibe Code and Ash flight voice now use Kokoro when present."
Write-Host "Orac = bm_george, Narcea = af_nicole, Skippy = bm_lewis."
