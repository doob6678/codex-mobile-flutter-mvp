param(
    [int]$Port = 51905,
    [string]$KnowledgeBasePath = ""
)

$ErrorActionPreference = "Stop"

$repo = (Get-Location).Path
$bridge = Join-Path $repo "dist\bridge-framework-dependent"
$outLog = Join-Path $repo "tmp-bridge-smoke.out.log"
$errLog = Join-Path $repo "tmp-bridge-smoke.err.log"

Remove-Item -LiteralPath $outLog -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $errLog -ErrorAction SilentlyContinue

if (-not (Test-Path -LiteralPath (Join-Path $bridge "CodexMobile.Bridge.dll"))) {
    throw "Packaged bridge DLL not found under $bridge"
}

$env:ASPNETCORE_URLS = "http://127.0.0.1:$Port"
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

$process = Start-Process `
    -FilePath "dotnet" `
    -ArgumentList ".\CodexMobile.Bridge.dll" `
    -WorkingDirectory $bridge `
    -PassThru `
    -WindowStyle Hidden `
    -RedirectStandardOutput $outLog `
    -RedirectStandardError $errLog

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

    $pair = Invoke-RestMethod -Method Post -Uri "$baseUri/pairing/start" -TimeoutSec 5
    $token = Invoke-RestMethod `
        -Method Post `
        -Uri "$baseUri/pairing/complete" `
        -ContentType "application/json" `
        -Body (@{ code = $pair.code } | ConvertTo-Json -Compress) `
        -TimeoutSec 5

    $headers = @{ Authorization = "Bearer $($token.accessToken)" }
    $threads = Invoke-RestMethod -Uri "$baseUri/codex/threads" -Headers $headers -TimeoutSec 20
    $firstThreadId = $threads.json.data[0].id
    $threadDetail = Invoke-RestMethod -Uri "$baseUri/codex/threads/$firstThreadId" -Headers $headers -TimeoutSec 20
    $projects = Invoke-RestMethod -Uri "$baseUri/projects" -Headers $headers -TimeoutSec 5
    $network = Invoke-RestMethod -Uri "$baseUri/network/interfaces" -Headers $headers -TimeoutSec 5

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
        NetworkInterfaceCount = ($network.interfaces | Measure-Object).Count
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
