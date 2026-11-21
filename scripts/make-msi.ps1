# Builds the Windows installer (an MSI) from the `flutter build windows`
# output, using WiX Toolset v5 (`dotnet tool install --global wix --version 5.0.2`).
# v5 rather than v6: v6 requires accepting the Open Source Maintenance Fee
# EULA, and v5 does everything this installer needs.
# Usage: scripts/make-msi.ps1 -Version 1.2.3 -Out Flights-windows.msi
param(
  [Parameter(Mandatory)] [string] $Version,
  [Parameter(Mandatory)] [string] $Out
)
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$appDir = Join-Path $root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $appDir 'Flights.exe'))) {
  throw "No Flights.exe in $appDir; run 'flutter build windows --release' first."
}
# MSI versions are up to three plain numbers; drop anything like "+42".
$msiVersion = ($Version -split '[+-]')[0]

wix build (Join-Path $root 'windows\installer\Flights.wxs') `
  -arch x64 `
  -d "Version=$msiVersion" `
  -d "AppDir=$appDir" `
  -d "IconFile=$(Join-Path $root 'windows\runner\resources\app_icon.ico')" `
  -o $Out
if ($LASTEXITCODE -ne 0) { throw "wix build failed ($LASTEXITCODE)" }
