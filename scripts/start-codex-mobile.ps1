[CmdletBinding()]
param(
    [string]$Urls,
    [string]$DefaultProjects,
    [switch]$NoTunnel,
    [switch]$SkipDesktop,
    [string]$CodexAppId = 'OpenAI.Codex_2p2nqsd0c76g0!App'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-CodexDesktopRunning {
    $processes = Get-Process -Name 'Codex' -ErrorAction SilentlyContinue
    foreach ($process in $processes) {
        try {
            if ($process.Path -like '*\OpenAI.Codex_*') {
                return $true
            }
        }
        catch {
            return $true
        }
    }

    return $false
}

function Start-CodexDesktop {
    param([string]$AppId)

    if (Test-CodexDesktopRunning) {
        Write-Host 'Codex desktop app is already running.'
        return
    }

    Write-Host 'Starting Codex desktop app...'
    Start-Process -FilePath 'explorer.exe' -ArgumentList "shell:AppsFolder\$AppId" | Out-Null

    $deadline = [DateTimeOffset]::Now.AddSeconds(15)
    while ([DateTimeOffset]::Now -lt $deadline) {
        Start-Sleep -Milliseconds 500
        if (Test-CodexDesktopRunning) {
            Write-Host 'Codex desktop app started.'
            return
        }
    }

    Write-Host 'Codex desktop app launch was requested, but the process was not detected within 15 seconds.'
}

$bridgeScript = Join-Path $PSScriptRoot 'start-bridge.ps1'
if (-not (Test-Path -LiteralPath $bridgeScript -PathType Leaf)) {
    throw "start-bridge.ps1 not found next to this script: $bridgeScript"
}

Write-Host 'Codex Mobile combined launcher'
Write-Host 'This starts the Windows Codex desktop app and the Codex Mobile Bridge from one command.'
Write-Host 'Note: on Windows, Codex app-server daemon/proxy lifecycle is not available, so this does not merge the Bridge process into the desktop app-server.'

if (-not $SkipDesktop) {
    Start-CodexDesktop -AppId $CodexAppId
}
else {
    Write-Host 'Skipping Codex desktop launch because -SkipDesktop was specified.'
}

$bridgeArgs = @{}
if ($PSBoundParameters.ContainsKey('Urls') -and -not [string]::IsNullOrWhiteSpace($Urls)) {
    $bridgeArgs['Urls'] = $Urls
}
if ($PSBoundParameters.ContainsKey('DefaultProjects') -and -not [string]::IsNullOrWhiteSpace($DefaultProjects)) {
    $bridgeArgs['DefaultProjects'] = $DefaultProjects
}
if ($NoTunnel) {
    $bridgeArgs['NoTunnel'] = $true
}

& $bridgeScript @bridgeArgs
