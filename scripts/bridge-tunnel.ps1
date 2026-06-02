function Get-BridgeFirstPort {
    param([string]$BindUrls)

    foreach ($url in ($BindUrls -split ';')) {
        $trimmed = $url.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) {
            continue
        }

        if ($trimmed -match ':(\d+)(/)?$') {
            return [int]$Matches[1]
        }

        if ($trimmed.StartsWith('https://', [System.StringComparison]::OrdinalIgnoreCase)) {
            return 443
        }

        return 80
    }

    return 5010
}

function Get-CloudflaredPath {
    param([string]$Root)

    if (-not [string]::IsNullOrWhiteSpace($env:CLOUDFLARED_PATH) -and (Test-Path -LiteralPath $env:CLOUDFLARED_PATH)) {
        $resolved = (Resolve-Path -LiteralPath $env:CLOUDFLARED_PATH).Path
        if (Test-CloudflaredExecutable -Path $resolved) {
            return $resolved
        }
    }

    $local = Join-Path $Root 'tools\cloudflared.exe'
    if (Test-Path -LiteralPath $local) {
        $resolved = (Resolve-Path -LiteralPath $local).Path
        if (Test-CloudflaredExecutable -Path $resolved) {
            return $resolved
        }

        Write-Host "Existing cloudflared is invalid and will be replaced: $resolved"
        Remove-Item -LiteralPath $resolved -Force -ErrorAction SilentlyContinue
    }

    $command = Get-Command 'cloudflared.exe' -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        if (Test-CloudflaredExecutable -Path $command.Source) {
            return $command.Source
        }
    }

    $command = Get-Command 'cloudflared' -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        if (Test-CloudflaredExecutable -Path $command.Source) {
            return $command.Source
        }
    }

    return $null
}

function Test-CloudflaredExecutable {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $item = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($null -eq $item -or $item.Length -lt 20MB) {
        return $false
    }

    try {
        $output = & $Path --version 2>&1
        if ($LASTEXITCODE -eq 0 -and ($output -join "`n") -match 'cloudflared') {
            return $true
        }
    }
    catch {
        return $false
    }

    return $false
}

function Install-Cloudflared {
    param([string]$Root)

    $tools = Join-Path $Root 'tools'
    New-Item -ItemType Directory -Force -Path $tools | Out-Null
    $target = Join-Path $tools 'cloudflared.exe'
    if (Test-Path -LiteralPath $target) {
        if (Test-CloudflaredExecutable -Path $target) {
            return $target
        }

        Write-Host "Removing invalid cloudflared file: $target"
        Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    }

    $downloadUrl = 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe'
    Write-Host "cloudflared not found. Downloading tunnel helper to $target"
    Write-Host "Download URL: $downloadUrl"
    Write-Host "Download target: $target"
    Save-FileWithProgress -Url $downloadUrl -Destination $target -TimeoutSeconds 300
    if (-not (Test-CloudflaredExecutable -Path $target)) {
        Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
        throw "Downloaded cloudflared could not be executed on this Windows machine."
    }

    return $target
}

function Save-FileWithProgress {
    param(
        [string]$Url,
        [string]$Destination,
        [int]$TimeoutSeconds = 300
    )

    Add-Type -AssemblyName System.Net.Http
    $handler = [System.Net.Http.HttpClientHandler]::new()
    $client = [System.Net.Http.HttpClient]::new($handler)
    $client.Timeout = [TimeSpan]::FromSeconds($TimeoutSeconds)
    $temp = "$Destination.download"
    Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    try {
        $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Url)
        $response = $client.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $response.EnsureSuccessStatusCode() | Out-Null
        $total = $response.Content.Headers.ContentLength
        $stream = $response.Content.ReadAsStreamAsync().GetAwaiter().GetResult()
        $file = [System.IO.File]::Open($temp, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
        try {
            $buffer = New-Object byte[] (1024 * 1024)
            [long]$readTotal = 0
            $lastPrint = Get-Date
            while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
                $file.Write($buffer, 0, $read)
                $readTotal += $read
                $now = Get-Date
                if (($now - $lastPrint).TotalSeconds -ge 1) {
                    if ($total.HasValue -and $total.Value -gt 0) {
                        $percent = [math]::Round(($readTotal * 100.0) / $total.Value, 1)
                        Write-Host "cloudflared download: $percent% ($([math]::Round($readTotal / 1MB, 1)) MB / $([math]::Round($total.Value / 1MB, 1)) MB)"
                    }
                    else {
                        Write-Host "cloudflared download: $([math]::Round($readTotal / 1MB, 1)) MB"
                    }
                    $lastPrint = $now
                }
            }
        }
        finally {
            $file.Dispose()
            $stream.Dispose()
        }

        Move-Item -LiteralPath $temp -Destination $Destination -Force
        $size = (Get-Item -LiteralPath $Destination).Length
        Write-Host "cloudflared download complete: $Destination ($([math]::Round($size / 1MB, 1)) MB)"
    }
    finally {
        $client.Dispose()
        if (Test-Path -LiteralPath $temp) {
            Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
        }
    }
}

function Read-CloudflaredTunnelUrl {
    param([string[]]$LogPaths)

    foreach ($path in $LogPaths) {
        if (-not (Test-Path -LiteralPath $path)) {
            continue
        }

        $text = Get-Content -LiteralPath $path -Encoding UTF8 -Raw -ErrorAction SilentlyContinue
        if ($text -match 'https://[a-zA-Z0-9.-]+\.trycloudflare\.com') {
            return $Matches[0]
        }
    }

    return $null
}

function Start-BridgeExternalTunnel {
    param(
        [string]$Root,
        [int]$Port,
        [string]$ExternalUrlsFile
    )

    if ($env:CODEX_MOBILE_DISABLE_TUNNEL -in @('1', 'true', 'yes')) {
        Write-Host "External tunnel disabled by CODEX_MOBILE_DISABLE_TUNNEL."
        return $null
    }

    $cloudflared = Get-CloudflaredPath -Root $Root
    if ([string]::IsNullOrWhiteSpace($cloudflared)) {
        try {
            $cloudflared = Install-Cloudflared -Root $Root
        }
        catch {
            Write-Host "Could not install cloudflared automatically: $($_.Exception.Message)"
            Write-Host "Continuing with LAN/VPN URLs only. Put cloudflared.exe in '$Root\tools' and restart for cross-network mobile data."
            return $null
        }
    }

    Remove-Item -LiteralPath $ExternalUrlsFile -ErrorAction SilentlyContinue
    $logDir = Join-Path $Root 'logs'
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    $stdout = Join-Path $logDir 'cloudflared.out.log'
    $stderr = Join-Path $logDir 'cloudflared.err.log'
    Remove-Item -LiteralPath $stdout -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stderr -ErrorAction SilentlyContinue

    $target = "http://127.0.0.1:$Port"
    Write-Host "Starting external HTTPS tunnel for $target"
    $process = Start-Process `
        -FilePath $cloudflared `
        -ArgumentList @('tunnel', '--url', $target, '--no-autoupdate') `
        -WorkingDirectory $Root `
        -WindowStyle Hidden `
        -RedirectStandardOutput $stdout `
        -RedirectStandardError $stderr `
        -PassThru

    $deadline = (Get-Date).AddSeconds(60)
    $tunnelUrl = $null
    do {
        Start-Sleep -Milliseconds 500
        $tunnelUrl = Read-CloudflaredTunnelUrl -LogPaths @($stdout, $stderr)
    } while ([string]::IsNullOrWhiteSpace($tunnelUrl) -and (Get-Date) -lt $deadline -and -not $process.HasExited)

    if ([string]::IsNullOrWhiteSpace($tunnelUrl)) {
        Write-Host "cloudflared started but no public URL was detected yet. Logs:"
        Write-Host "  $stdout"
        Write-Host "  $stderr"
        return $process
    }

    Set-Content -LiteralPath $ExternalUrlsFile -Encoding UTF8 -Value $tunnelUrl
    $env:CODEX_MOBILE_EXTERNAL_BRIDGE_URLS = $tunnelUrl
    Write-Host "External mobile URL: $tunnelUrl"
    Write-Host "Use this base URL on Android when the phone is outside the LAN."
    Write-Host "Open the Windows-local /connect page printed by start-bridge.ps1; its QR payload will prefer this HTTPS tunnel URL."
    return $process
}

function Stop-BridgeExternalTunnel {
    param($Process)

    if ($null -eq $Process) {
        return
    }

    try {
        if (-not $Process.HasExited) {
            Stop-Process -Id $Process.Id -Force
        }
    }
    catch {
        Write-Verbose "Could not stop tunnel process: $($_.Exception.Message)"
    }
}
