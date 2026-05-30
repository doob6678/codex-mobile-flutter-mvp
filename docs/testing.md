# Testing And Verification

Use the repository verification script for a single local check:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1
```

The script is intentionally conditional. It always checks documentation and generated protocol assets, then runs backend or Flutter checks only when those directories exist.

## Protocol Asset Checks

`scripts/verify.ps1` verifies:

- Required docs exist: `docs/protocol-assets.md`, `docs/api.md`, `docs/security.md`, `docs/testing.md`.
- Required generated files exist:
  - `generated/codex-app-server-ts/ClientRequest.ts`
  - `generated/codex-app-server-ts/ServerRequest.ts`
  - `generated/codex-app-server-ts/ServerNotification.ts`
  - `generated/codex-app-server-ts/v2/ThreadStartParams.ts`
  - `generated/codex-app-server-schema/codex_app_server_protocol.v2.schemas.json`
- The v2 JSON schema parses as JSON.
- Key JSON-RPC methods are present: `thread/start`, `thread/list`, `thread/read`, `turn/start`, `fs/readFile`, `fs/readDirectory`, `config/read`, `account/read`, `item/commandExecution/requestApproval`, and `item/fileChange/requestApproval`.

## Backend Checks

When `bridge/` exists, the script runs the most specific available backend test command:

```powershell
dotnet run --no-restore --project bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj
```

It also starts the Bridge with `--no-launch-profile` and checks:

```powershell
GET /health
GET /protocol/summary
GET /codex/status
GET /network/interfaces
POST /goal
POST /tasks
POST /tasks/{id}/progress
GET /sync/state
GET /sync/stream
GET /projects
GET /files/read
```

Expected backend coverage:

- Path canonicalization.
- Project whitelist enforcement.
- UTF-8 text file reading.
- Patch hash mismatch rejection.
- Command allowlist rejection.
- Pairing token expiry.
- Audit log redaction.
- HTTP health and protocol summary smoke behavior.
- Codex app-server adapter status response shape and redaction path.
- Private LAN and mesh/VPN bridge URL reporting.
- Default suppression of public bridge hosts.
- Protected `/goal` and task progress updates.
- First live sync snapshot from the server-sent event stream.
- Optional default Markdown knowledge-base project loading through `CODEX_MOBILE_DEFAULT_PROJECTS`.
- Remote reading of `00-总目录.md` with `language=markdown` when the AgentScope Java Harness knowledge base exists locally.
- Default Bridge hosting behavior binds to `http://0.0.0.0:5010` so a phone can connect through the Windows LAN or mesh/VPN address.

## Flutter Checks

When `mobile_app/` exists, the script runs:

```powershell
Push-Location mobile_app
flutter analyze
flutter test
Pop-Location
```

Expected Flutter coverage:

- API URL construction.
- JSON parsing.
- Pairing and settings state.
- Project and file list rendering.
- Conversation and approval surfaces.
- Release-build safety text for debug bridge behavior.
- Goal/task progress surface and live-sync copy.
- Network URL and public-host warning rendering.
- Markdown preview rendering for mobile reading.

## Manual Smoke Checks

After backend and mobile client exist:

1. Start the Bridge locally.
2. Open `GET /health`.
3. Start pairing and connect the Flutter app.
4. Configure `CODEX_MOBILE_DEFAULT_PROJECTS='AgentScope Java Harness 知识库=<knowledge-root>'` or add a small test project to the whitelist.
5. Browse a directory and read a UTF-8 Markdown file.
6. Start a conversation bound to that project.
7. Set a `/goal` from the mobile Goals tab.
8. Create or receive a task progress record and confirm it updates live.
9. Trigger a command preview and confirm the approval card shows command, cwd, args, risk, and expiry.
10. Apply a small patch only after checking the base hash.
11. Confirm `GET /audit` shows redacted entries.

## Network Smoke Details

`scripts/verify.ps1` sets `CODEX_MOBILE_BRIDGE_HOSTS` to a temporary mix of loopback, private LAN, mesh/VPN, and public IP examples. The smoke test asserts that private and mesh URLs appear and the public host is hidden. It then pairs, writes `/goal`, completes a task through HTTP, and reads the first snapshot from `/sync/stream`.

For a phone-accessible local run, use:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-bridge.ps1
```

The script binds the Bridge to all interfaces on port `5010` and auto-loads the AgentScope Java Harness Markdown knowledge base when it is found under the desktop.

## Regenerating Protocol Assets

When Codex CLI changes, regenerate assets from the repository root:

```powershell
New-Item -ItemType Directory -Force -Path generated\codex-app-server-ts,generated\codex-app-server-schema | Out-Null
codex app-server generate-ts --experimental --out generated\codex-app-server-ts
codex app-server generate-json-schema --experimental --out generated\codex-app-server-schema
```

Then rerun:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1
```
