[CmdletBinding()]
param(
    [string]$Urls = 'http://0.0.0.0:5010',
    [string]$DefaultProjects
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot

$env:DOTNET_CLI_HOME = Join-Path $RepoRoot '.dotnet_home'
$env:NUGET_PACKAGES = Join-Path $RepoRoot '.nuget_packages'
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
Write-Host "Open /network/interfaces after pairing to see phone connection URLs."

dotnet run --no-restore --no-launch-profile --project bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj
