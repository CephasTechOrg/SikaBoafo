# Requires Flutter on PATH. Run from repo root: .\scripts\bootstrap_mobile.ps1
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..\mobile")

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Error "flutter not found. Install Flutter and add it to PATH."
}

if (-not (Test-Path "android")) {
    Write-Host "Creating platform projects with flutter create..."
    flutter create . --org com.biztrackgh.app --project-name biztrack_gh
}

flutter pub get
flutter analyze
flutter test
