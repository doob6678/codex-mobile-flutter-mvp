[CmdletBinding()]
param(
    [string]$Urls,
    [string]$DefaultProjects,
    [switch]$NoTunnel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'bridge-tunnel.ps1')

function Get-BridgeUrlParts {
    param([string]$BindUrls)

    foreach ($url in ($BindUrls -split ';')) {
        $trimmed = $url.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        if ($trimmed -notmatch '^(?<scheme>https?)://(?<host>[^/:]+)(:(?<port>\d+))?') {
            continue
        }

        $scheme = $Matches['scheme'].ToLowerInvariant()
        $hostName = $Matches['host']
        $portText = $Matches['port']
        if ([string]::IsNullOrWhiteSpace($portText)) {
            if ($scheme -eq 'https') {
                $portText = '443'
            }
            else {
                $portText = '80'
            }
        }

        [pscustomobject]@{
            Scheme = $scheme
            Host = $hostName
            Port = [int]$portText
        }
    }
}

function Get-BridgeWindowsConnectUrls {
    param([string]$BindUrls)

    $urls = New-Object System.Collections.Generic.List[string]
    foreach ($part in (Get-BridgeUrlParts -BindUrls $BindUrls)) {
        $hostName = $part.Host
        if ($hostName -in @('0.0.0.0', '*', '+')) {
            $hostName = '127.0.0.1'
        }

        $urls.Add("$($part.Scheme)://$hostName`:$($part.Port)/connect")
    }

    if ($urls.Count -eq 0) {
        $urls.Add('http://127.0.0.1:5010/connect')
    }

    $urls | Select-Object -Unique
}

function Get-BridgePhoneBaseUrls {
    param(
        [string]$BindUrls,
        [string]$ExternalUrlsFile
    )

    $urls = New-Object System.Collections.Generic.List[string]

    foreach ($part in (Get-BridgeUrlParts -BindUrls $BindUrls)) {
        if ($part.Host -notin @('0.0.0.0', '*', '+', '127.0.0.1', 'localhost')) {
            $urls.Add("$($part.Scheme)://$($part.Host):$($part.Port)")
            continue
        }

        try {
            [System.Net.Dns]::GetHostAddresses([System.Net.Dns]::GetHostName()) |
                Where-Object { $_.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetwork } |
                ForEach-Object { $_.IPAddressToString } |
                Where-Object { $_ -ne '127.0.0.1' -and $_ -ne '0.0.0.0' } |
                Sort-Object -Unique |
                ForEach-Object { $urls.Add("$($part.Scheme)://$_`:$($part.Port)") }
        }
        catch {
            Write-Verbose "Could not enumerate LAN addresses: $($_.Exception.Message)"
        }
    }

    foreach ($external in (Get-ConfiguredExternalBridgeUrls -ExternalUrlsFile $ExternalUrlsFile)) {
        $urls.Add($external)
    }

    $urls | Select-Object -Unique
}

function Get-ConfiguredExternalBridgeUrls {
    param([string]$ExternalUrlsFile)

    $values = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($env:CODEX_MOBILE_EXTERNAL_BRIDGE_URLS)) {
        foreach ($url in ($env:CODEX_MOBILE_EXTERNAL_BRIDGE_URLS -split '[;,]')) {
            if (-not [string]::IsNullOrWhiteSpace($url)) {
                $values.Add($url.Trim().TrimEnd('/'))
            }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($ExternalUrlsFile) -and (Test-Path -LiteralPath $ExternalUrlsFile)) {
        Get-Content -LiteralPath $ExternalUrlsFile -Encoding UTF8 |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            ForEach-Object { $values.Add($_.Trim().TrimEnd('/')) }
    }

    $values | Select-Object -Unique
}

function Test-BridgePortAvailable {
    param([int]$Port)

    $listener = $null
    try {
        $listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Any, $Port)
        $listener.Start()
        return $true
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $listener) {
            $listener.Stop()
        }
    }
}

function Resolve-BridgeLaunch {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..') -ErrorAction SilentlyContinue
    if ($repoRoot) {
        $project = Join-Path $repoRoot 'bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj'
        if (Test-Path -LiteralPath $project) {
            return [pscustomobject]@{
                Root = $repoRoot.Path
                FilePath = 'dotnet'
                Arguments = @('run', '--no-restore', '--no-launch-profile', '--project', 'bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj')
            }
        }
    }

    $exe = Join-Path $PSScriptRoot 'CodexMobile.Bridge.exe'
    if (Test-Path -LiteralPath $exe) {
        return [pscustomobject]@{
            Root = $PSScriptRoot
            FilePath = $exe
            Arguments = @()
        }
    }

    $dll = Join-Path $PSScriptRoot 'CodexMobile.Bridge.dll'
    if (Test-Path -LiteralPath $dll) {
        return [pscustomobject]@{
            Root = $PSScriptRoot
            FilePath = 'dotnet'
            Arguments = @('.\CodexMobile.Bridge.dll')
        }
    }

    throw 'Bridge launch target not found. Run from the repo scripts folder or from a packaged Bridge folder.'
}

$Launch = Resolve-BridgeLaunch
Set-Location $Launch.Root

$env:DOTNET_CLI_HOME = Join-Path $Launch.Root '.dotnet_home'
$env:NUGET_PACKAGES = Join-Path $Launch.Root '.nuget_packages'
$ExternalUrlsFile = Join-Path $Launch.Root 'bridge-external-urls.txt'
$env:CODEX_MOBILE_EXTERNAL_BRIDGE_URLS_FILE = $ExternalUrlsFile
$UsingDefaultUrls = $false
if ($PSBoundParameters.ContainsKey('Urls') -and -not [string]::IsNullOrWhiteSpace($Urls)) {
    $env:ASPNETCORE_URLS = $Urls
}
else {
    Remove-Item Env:\ASPNETCORE_URLS -ErrorAction SilentlyContinue
    $Urls = 'http://0.0.0.0:5010'
    $UsingDefaultUrls = $true
}
$env:CODEX_MOBILE_NO_BROWSER = '1'

if ($UsingDefaultUrls -and -not (Test-BridgePortAvailable -Port 5010)) {
    throw 'Bridge default port 5010 is already occupied. Close the old CodexMobile.Bridge/dotnet process, or start with a fixed explicit URL such as -Urls http://0.0.0.0:51910.'
}

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

$TunnelProcess = $null
if (-not $NoTunnel) {
    $TunnelProcess = Start-BridgeExternalTunnel `
        -Root $Launch.Root `
        -Port (Get-BridgeFirstPort -BindUrls $Urls) `
        -ExternalUrlsFile $ExternalUrlsFile
}

$windowsConnectUrls = @(Get-BridgeWindowsConnectUrls -BindUrls $Urls)
$phoneBaseUrls = @(Get-BridgePhoneBaseUrls -BindUrls $Urls -ExternalUrlsFile $ExternalUrlsFile)

Write-Host "Codex Mobile Bridge"
Write-Host "Requested bind URLs: $Urls"
Write-Host "Default port is fixed at 5010. It will not auto-switch to a random port; pass -Urls to choose another fixed port."
Write-Host "Windows QR page, open on this PC only:"
$windowsConnectUrls | ForEach-Object { Write-Host "  $_" }
Write-Host "Phone Bridge base URLs, use in Android app or QR payload:"
if ($phoneBaseUrls.Count -gt 0) {
    $phoneBaseUrls | ForEach-Object { Write-Host "  $_" }
}
else {
    Write-Host "  No LAN/VPN/tunnel URL detected. Install/start a tunnel or bind to a real LAN/VPN address."
}
Write-Host "Important: 127.0.0.1 is Windows-only. A physical phone must use a LAN/VPN address such as 10.x/192.168.x/100.x, or an HTTPS tunnel URL."
if (-not [string]::IsNullOrWhiteSpace($env:CODEX_MOBILE_DEFAULT_PROJECTS)) {
    Write-Host "Default projects: $env:CODEX_MOBILE_DEFAULT_PROJECTS"
}
Write-Host "Pairing: open the Windows QR page above, scan it from Android, and keep OpenAI/Codex keys on Windows; the phone receives only a short-lived Bridge token."

try {
    $launchArgs = @($Launch.Arguments)
    & $Launch.FilePath @launchArgs
}
finally {
    Stop-BridgeExternalTunnel -Process $TunnelProcess
}
