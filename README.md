# Codex Mobile Flutter MVP

This repository implements the MVP path from `codex-mobile-flutter-research.md`: a Flutter mobile console talks to a Windows Bridge, while Windows keeps authority over files, commands, Codex app-server protocol adaptation, and secrets.

## What Is Included

- `bridge/CodexMobile.Bridge`: .NET 8 ASP.NET Core Minimal API Bridge.
- `mobile_app`: Flutter Material 3 client with pairing, dashboard, projects, files, conversations, approvals, and settings screens.
- `generated/`: local `codex app-server` TypeScript and JSON Schema protocol snapshots.
- `docs/`: API, security, protocol asset, testing, and Superpowers plan documents.
- `scripts/verify.ps1`: end-to-end local verification script.

## Bridge

Run the Bridge locally:

```powershell
$env:DOTNET_CLI_HOME=(Join-Path (Get-Location) '.dotnet_home')
$env:NUGET_PACKAGES=(Join-Path (Get-Location) '.nuget_packages')
$env:ASPNETCORE_URLS='http://127.0.0.1:5010'
dotnet run --no-restore --no-launch-profile --project bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj
```

Smoke checks:

```powershell
Invoke-RestMethod -Uri http://127.0.0.1:5010/health
Invoke-RestMethod -Uri http://127.0.0.1:5010/protocol/summary
```

## Flutter

Run the mobile client:

```powershell
cd mobile_app
flutter run --dart-define=BRIDGE_URL=http://127.0.0.1:5010
```

For Android emulator networking, use `http://10.0.2.2:5010` or `adb reverse` depending on device setup.

## Verification

Run:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1
```

This checks docs and generated Codex protocol assets, runs Bridge service tests, starts the Bridge for HTTP smoke checks, then runs `flutter analyze` and `flutter test`.

## Security Boundary

The Flutter app is a remote UI only. OpenAI keys, Codex auth/config, project filesystem access, command execution, patch application, and audit logs remain on Windows behind the Bridge. The MVP targets LAN/VPN/mesh access, not direct public exposure.
