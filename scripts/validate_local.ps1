$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $RootDir

$IsRunningOnMac = $false
$MacVariable = Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue
if ($null -ne $MacVariable) {
    $IsRunningOnMac = [bool]$MacVariable.Value
}

Write-Host '== STK Haven local validation =='
Write-Host "Repository: $RootDir"
Write-Host ''

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    throw 'Flutter is not available in PATH.'
}

flutter --version
if ($LASTEXITCODE -ne 0) { throw 'flutter --version failed.' }

Write-Host ''
Write-Host '[1/7] Resolve workspace dependencies'
flutter pub get
if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed at workspace root.' }

Write-Host ''
Write-Host '[2/7] Analyze workspace'
flutter analyze --no-fatal-infos
if ($LASTEXITCODE -ne 0) { throw 'flutter analyze failed.' }

Write-Host ''
Write-Host '[3/7] Test shared core'
Push-Location 'packages/core'
try {
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Core tests failed.' }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host '[4/7] Test mobile app'
Push-Location 'apps/app_mobile'
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Mobile flutter pub get failed.' }
    flutter test
    if ($LASTEXITCODE -ne 0) { throw 'Mobile tests failed.' }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host '[5/7] Build Android debug + release (Android entrypoint only)'
Push-Location 'apps/app_mobile'
try {
    flutter build apk --debug --target lib/main_android.dart
    if ($LASTEXITCODE -ne 0) { throw 'Android debug APK build failed.' }
    flutter build apk --release --target lib/main_android.dart
    if ($LASTEXITCODE -ne 0) { throw 'Android release APK build failed.' }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host '[6/7] Build web release for GitHub Pages'
Push-Location 'apps/app_web'
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { throw 'Web flutter pub get failed.' }
    flutter build web --release --base-href '/STK-Haven/'
    if ($LASTEXITCODE -ne 0) { throw 'Web release build failed.' }
}
finally {
    Pop-Location
}

Write-Host ''
Write-Host '[7/7] Build iOS release without signing (iOS entrypoint only)'
if ($IsRunningOnMac) {
    if (-not (Get-Command pod -ErrorAction SilentlyContinue)) {
        throw 'CocoaPods is required for the iOS validation step.'
    }

    Push-Location 'apps/app_mobile/ios'
    try {
        pod install
        if ($LASTEXITCODE -ne 0) { throw 'pod install failed.' }
    }
    finally {
        Pop-Location
    }

    Push-Location 'apps/app_mobile'
    try {
        flutter build ios --release --no-codesign --target lib/main_ios.dart
        if ($LASTEXITCODE -ne 0) { throw 'iOS release build failed.' }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Host 'SKIP: iOS build requires macOS. Run this script on a Mac to reproduce the full local matrix.'
}

Write-Host ''
Write-Host 'SUCCESS: all validation steps available on this machine passed.'
