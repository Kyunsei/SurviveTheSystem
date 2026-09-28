# Rebuilds the ThreadBench GDExtension. Run from anywhere.
# Requires: godot-cpp cloned as .\godot-cpp (see SETUP.md), SCons installed.

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$vcvars = "C:\Program Files\Microsoft Visual Studio\18\Insiders\VC\Auxiliary\Build\vcvars64.bat"
if (-not (Test-Path $vcvars)) {
    Write-Host "vcvars64.bat not found at expected path -- edit build.ps1 if your VS install differs." -ForegroundColor Yellow
}

$env:SCONS_MSVC_SCRIPT = $vcvars
cmd /c "`"$vcvars`" && python -m SCons platform=windows target=template_debug -j16"

Write-Host "`nBuild finished. If you added/changed the .gdextension file itself (not just the C++), re-run the project scan:" -ForegroundColor Cyan
Write-Host '  godot.exe --headless --editor --quit-after 60 --path "path\to\project"'
