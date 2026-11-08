param(
    [string]$Compiler = "C:\Program Files\PureBasic\Compilers\pbcompiler.exe",
    [switch]$SkipTests
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

if (-not (Test-Path $Compiler)) {
    throw "PureBasic compiler not found at $Compiler"
}

$icon = Join-Path $PSScriptRoot "..\assets\pyzdl-launcher.ico"
New-Item -ItemType Directory -Force -Path "build" | Out-Null

function Invoke-Compile($source, $output, $extra) {
    & $Compiler $source @extra /OUTPUT $output
    if ($LASTEXITCODE -ne 0) { throw "Compiling $source failed." }
}

Invoke-Compile "pyzdl.pb" "build\pyZDL.exe" @("/CONSOLE", "/ICON", $icon)

if (-not $SkipTests) {
    Invoke-Compile "tests\tests.pb" "build\tests.exe" @("/CONSOLE")
    & "build\tests.exe"
    if ($LASTEXITCODE -ne 0) { throw "Unit tests failed." }
}

Invoke-Compile "setup\pyzdl-setup.pb" "build\pyZDL-setup.exe" @("/ICON", $icon)

Write-Host "Built purebasic\build\pyZDL.exe and purebasic\build\pyZDL-setup.exe"
