[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Net.Http

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

function Read-FirstSyncEvent {
    param(
        [Parameter(Mandatory = $true)][string]$Url,
        [Parameter(Mandatory = $true)][string]$Token
    )

    $client = [System.Net.Http.HttpClient]::new()
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Url)
    $request.Headers.Authorization = [System.Net.Http.Headers.AuthenticationHeaderValue]::new('Bearer', $Token)
    $request.Headers.Accept.ParseAdd('text/event-stream')
    try {
        $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        if (-not $response.IsSuccessStatusCode) {
            throw "Sync stream returned $([int]$response.StatusCode)."
        }

        $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $reader = [System.IO.StreamReader]::new($stream)
        try {
            $deadline = [DateTimeOffset]::UtcNow.AddSeconds(5)
            while ([DateTimeOffset]::UtcNow -lt $deadline) {
                $lineTask = $reader.ReadLineAsync()
                if (-not $lineTask.Wait(1000)) {
                    continue
                }

                $line = $lineTask.Result
                if ($line -and $line.StartsWith('data:')) {
                    return $line.Substring(5).Trim() | ConvertFrom-Json
                }
            }
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $request.Dispose()
        $client.Dispose()
    }

    throw "Timed out waiting for first sync stream event."
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
        $previousBridgeHosts = $env:CODEX_MOBILE_BRIDGE_HOSTS
        $previousAllowPublicBridge = $env:CODEX_MOBILE_ALLOW_PUBLIC_BRIDGE
        $previousDefaultProjects = $env:CODEX_MOBILE_DEFAULT_PROJECTS
        $env:ASPNETCORE_URLS = $smokeUrl
        $env:DOTNET_CLI_HOME = Join-Path $RepoRoot '.dotnet_home'
        $env:NUGET_PACKAGES = Join-Path $RepoRoot '.nuget_packages'
        $env:CODEX_MOBILE_BRIDGE_HOSTS = '127.0.0.1,192.168.55.44,100.72.10.9,8.8.8.8'
        $knowledgeRoot = Get-ChildItem -LiteralPath (Join-Path $env:USERPROFILE 'Desktop') -Directory -Recurse -Filter 'AgentScope-Java-Harness-*' -ErrorAction SilentlyContinue |
            Select-Object -First 1 -ExpandProperty FullName
        $knowledgeProjectName = 'AgentScope Java Harness Knowledge Base'
        $knowledgeRootExists = -not [string]::IsNullOrWhiteSpace($knowledgeRoot) -and (Test-Path -LiteralPath $knowledgeRoot -PathType Container)
        if ($knowledgeRootExists) {
            $env:CODEX_MOBILE_DEFAULT_PROJECTS = "$knowledgeProjectName=$knowledgeRoot"
        }
        Remove-Item Env:\CODEX_MOBILE_ALLOW_PUBLIC_BRIDGE -ErrorAction SilentlyContinue
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

            $network = Invoke-RestMethod -Uri "$smokeUrl/network/interfaces" -Headers $headers -UseBasicParsing
            if ($network.publicExposureAllowed) {
                throw "Public bridge exposure should be disabled by default."
            }
            if (-not ($network.endpoints.url -contains 'http://192.168.55.44:51870')) {
                throw "Private LAN bridge URL was not reported."
            }
            if (-not ($network.endpoints.url -contains 'http://100.72.10.9:51870')) {
                throw "Mesh/VPN bridge URL was not reported."
            }
            if ($network.endpoints.host -contains '8.8.8.8') {
                throw "Public bridge host leaked into default network summary."
            }

            $goal = Invoke-RestMethod -Method Post -Uri "$smokeUrl/goal" -Headers $headers -ContentType 'application/json' -Body (@{
                objective = 'verify mobile /goal bidirectional sync'
                status = 'active'
                source = 'verify-script'
            } | ConvertTo-Json -Compress) -UseBasicParsing
            if ($goal.objective -notlike '*bidirectional sync*') {
                throw "Goal response did not preserve objective."
            }

            $task = Invoke-RestMethod -Method Post -Uri "$smokeUrl/tasks" -Headers $headers -ContentType 'application/json' -Body (@{
                title = 'Verify sync task'
                detail = 'Create and complete a task through protected Bridge HTTP APIs'
            } | ConvertTo-Json -Compress) -UseBasicParsing
            $completed = Invoke-RestMethod -Method Post -Uri "$smokeUrl/tasks/$($task.id)/progress" -Headers $headers -ContentType 'application/json' -Body (@{
                status = 'completed'
                progressPercent = 100
                summary = 'Verified through HTTP smoke test'
            } | ConvertTo-Json -Compress) -UseBasicParsing
            if (($completed.status.ToString().ToLowerInvariant()) -ne 'completed' -or $completed.progressPercent -ne 100) {
                throw "Task progress did not reach completed state."
            }

            $syncState = Invoke-RestMethod -Uri "$smokeUrl/sync/state" -Headers $headers -UseBasicParsing
            if ($syncState.goal.objective -notlike '*bidirectional sync*') {
                throw "Sync snapshot did not include current goal."
            }
            if (-not ($syncState.tasks | Where-Object { $_.id -eq $task.id -and $_.status.ToString().ToLowerInvariant() -eq 'completed' })) {
                throw "Sync snapshot did not include completed task."
            }

            $syncEvent = Read-FirstSyncEvent -Url "$smokeUrl/sync/stream" -Token $token.accessToken
            if ($null -eq $syncEvent.updatedAt -or $null -eq $syncEvent.tasks) {
                throw "Sync stream first event was malformed."
            }

            if ($knowledgeRootExists) {
                $projects = Invoke-RestMethod -Uri "$smokeUrl/projects" -Headers $headers -UseBasicParsing
                if (-not ($projects | Where-Object { $_.name -eq $knowledgeProjectName })) {
                    throw "Default knowledge project was not loaded."
                }

                $knowledgeProject = $projects | Where-Object { $_.name -eq $knowledgeProjectName } | Select-Object -First 1
                $markdown = Invoke-RestMethod -Uri "$smokeUrl/files/read?projectId=$($knowledgeProject.id)&path=00-%E6%80%BB%E7%9B%AE%E5%BD%95.md" -Headers $headers -UseBasicParsing
                if ($markdown.language -ne 'markdown') {
                    throw "Knowledge base markdown was not marked as markdown."
                }
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
            $env:CODEX_MOBILE_BRIDGE_HOSTS = $previousBridgeHosts
            $env:CODEX_MOBILE_ALLOW_PUBLIC_BRIDGE = $previousAllowPublicBridge
            $env:CODEX_MOBILE_DEFAULT_PROJECTS = $previousDefaultProjects
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
        flutter analyze
        if ($LASTEXITCODE -ne 0) {
            throw "flutter analyze failed with exit code ${LASTEXITCODE}."
        }

        flutter test
        if ($LASTEXITCODE -ne 0) {
            throw "flutter test failed with exit code ${LASTEXITCODE}."
        }
    }
    finally {
        Pop-Location
    }
}
else {
    Write-Step "Skipping Flutter checks because mobile_app\ does not exist"
}

Write-Step "Verification complete"
