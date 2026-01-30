# VisualGasic Template Installer for Windows
# Usage: iwr -useb https://raw.githubusercontent.com/xgreenrx-star/VisualGasic/main/install.ps1 | iex

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "  VisualGasic Template Installer" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

# Set template directory
$TemplateDir = Join-Path $env:APPDATA "Godot\project_templates"
$InstallDir = Join-Path $TemplateDir "VisualGasic"

Write-Host "Installing to: $InstallDir"
Write-Host ""

# Create directory
New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null

# Download and extract
Write-Host "Downloading VisualGasic template..."
$TempDir = Join-Path $env:TEMP "visualgasic_install"
$ZipPath = Join-Path $TempDir "visualgasic.zip"

New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

try {
    # Download from GitHub
    $DownloadUrl = "https://github.com/xgreenrx-star/VisualGasic/archive/refs/heads/main.zip"
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $ZipPath -UseBasicParsing
    
    Write-Host "Extracting template..."
    Expand-Archive -Path $ZipPath -DestinationPath $TempDir -Force
    
    # Copy necessary files
    $SourceDir = Join-Path $TempDir "VisualGasic-main"
    
    # Copy addons
    if (Test-Path (Join-Path $SourceDir "addons")) {
        Copy-Item -Path (Join-Path $SourceDir "addons") -Destination $InstallDir -Recurse -Force
    }
    
    # Copy or create project.godot
    if (Test-Path (Join-Path $SourceDir "project.godot")) {
        Copy-Item -Path (Join-Path $SourceDir "project.godot") -Destination $InstallDir -Force
    } else {
        'project_name="VisualGasic Project"' | Out-File -FilePath (Join-Path $InstallDir "project.godot") -Encoding UTF8
    }
    
    # Create template configuration
    $TemplateConfig = @"
[template]
name="VisualGasic Project"
description="A new VisualGasic project with the language already installed and configured."
version="1.0.0"
icon="res://icon.svg"
"@
    $TemplateConfig | Out-File -FilePath (Join-Path $InstallDir ".template.cfg") -Encoding UTF8
    
    # Copy example scripts
    $ExamplesDir = Join-Path $InstallDir "examples"
    New-Item -ItemType Directory -Force -Path $ExamplesDir | Out-Null
    if (Test-Path (Join-Path $SourceDir "examples")) {
        Get-ChildItem -Path (Join-Path $SourceDir "examples\*.vg") -ErrorAction SilentlyContinue | 
            Copy-Item -Destination $ExamplesDir -ErrorAction SilentlyContinue
    }
    
} catch {
    Write-Host "Error during installation: $_" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    Remove-Item -Path $TempDir -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Green
Write-Host "  ✅ Installation Complete!" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""
Write-Host "VisualGasic template has been installed to:"
Write-Host "  $InstallDir" -ForegroundColor Yellow
Write-Host ""
Write-Host "To use it:"
Write-Host "  1. Open Godot"
Write-Host "  2. Create New Project"
Write-Host "  3. Select 'VisualGasic Project' from templates"
Write-Host "  4. Start coding in .vg files!"
Write-Host ""
Write-Host "Documentation: https://github.com/xgreenrx-star/VisualGasic"
Write-Host ""
