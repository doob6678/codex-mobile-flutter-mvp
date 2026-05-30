[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $RepoRoot
$env:DOTNET_CLI_HOME = Join-Path $RepoRoot '.dotnet_home'
$env:NUGET_PACKAGES = Join-Path $RepoRoot '.nuget_packages'

function Write-Step {
    param([Parameter(Mandatory = $true)][string]$Message)
    Write-Host ""
    Write-Host "==> $Message"
}

function Assert-File {
    param([Parameter(Mandatory = $true)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Missing required file: $Path"
    }
}

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text
    )
    $content = Get-Content -LiteralPath $Path -Encoding UTF8 -Raw
    if (-not $content.Contains($Text)) {
        throw "Expected '$Text' in $Path"
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
    )
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
}

function Wait-HttpReady {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][int]$TimeoutSeconds
    )

    $deadline = [DateTimeOffset]::UtcNow.AddSeconds($TimeoutSeconds)
    while ([DateTimeOffset]::UtcNow -lt $deadline) {
        try {
            $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
                return
            }
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    }

    throw "Timed out waiting for $Url"
}

Write-Step "Checking documentation files"
$docFiles = @(
    'docs\protocol-assets.md',
    'docs\api.md',
    'docs\security.md',
    'docs\testing.md'
)
foreach ($file in $docFiles) {
    Assert-File $file
}

Write-Step "Checking generated Codex app-server protocol assets"
$assetFiles = @(
    'generated\codex-app-server-ts\ClientRequest.ts',
    'generated\codex-app-server-ts\ServerRequest.ts',
    'generated\codex-app-server-ts\ServerNotification.ts',
    'generated\codex-app-server-ts\v2\ThreadStartParams.ts',
    'generated\codex-app-server-schema\codex_app_server_protocol.v2.schemas.json'
)
foreach ($file in $assetFiles) {
    Assert-File $file
}

Write-Step "Parsing generated JSON schema"
$schemaText = Get-Content -LiteralPath 'generated\codex-app-server-schema\codex_app_server_protocol.v2.schemas.json' -Encoding UTF8 -Raw
$null = $schemaText | ConvertFrom-Json

Write-Step "Checking key JSON-RPC methods"
$clientRequest = 'generated\codex-app-server-ts\ClientRequest.ts'
$serverRequest = 'generated\codex-app-server-ts\ServerRequest.ts'
$clientMethods = @(
    'thread/start',
    'thread/list',
    'thread/read',
    'turn/start',
    'fs/readFile',
    'fs/readDirectory',
    'config/read',
    'account/read'
)
foreach ($method in $clientMethods) {
    Assert-Contains $clientRequest $method
}

$serverMethods = @(
    'item/commandExecution/requestApproval',
    'item/fileChange/requestApproval'
)
foreach ($method in $serverMethods) {
    Assert-Contains $serverRequest $method
}

if (Test-Path -LiteralPath 'bridge' -PathType Container) {
    Write-Step "Running backend tests"
    if (Test-Path -LiteralPath 'bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj' -PathType Leaf) {
        Invoke-Checked dotnet run --no-restore --project 'bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj'
    }

    if (Test-Path -LiteralPath 'bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj' -PathType Leaf) {
        Write-Step "Running backend HTTP smoke test"
        New-Item -ItemType Directory -Force -Path 'bridge\logs' | Out-Null
        $smokeUrl = 'http://127.0.0.1:51870'
        $previousAspNetCoreUrls = $env:ASPNETCORE_URLS
        $previousDotnetCliHome = $env:DOTNET_CLI_HOME
        $previousNugetPackages = $env:NUGET_PACKAGES
        $env:ASPNETCORE_URLS = $smokeUrl
        $env:DOTNET_CLI_HOME = Join-Path $RepoRoot '.dotnet_home'
        $env:NUGET_PACKAGES = Join-Path $RepoRoot '.nuget_packages'
        $startInfo = [System.Diagnostics.ProcessStartInfo]::new('dotnet')
        $startInfo.Arguments = 'run --no-restore --no-launch-profile --project bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj'
        $startInfo.WorkingDirectory = $RepoRoot
        $startInfo.UseShellExecute = $false
        $startInfo.CreateNoWindow = $true
        $server = [System.Diagnostics.Process]::Start($startInfo)
        try {
            Wait-HttpReady -Url "$smokeUrl/health" -TimeoutSeconds 60
            $health = Invoke-RestMethod -Uri "$smokeUrl/health" -UseBasicParsing
            if ($health.status -ne 'ok') {
                throw "Unexpected health status: $($health | ConvertTo-Json -Compress)"
            }

            $summary = Invoke-RestMethod -Uri "$smokeUrl/protocol/summary" -UseBasicParsing
            if (-not ($summary.supportedMethods -contains 'thread/start')) {
                throw "Protocol summary missing thread/start."
            }

            $pairing = Invoke-RestMethod -Method Post -Uri "$smokeUrl/pairing/start" -UseBasicParsing
            $token = Invoke-RestMethod -Method Post -Uri "$smokeUrl/pairing/complete" -ContentType 'application/json' -Body (@{ code = $pairing.code } | ConvertTo-Json -Compress) -UseBasicParsing
            $headers = @{ Authorization = "Bearer $($token.accessToken)" }
            $codexStatus = Invoke-RestMethod -Uri "$smokeUrl/codex/status" -Headers $headers -UseBasicParsing
            if ($null -eq $codexStatus.available -or [string]::IsNullOrWhiteSpace($codexStatus.message)) {
                throw "Codex app-server status response is malformed."
            }
        }
        finally {
            if ($server -and -not $server.HasExited) {
                Stop-Process -Id $server.Id -Force
                Wait-Process -Id $server.Id -Timeout 10 -ErrorAction SilentlyContinue
            }
            $env:ASPNETCORE_URLS = $previousAspNetCoreUrls
            $env:DOTNET_CLI_HOME = $previousDotnetCliHome
            $env:NUGET_PACKAGES = $previousNugetPackages
        }
    }
    elseif (Test-Path -LiteralPath 'CodexMobile.sln' -PathType Leaf) {
        Invoke-Checked dotnet test 'CodexMobile.sln'
    }
    else {
        Write-Host "bridge exists, but no test project or solution was found; skipping dotnet test."
    }
}
else {
    Write-Step "Skipping backend tests because bridge\ does not exist"
}

if (Test-Path -LiteralPath 'mobile_app' -PathType Container) {
    Write-Step "Running Flutter analysis and tests"
    Push-Location 'mobile_app'
    try {
        Invoke-Checked flutter analyze
        Invoke-Checked flutter test
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Step "Skipping Flutter checks because mobile_app\ does not exist"
}

Write-Step "Verification complete"
