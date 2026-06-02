[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot
$env:DOTNET_CLI_HOME = Join-Path $RepoRoot '.dotnet_home'
$env:NUGET_PACKAGES = Join-Path $RepoRoot '.nuget_packages'

$DistRoot = Join-Path $RepoRoot 'dist'
New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null

Write-Host "==> Publishing Windows Bridge"
$bridgeOut = Join-Path $DistRoot 'bridge-framework-dependent'
dotnet publish 'bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj' `
    -c Release `
    --no-self-contained `
    -p:SelfContained=false `
    -p:PublishSingleFile=false `
    -p:PublishTrimmed=false `
    -o $bridgeOut
if ($LASTEXITCODE -ne 0) {
    throw "Bridge publish failed."
}

$bridgeExeOut = Join-Path $DistRoot 'bridge-windows'
Write-Host "==> Publishing Windows Bridge self-contained exe"
dotnet publish 'bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj' `
    -c Release `
    -r win-x64 `
    --self-contained true `
    -p:SelfContained=true `
    -p:PublishSingleFile=true `
    -p:PublishTrimmed=false `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o $bridgeExeOut
if ($LASTEXITCODE -ne 0) {
    throw "Windows Bridge exe publish failed."
}

Copy-Item -Force -Path 'scripts\start-bridge.ps1' -Destination (Join-Path $bridgeOut 'start-bridge.ps1')
Copy-Item -Force -Path 'scripts\start-bridge.ps1' -Destination (Join-Path $bridgeExeOut 'start-bridge.ps1')
Copy-Item -Force -Path 'scripts\bridge-tunnel.ps1' -Destination (Join-Path $bridgeOut 'bridge-tunnel.ps1')
Copy-Item -Force -Path 'scripts\bridge-tunnel.ps1' -Destination (Join-Path $bridgeExeOut 'bridge-tunnel.ps1')

if (Test-Path -LiteralPath 'mobile_app' -PathType Container) {
    Push-Location 'mobile_app'
    try {
        Write-Host "==> Building Flutter Android APK"
        flutter build apk --release
        if ($LASTEXITCODE -eq 0) {
            $apkOut = Join-Path $DistRoot 'mobile-android'
            New-Item -ItemType Directory -Force -Path $apkOut | Out-Null
            Copy-Item -Force -Path 'build\app\outputs\flutter-apk\app-release.apk' -Destination $apkOut
        }
        else {
            Write-Host "Android APK build skipped or failed; Bridge package remains available."
        }

        Write-Host "==> Building Flutter Windows client when the toolchain is available"
        flutter build windows --release
        if ($LASTEXITCODE -eq 0) {
            $windowsOut = Join-Path $DistRoot 'mobile-windows'
            New-Item -ItemType Directory -Force -Path $windowsOut | Out-Null
            Copy-Item -Recurse -Force -Path 'build\windows\x64\runner\Release\*' -Destination $windowsOut
        }
        else {
            Write-Host "Windows client build skipped or failed; Bridge and Android artifacts remain available."
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host "==> Package output: $DistRoot"
