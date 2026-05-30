# Codex Mobile Flutter MVP

This repository implements the MVP path from `codex-mobile-flutter-research.md`: a Flutter mobile console talks to a Windows Bridge, while Windows keeps authority over files, commands, Codex app-server protocol adaptation, and secrets.

## What Is Included

- `bridge/CodexMobile.Bridge`: .NET 8 ASP.NET Core Minimal API Bridge.
- `mobile_app`: Flutter Material 3 client with pairing, dashboard, projects, files, conversations, approvals, live goals/tasks, and settings screens.
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
Invoke-RestMethod -Uri http://127.0.0.1:5010/codex/status
```

Pairing is required before mobile-visible project, network, goal, task, and Codex endpoints can be used. After pairing, the mobile app can set `/goal`, read task progress, and receive live state snapshots from `/sync/stream`.

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

The smoke flow also exercises real protected HTTP behavior: pairing token exchange, private/mesh network URL reporting, `/goal` update, task creation/completion, `/sync/state`, and the first event from the live `/sync/stream`.

## Packaging

For a simple two-part release, build the Windows Bridge and mobile app:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\package.ps1
```

The script publishes a Windows Bridge server and builds the Flutter client for available local targets. Android still requires a normal Flutter/Android toolchain on the build machine, but end users only need the produced app and the Windows Bridge folder.

## Security Boundary

The Flutter app is a remote UI only. OpenAI keys, Codex auth/config, project filesystem access, command execution, patch application, and audit logs remain on Windows behind the Bridge. The MVP targets LAN/VPN/mesh access, not direct public exposure.
