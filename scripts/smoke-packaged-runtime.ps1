param(
    [int]$Port = 51905,
    [string]$KnowledgeBasePath = ""
)

$ErrorActionPreference = "Stop"

$repo = (Get-Location).Path
$bridgeExe = Join-Path $repo "dist\bridge-windows"
$bridge = Join-Path $repo "dist\bridge-framework-dependent"
$outLog = Join-Path $repo "tmp-bridge-smoke.out.log"
$errLog = Join-Path $repo "tmp-bridge-smoke.err.log"

Remove-Item -LiteralPath $outLog -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $errLog -ErrorAction SilentlyContinue

if (Test-Path -LiteralPath (Join-Path $bridgeExe "CodexMobile.Bridge.exe")) {
    $bridgeRoot = $bridgeExe
    $bridgeFilePath = Join-Path $bridgeRoot "CodexMobile.Bridge.exe"
    $bridgeArguments = @()
}
elseif (Test-Path -LiteralPath (Join-Path $bridge "CodexMobile.Bridge.dll")) {
    $bridgeRoot = $bridge
    $bridgeFilePath = "dotnet"
    $bridgeArguments = @(".\CodexMobile.Bridge.dll")
}
else {
    throw "Packaged bridge executable or DLL not found."
}

$env:ASPNETCORE_URLS = "http://127.0.0.1:$Port"
$env:CODEX_MOBILE_NO_BROWSER = "1"
$env:CODEX_MOBILE_EXTERNAL_BRIDGE_URLS = "https://codex-mobile-smoke.example"
if ([string]::IsNullOrWhiteSpace($KnowledgeBasePath)) {
    $desktop = Join-Path $env:USERPROFILE "Desktop"
    $KnowledgeBasePath = Get-ChildItem `
        -LiteralPath $desktop `
        -Directory `
        -Recurse `
        -Filter "AgentScope-Java-Harness-*" `
        -ErrorAction SilentlyContinue |
        Select-Object -First 1 -ExpandProperty FullName
}

if (Test-Path -LiteralPath $KnowledgeBasePath) {
    $env:CODEX_MOBILE_DEFAULT_PROJECTS = "AgentScope Java Harness Knowledge Base=$KnowledgeBasePath"
}

$startArgs = @{
    FilePath = $bridgeFilePath
    WorkingDirectory = $bridgeRoot
    PassThru = $true
    WindowStyle = 'Hidden'
    RedirectStandardOutput = $outLog
    RedirectStandardError = $errLog
}

if ($bridgeArguments.Count -gt 0) {
    $startArgs.ArgumentList = $bridgeArguments
}

$process = Start-Process @startArgs

try {
    $baseUri = "http://127.0.0.1:$Port"
    $deadline = (Get-Date).AddSeconds(35)
    $health = $null

    do {
        try {
            $health = Invoke-RestMethod -Uri "$baseUri/health" -TimeoutSec 2
            break
        }
        catch {
            Start-Sleep -Milliseconds 500
        }
    } while ((Get-Date) -lt $deadline)

    if (-not $health) {
        throw "Bridge did not start on $baseUri"
    }

    $connectPage = Invoke-WebRequest -Uri "$baseUri/connect" -TimeoutSec 5
    $connectQrHasBridgeUrls = $connectPage.Content -match 'bridgeUrls'
    if (-not $connectQrHasBridgeUrls) {
        throw "Connect page QR payload does not include bridgeUrls."
    }
    $connectQrHasExternalUrl = $connectPage.Content -match 'https://codex-mobile-smoke.example'
    if (-not $connectQrHasExternalUrl) {
        throw "Connect page QR payload does not prefer configured external bridge URL."
    }

    $pair = Invoke-RestMethod -Method Post -Uri "$baseUri/pairing/start" -TimeoutSec 5
    $pairingBody = @{ code = $pair.code }
    if ($pair.PSObject.Properties.Name -contains "challengeId") {
        $pairingBody.challengeId = $pair.challengeId
    }
    elseif ($pair.PSObject.Properties.Name -contains "id") {
        $pairingBody.challengeId = $pair.id
    }

    $token = Invoke-RestMethod `
        -Method Post `
        -Uri "$baseUri/pairing/complete" `
        -ContentType "application/json" `
        -Body ($pairingBody | ConvertTo-Json -Compress) `
        -TimeoutSec 5

    $headers = @{ Authorization = "Bearer $($token.accessToken)" }
    $unauthorizedTokenInventory = $false
    try {
        Invoke-WebRequest -Uri "$baseUri/pairing/tokens" -TimeoutSec 5 | Out-Null
    }
    catch {
        $statusCode = $_.Exception.Response.StatusCode.value__
        $unauthorizedTokenInventory = $statusCode -eq 401
    }
    if (-not $unauthorizedTokenInventory) {
        throw "Pairing token inventory was reachable without bearer auth."
    }

    $tokenInventory = Invoke-RestMethod -Uri "$baseUri/pairing/tokens" -Headers $headers -TimeoutSec 5
    $tokenInventoryJson = $tokenInventory | ConvertTo-Json -Depth 8 -Compress
    $tokenInventoryHidesRawToken = $tokenInventoryJson -notmatch [regex]::Escape($token.accessToken)
    if (-not $tokenInventoryHidesRawToken) {
        throw "Pairing token inventory exposed the raw access token."
    }

    $threads = Invoke-RestMethod -Uri "$baseUri/codex/threads" -Headers $headers -TimeoutSec 20
    $firstThreadId = $threads.json.data[0].id
    $threadDetail = Invoke-RestMethod -Uri "$baseUri/codex/threads/$firstThreadId" -Headers $headers -TimeoutSec 20
    $projects = Invoke-RestMethod -Uri "$baseUri/projects" -Headers $headers -TimeoutSec 5
    $network = Invoke-RestMethod -Uri "$baseUri/network/interfaces" -Headers $headers -TimeoutSec 5
    $networkEndpointCount = ($network.endpoints | Measure-Object).Count
    $networkNonLoopbackCount = ($network.endpoints | Where-Object { $_.scope -ne "loopback" } | Measure-Object).Count
    if ($networkEndpointCount -lt 1) {
        throw "Bridge did not report any network endpoints."
    }

    Invoke-RestMethod `
        -Method Post `
        -Uri "$baseUri/goal" `
        -Headers $headers `
        -ContentType "application/json" `
        -Body (@{ objective = "packaged runtime smoke"; status = "active"; source = "smoke" } | ConvertTo-Json -Compress) `
        -TimeoutSec 5 | Out-Null

    $sync = Invoke-RestMethod -Uri "$baseUri/sync/state" -Headers $headers -TimeoutSec 5

    $kbProject = $projects | Where-Object { $_.name -eq "AgentScope Java Harness Knowledge Base" } | Select-Object -First 1
    $markdownRead = $false
    $markdownLength = 0
    if ($kbProject) {
        $markdown = Invoke-RestMethod `
            -Uri "$baseUri/files/read?projectId=$($kbProject.id)&path=00-%E6%80%BB%E7%9B%AE%E5%BD%95.md" `
            -Headers $headers `
            -TimeoutSec 5
        $markdownRead = $markdown.language -eq "markdown" -and $markdown.content.Length -gt 0
        $markdownLength = $markdown.content.Length
    }

    [pscustomobject]@{
        Health = $health.status
        ThreadCount = ($threads.json.data | Measure-Object).Count
        ThreadSource = $threads.json.source
        FirstThread = $threads.json.data[0].name
        FirstThreadItems = ($threadDetail.json.thread.turns[0].items | Measure-Object).Count
        ProjectCount = ($projects | Measure-Object).Count
        HasRepoProject = [bool]($projects | Where-Object { $_.rootPath -eq $repo })
        HasKbProject = [bool]$kbProject
        MarkdownRead = $markdownRead
        MarkdownLength = $markdownLength
        ConnectQrHasBridgeUrls = $connectQrHasBridgeUrls
        ConnectQrHasExternalUrl = $connectQrHasExternalUrl
        NetworkEndpointCount = $networkEndpointCount
        NetworkNonLoopbackCount = $networkNonLoopbackCount
        TokenInventoryRequiresAuth = $unauthorizedTokenInventory
        TokenInventoryHidesRawToken = $tokenInventoryHidesRawToken
        TokenInventoryCount = ($tokenInventory.tokens | Measure-Object).Count
        GoalSynced = $sync.goal.objective -eq "packaged runtime smoke"
    } | ConvertTo-Json -Compress
}
finally {
    if ($process -and -not $process.HasExited) {
        Stop-Process -Id $process.Id -Force
    }

    Start-Sleep -Milliseconds 300
    if (Test-Path -LiteralPath $errLog) {
        $stderr = Get-Content -LiteralPath $errLog -Encoding UTF8 -Raw
        if (-not [string]::IsNullOrWhiteSpace($stderr)) {
            Write-Error $stderr
        }
    }
}
