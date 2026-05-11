# Install whisper.cpp + a small English model for VG's AI Pair voice mode.
#
# Total download: ~85 MB (binary ~10 MB + ggml-tiny.en.bin ~75 MB).  Files
# land in %LOCALAPPDATA%\VisualGasic\whisper\.  VG's voice cfg is updated
# automatically so the mic button works on next Godot launch with no
# OpenAI API key required.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\install_whisper.ps1
#
# Override download URL or model with:
#   $Env:WHISPER_BIN_URL = '<custom .zip url>'
#   $Env:WHISPER_MODEL   = 'ggml-base.en.bin'   # default ggml-tiny.en.bin

$ErrorActionPreference = 'Stop'

$Dest = if ($Env:WHISPER_DIR) { $Env:WHISPER_DIR } else { Join-Path $Env:LOCALAPPDATA 'VisualGasic\whisper' }
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Set-Location $Dest

# Latest prebuilt CPU build for x64 Windows.  Pinned to a known-good
# release; users who want GPU/SIMD variants can set WHISPER_BIN_URL.
$WhisperRelease = 'v1.7.1'
$BinZip         = 'whisper-bin-x64.zip'
$BinUrl = if ($Env:WHISPER_BIN_URL) { $Env:WHISPER_BIN_URL } else {
    "https://github.com/ggerganov/whisper.cpp/releases/download/$WhisperRelease/$BinZip"
}

$Model = if ($Env:WHISPER_MODEL) { $Env:WHISPER_MODEL } else { 'ggml-base.en.bin' }
$ModelUrl = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/$Model"

Write-Host "[1/2] Installing whisper.cpp binary into $Dest ..."
$WhisperExe = Join-Path $Dest 'whisper.exe'
if (-not (Test-Path $WhisperExe)) {
    Invoke-WebRequest -Uri $BinUrl -OutFile $BinZip -UseBasicParsing
    Expand-Archive -Path $BinZip -DestinationPath $Dest -Force
    Remove-Item $BinZip
    # Releases ship the binary as either main.exe or whisper-cli.exe
    # depending on version.  Normalise to whisper.exe so VG's cfg has a
    # stable path.
    $cands = @('whisper-cli.exe','main.exe','whisper.exe') |
        ForEach-Object { Join-Path $Dest $_ } | Where-Object { Test-Path $_ }
    if ($cands.Count -eq 0) {
        # Some zips nest the binary under a Release\ subdirectory.
        $cands = Get-ChildItem -Path $Dest -Recurse -Include 'whisper-cli.exe','main.exe' |
                 Select-Object -ExpandProperty FullName
    }
    if ($cands.Count -eq 0) {
        throw "Could not find whisper-cli.exe or main.exe inside $BinZip"
    }
    if ($cands[0] -ne $WhisperExe) {
        Copy-Item -Path $cands[0] -Destination $WhisperExe -Force
    }
    Write-Host "      done."
} else {
    Write-Host "      already installed."
}

Write-Host "[2/2] Downloading model $Model (~75 MB) ..."
$ModelPath = Join-Path $Dest $Model
if (-not (Test-Path $ModelPath)) {
    Invoke-WebRequest -Uri $ModelUrl -OutFile $ModelPath -UseBasicParsing
    Write-Host "      done."
} else {
    Write-Host "      already installed."
}

Write-Host ""
Write-Host "  whisper installed at $WhisperExe"
Write-Host "  model:               $ModelPath"
Write-Host ""

# Pre-configure VG so STT uses local Whisper on next launch.  Without
# this, users without an OpenAI key still hit the API-key error.  Edit
# every existing project's vg_ai_voice.cfg in place when present so we
# don't overwrite a Piper config the user already has.
$GodotData = Join-Path $Env:APPDATA 'Godot\app_userdata'
if (Test-Path $GodotData) {
    $WBin   = $WhisperExe -replace '\\','\\'
    $WModel = $ModelPath  -replace '\\','\\'
    Get-ChildItem $GodotData -Directory | ForEach-Object {
        $cfgPath = Join-Path $_.FullName 'vg_ai_voice.cfg'
        if (Test-Path $cfgPath) {
            $text = Get-Content -Raw -Path $cfgPath
            function Set-Kv([string]$t, [string]$key, [string]$val) {
                $line = "$key=`"$val`""
                if ($t -match "(?m)^$([regex]::Escape($key))=.*$") {
                    return [regex]::Replace($t, "(?m)^$([regex]::Escape($key))=.*$", $line)
                } else {
                    return $t.TrimEnd() + "`r`n" + $line + "`r`n"
                }
            }
            $text = Set-Kv $text 'stt_backend'       'whisper'
            $text = Set-Kv $text 'whisper_cpp_path'  $WBin
            $text = Set-Kv $text 'whisper_cpp_model' $WModel
            Set-Content -Path $cfgPath -Value $text -Encoding UTF8
        } else {
            $Cfg = @"
[voice]

stt_backend="whisper"
tts_backend="openai"
tts_voice="alloy"
auto_speak_replies=true
whisper_cpp_path="$WBin"
whisper_cpp_model="$WModel"
piper_path="piper"
piper_voice_path=""
"@
            Set-Content -Path $cfgPath -Value $Cfg -Encoding UTF8
        }
        Write-Host "  Configured: $cfgPath"
    }
}

Write-Host ""
Write-Host "Restart Godot — the mic button in AI Pair will now use local"
Write-Host "Whisper automatically (no OpenAI key, no network)."
