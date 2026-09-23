$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$RootDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $RootDir

$BaselineWebSnapshot = $null
$IsRunningOnMac = $false
$MacVariable = Get-Variable -Name IsMacOS -ErrorAction SilentlyContinue
if ($null -ne $MacVariable) {
    $IsRunningOnMac = [bool]$MacVariable.Value
}

# Flutter rewrites these tracked platform registrants during `pub get`/build.
# They are derived artifacts, not Roadmap 2 source files. On Windows they can
# also oscillate between LF/CRLF. They are therefore excluded from the clean
# source-tree gate; every other tracked/untracked path still blocks validation.
$FlutterGeneratedFiles = @(
    'apps/app_mobile/linux/flutter/generated_plugin_registrant.cc',
    'apps/app_mobile/linux/flutter/generated_plugin_registrant.h',
    'apps/app_mobile/linux/flutter/generated_plugins.cmake',
    'apps/app_mobile/macos/Flutter/GeneratedPluginRegistrant.swift',
    'apps/app_mobile/windows/flutter/generated_plugin_registrant.cc',
    'apps/app_mobile/windows/flutter/generated_plugin_registrant.h',
    'apps/app_mobile/windows/flutter/generated_plugins.cmake'
)

function Get-WorkingTreePathFromPorcelainLine {
    param([Parameter(Mandatory = $true)][string]$Line)

    if ($Line.Length -lt 4) { return $null }
    $Path = $Line.Substring(3).Trim()
    if ($Path -like '* -> *') {
        $Path = ($Path -split ' -> ')[-1].Trim()
    }
    if ($Path.StartsWith('"') -and $Path.EndsWith('"')) {
        $Path = $Path.Substring(1, $Path.Length - 2)
    }
    return $Path.Replace('\', '/')
}

function Get-BlockingWorkingTreeChanges {
    $StatusLines = @(git status --porcelain=v1 --untracked-files=all)
    if ($LASTEXITCODE -ne 0) {
        throw 'Unable to inspect Git working tree.'
    }

    $Blocking = @()
    foreach ($Line in $StatusLines) {
        if ([string]::IsNullOrWhiteSpace($Line)) { continue }

        $Path = Get-WorkingTreePathFromPorcelainLine -Line $Line
        if ($null -eq $Path) { continue }

        if ($FlutterGeneratedFiles -contains $Path) {
            Write-Host "INFO: ignoring regenerated Flutter platform artifact: $Path"
            continue
        }

        $Blocking += $Line
    }

    return $Blocking
}

try {
    Write-Host '== STK Haven Roadmap 2.0 final local validation =='
    Write-Host "Repository: $RootDir"
    $Commit = (git rev-parse HEAD).Trim()
    if ($LASTEXITCODE -ne 0) { throw 'Unable to resolve current Git commit.' }
    Write-Host "Commit: $Commit"
    Write-Host ''

    $BlockingChanges = @(Get-BlockingWorkingTreeChanges)
    if ($BlockingChanges.Count -gt 0) {
        Write-Host 'ERROR: working tree contains source changes outside allowed generated Flutter artifacts.'
        $BlockingChanges | ForEach-Object { Write-Host $_ }
        throw 'Working tree is not clean.'
    }

    & (Join-Path $PSScriptRoot 'validate_local.ps1')

    Write-Host ''
    Write-Host '[R2-1/6] Web widget/responsive tests'
    Push-Location 'apps/app_web'
    try {
        flutter pub get
        if ($LASTEXITCODE -ne 0) { throw 'Web flutter pub get failed.' }
        flutter test
        if ($LASTEXITCODE -ne 0) { throw 'Web tests failed.' }
    }
    finally {
        Pop-Location
    }

    Write-Host ''
    Write-Host '[R2-2/6] Android profile + distribution artifacts (Android entrypoint only)'
    Push-Location 'apps/app_mobile'
    try {
        flutter build apk --profile --target lib/main_android.dart
        if ($LASTEXITCODE -ne 0) { throw 'Android profile APK build failed.' }
        flutter build appbundle --release --target lib/main_android.dart
        if ($LASTEXITCODE -ne 0) { throw 'Android AAB release build failed.' }
        flutter build apk --release --split-per-abi --target lib/main_android.dart
        if ($LASTEXITCODE -ne 0) { throw 'Android split-per-ABI build failed.' }
    }
    finally {
        Pop-Location
    }

    Write-Host ''
    Write-Host '[R2-3/6] Preserve the exact validated dart2js Pages artifact'
    $WebBuild = Join-Path $RootDir 'apps/app_web/build/web'
    if (-not (Test-Path $WebBuild -PathType Container)) {
        throw 'Baseline web artifact is missing after validate_local.ps1.'
    }

    $BaselineWebSnapshot = Join-Path ([System.IO.Path]::GetTempPath()) ("stk-haven-web-dart2js-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $BaselineWebSnapshot | Out-Null
    Copy-Item -Path (Join-Path $WebBuild '*') -Destination $BaselineWebSnapshot -Recurse -Force
    Write-Host "Baseline dart2js artifact: $BaselineWebSnapshot"

    Write-Host ''
    Write-Host '[R2-4/6] Build optional WebAssembly comparison artifact'
    Push-Location 'apps/app_web'
    try {
        flutter build web --release --wasm --base-href '/STK-Haven/'
        if ($LASTEXITCODE -ne 0) { throw 'WebAssembly comparison build failed.' }

        $WasmTarget = Join-Path (Get-Location) 'build/web-wasm-roadmap2'
        if (Test-Path $WasmTarget) { Remove-Item $WasmTarget -Recurse -Force }
        New-Item -ItemType Directory -Path $WasmTarget | Out-Null
        Copy-Item -Path 'build/web/*' -Destination $WasmTarget -Recurse -Force
        Write-Host "WASM comparison artifact: $WasmTarget"
    }
    finally {
        Pop-Location
    }

    Write-Host ''
    Write-Host '[R2-5/6] Restore exact validated dart2js artifact for Pages'
    if (Test-Path $WebBuild) { Remove-Item $WebBuild -Recurse -Force }
    New-Item -ItemType Directory -Path $WebBuild | Out-Null
    Copy-Item -Path (Join-Path $BaselineWebSnapshot '*') -Destination $WebBuild -Recurse -Force

    $RequiredFiles = @(
        'apps/app_web/build/web/index.html',
        'apps/app_web/build/web/flutter_bootstrap.js',
        'apps/app_web/build/web/sw.js'
    )
    foreach ($Required in $RequiredFiles) {
        if (-not (Test-Path $Required -PathType Leaf)) {
            throw "Restored validated Pages artifact is missing $Required"
        }
    }

    Write-Host ''
    Write-Host '[R2-6/6] iOS profile build when running on macOS (iOS entrypoint only)'
    if ($IsRunningOnMac) {
        Push-Location 'apps/app_mobile'
        try {
            flutter build ios --profile --no-codesign --target lib/main_ios.dart
            if ($LASTEXITCODE -ne 0) { throw 'iOS profile build failed.' }
        }
        finally {
            Pop-Location
        }
    }
    else {
        Write-Host 'SKIP: iOS profile build and physical-device profiling require macOS.'
    }

    $BlockingAfterValidation = @(Get-BlockingWorkingTreeChanges)
    if ($BlockingAfterValidation.Count -gt 0) {
        Write-Host 'ERROR: validation produced unexpected source-tree changes.'
        $BlockingAfterValidation | ForEach-Object { Write-Host $_ }
        throw 'Validation changed source files unexpectedly.'
    }

    Write-Host ''
    Write-Host '== Roadmap 2.0 artifact summary =='
    Get-ChildItem 'apps/app_mobile/build/app/outputs/flutter-apk/*.apk' -ErrorAction SilentlyContinue | Select-Object FullName, Length
    Get-ChildItem 'apps/app_mobile/build/app/outputs/bundle/release/*.aab' -ErrorAction SilentlyContinue | Select-Object FullName, Length

    Write-Host ''
    Write-Host 'SUCCESS: Roadmap 2.0 local build/test matrix available on this machine passed.'
    Write-Host 'IMPORTANT: apps/app_web/build/web is the exact validated dart2js Pages artifact.'
    Write-Host 'WASM comparison is retained separately at apps/app_web/build/web-wasm-roadmap2.'
    Write-Host 'Physical Android/iOS profile checks, golden approval and browser/PWA smoke checks remain manual audit items.'
}
finally {
    if ($BaselineWebSnapshot -and (Test-Path $BaselineWebSnapshot)) {
        Remove-Item $BaselineWebSnapshot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
