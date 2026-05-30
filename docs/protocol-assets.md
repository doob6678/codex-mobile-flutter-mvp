# Codex App-Server Protocol Assets

This repository snapshots Codex app-server protocol assets so the Windows Bridge can adapt to a known local protocol surface without exposing raw Codex credentials or making the Flutter client depend on every generated type.

## Local Generator

Discovered local CLI:

```powershell
codex --version
# codex-cli 0.131.0-alpha.9
```

The checked-in assets were generated from the local `codex app-server` generator. Regenerate them from the repository root with:

```powershell
New-Item -ItemType Directory -Force -Path generated\codex-app-server-ts,generated\codex-app-server-schema | Out-Null
codex app-server generate-ts --experimental --out generated\codex-app-server-ts
codex app-server generate-json-schema --experimental --out generated\codex-app-server-schema
```

Expected anchor files:

- `generated/codex-app-server-ts/ClientRequest.ts`
- `generated/codex-app-server-ts/ServerRequest.ts`
- `generated/codex-app-server-ts/ServerNotification.ts`
- `generated/codex-app-server-ts/v2/ThreadStartParams.ts`
- `generated/codex-app-server-schema/codex_app_server_protocol.v2.schemas.json`
- `generated/codex-app-server-schema/v2/ThreadStartParams.json`

## Protocol Shape

The generated TypeScript assets model JSON-RPC style messages:

- `ClientRequest.ts`: Flutter/Bridge-facing requests forwarded or adapted to app-server methods.
- `ServerRequest.ts`: app-server approval and tool-input requests that require a client response.
- `ServerNotification.ts`: streamed state updates for threads, turns, command output, file changes, account changes, warnings, and errors.
- `ClientNotification.ts`: client lifecycle notifications such as `initialized`.

Key generated request families used by the MVP mapping:

| Capability | Representative app-server methods |
|---|---|
| Initialization | `initialize`, `initialized` |
| Config and account | `config/read`, `config/value/write`, `config/batchWrite`, `account/read`, `account/login/start`, `account/logout`, `account/rateLimits/read` |
| Thread list and lifecycle | `thread/list`, `thread/read`, `thread/start`, `thread/resume`, `thread/archive`, `thread/unarchive`, `thread/metadata/update` |
| Turn execution | `turn/start`, `turn/steer`, `turn/interrupt`, `turn/completed`, `turn/diff/updated`, `turn/plan/updated` |
| Filesystem | `fs/readDirectory`, `fs/readFile`, `fs/getMetadata`, `fs/watch`, `fs/unwatch`, `fs/writeFile`, `fs/remove`, `fs/copy` |
| Approvals | `item/commandExecution/requestApproval`, `item/fileChange/requestApproval`, `item/permissions/requestApproval`, `applyPatchApproval`, `execCommandApproval` |
| Commands and processes | `command/exec`, `command/exec/write`, `command/exec/terminate`, `command/exec/resize`, `process/spawn`, `process/writeStdin`, `process/kill` |
| Events | `thread/started`, `thread/status/changed`, `item/started`, `item/completed`, `item/agentMessage/delta`, `command/exec/outputDelta`, `fs/changed`, `serverRequest/resolved` |

Server-initiated request methods in `ServerRequest.ts` include `item/commandExecution/requestApproval`, `item/fileChange/requestApproval`, `item/permissions/requestApproval`, `item/tool/requestUserInput`, `mcpServer/elicitation/request`, `item/tool/call`, `account/chatgptAuthTokens/refresh`, `attestation/generate`, plus legacy `applyPatchApproval` and `execCommandApproval`.

## Bridge Mapping

The Bridge should expose a stable mobile API and keep app-server compatibility behind `/protocol/summary`. The Flutter app should not connect to a raw app-server socket.

| Bridge endpoint | Codex concept | Generated asset anchors |
|---|---|---|
| `GET /protocol/summary` | Protocol version, local CLI version, supported method families | `ClientRequest.ts`, `ServerRequest.ts`, `ServerNotification.ts` |
| `GET /health` | Bridge liveness, app-server connection health | Bridge-owned |
| `POST /pairing/start`, `POST /pairing/complete` | Device pairing before any app-server access | Bridge-owned |
| `GET /projects`, `POST /projects` | Authorized project roots and mobile-visible workspace scope | Bridge-owned plus `ThreadStartParams.cwd` |
| `GET /files/list` | Directory browsing | `FsReadDirectoryParams`, `FsReadDirectoryResponse` |
| `GET /files/read` | Text file preview | `FsReadFileParams`, `FsReadFileResponse` |
| `GET /files/hash` | Concurrent write guard | Bridge-owned |
| `POST /files/patch` | Patch proposal/application after approval | `FileChangeRequestApprovalParams`, `ApplyPatchApprovalParams` |
| `GET /conversations` | Thread list | `ThreadListParams`, `ThreadListResponse` |
| `POST /conversations` | Thread start | `ThreadStartParams`, `ThreadStartResponse` |
| `GET /conversations/{id}` | Thread snapshot | `ThreadReadParams`, `ThreadReadResponse` |
| `POST /conversations/{id}/messages` | Turn start/steer | `TurnStartParams`, `TurnSteerParams` |
| `GET /approvals` | Pending approval cards | `ServerRequest.ts` approval variants |
| `POST /approvals/{id}/resolve` | Approval response | `ServerRequestResolvedNotification` |
| `GET /audit` | Bridge audit log | Bridge-owned |
| `POST /commands/preview`, `POST /commands/run` | Command allowlist preview and execution | `CommandExecParams`, `CommandExecResponse` |
| `GET /hubs/events` or `/hubs/events` SignalR | Mobile event stream | `ServerNotification.ts` mapped to mobile events |

## Compatibility Rules

- Treat generated assets as read-only snapshots. Do not edit files under `generated/` by hand.
- Keep Flutter models based on Bridge DTOs, not raw app-server generated TypeScript.
- The Bridge owns version adaptation when Codex app-server adds, removes, or renames methods.
- Do not expose `.codex/auth.json`, raw environment variables, or OpenAI API keys through protocol summary responses.
- Official Codex App UI synchronization is not a stable MVP dependency. The reliable contract is Flutter to Bridge to app-server state, not guaranteed live refresh inside the desktop Codex App window.
