$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

uv sync
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

uv run pyinstaller `
    --noconfirm `
    --clean `
    --onefile `
    --name pyZDL `
    --specpath build `
    --icon "$root\assets\pyzdl-launcher.ico" `
    --add-data "$root\assets;assets" `
    cli.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

uv run pyinstaller `
    --noconfirm `
    --clean `
    --onefile `
    --windowed `
    --name pyZDL-setup `
    --specpath build `
    --icon "$root\assets\pyzdl-launcher.ico" `
    --add-data "$root\dist\pyZDL.exe;payload" `
    pyzdl_setup.py
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Built dist\pyZDL.exe and dist\pyZDL-setup.exe"
