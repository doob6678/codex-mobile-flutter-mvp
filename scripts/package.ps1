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
    --no-restore `
    --no-self-contained `
    -p:SelfContained=false `
    -p:PublishSingleFile=false `
    -p:PublishTrimmed=false `
    -o $bridgeOut
if ($LASTEXITCODE -ne 0) {
    throw "Bridge publish failed."
}

$bridgeRunner = @'
[CmdletBinding()]
param(
    [string]$Urls = 'http://0.0.0.0:5010',
    [string]$DefaultProjects
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Set-Location $PSScriptRoot
$env:ASPNETCORE_URLS = $Urls

if ([string]::IsNullOrWhiteSpace($DefaultProjects)) {
    $knowledgeRoot = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE 'Desktop') -Directory -Recurse -Filter 'AgentScope-Java-Harness-*' -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
    if (-not [string]::IsNullOrWhiteSpace($knowledgeRoot)) {
        $DefaultProjects = "AgentScope Java Harness Knowledge Base=$knowledgeRoot"
    }
}

if (-not [string]::IsNullOrWhiteSpace($DefaultProjects)) {
    $env:CODEX_MOBILE_DEFAULT_PROJECTS = $DefaultProjects
}

Write-Host "Codex Mobile Bridge"
Write-Host "Bind URLs: $env:ASPNETCORE_URLS"
if (-not [string]::IsNullOrWhiteSpace($env:CODEX_MOBILE_DEFAULT_PROJECTS)) {
    Write-Host "Default projects: $env:CODEX_MOBILE_DEFAULT_PROJECTS"
}

dotnet .\CodexMobile.Bridge.dll
'@
Set-Content -LiteralPath (Join-Path $bridgeOut 'start-bridge.ps1') -Encoding UTF8 -Value $bridgeRunner

if (Test-Path -LiteralPath 'mobile_app' -PathType Container) {
    Push-Location 'mobile_app'
    try {
        Write-Host "==> Building Flutter Windows client"
        flutter build windows --release
        if ($LASTEXITCODE -ne 0) {
            throw "Flutter Windows build failed."
        }

        $windowsOut = Join-Path $DistRoot 'mobile-windows'
        New-Item -ItemType Directory -Force -Path $windowsOut | Out-Null
        Copy-Item -Recurse -Force -Path 'build\windows\x64\runner\Release\*' -Destination $windowsOut

        Write-Host "==> Building Flutter Android APK when Android toolchain is available"
        flutter build apk --release
        if ($LASTEXITCODE -eq 0) {
            $apkOut = Join-Path $DistRoot 'mobile-android'
            New-Item -ItemType Directory -Force -Path $apkOut | Out-Null
            Copy-Item -Force -Path 'build\app\outputs\flutter-apk\app-release.apk' -Destination $apkOut
        }
        else {
            Write-Host "Android APK build skipped or failed; Windows client and Bridge package remain available."
        }
    }
    finally {
        Pop-Location
    }
}

Write-Host "==> Package output: $DistRoot"
