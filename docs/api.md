# Bridge API

The Windows Bridge is the authority for mobile-visible projects, files, conversations, approvals, commands, audit logs, and Codex app-server compatibility metadata. The Flutter app talks to these endpoints only; the Bridge may internally call `codex app-server`.

## Base URL

MVP local-network form:

```text
http://<windows-host>:5010
```

During emulator testing, Android may reach the Windows host through `10.0.2.2` or `adb reverse`, depending on the setup.

## Authentication

All endpoints except `GET /health`, `POST /pairing/start`, and `POST /pairing/complete` require a Bridge-issued bearer token:

```http
Authorization: Bearer <access-token>
```

The token represents the paired device, not an OpenAI account. OpenAI and Codex credentials stay on Windows.

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/health` | Bridge liveness and optional app-server status summary. |
| `GET` | `/protocol/summary` | Local CLI version, generated protocol asset version, supported Bridge mappings, and unavailable features. |
| `GET` | `/codex/status` | Check whether the local `codex app-server` adapter is reachable without exposing secrets. |
| `GET` | `/codex/config` | Read safe Codex config summary through `config/read`. |
| `GET` | `/codex/account` | Read account/login state through `account/read`; never returns raw auth files. |
| `GET` | `/codex/threads` | List Codex threads through `thread/list`. |
| `GET` | `/codex/threads/{id}` | Read a thread through `thread/read`. |
| `POST` | `/codex/threads` | Start a Codex thread through `thread/start`. |
| `POST` | `/codex/turns` | Start or continue work through `turn/start`. |
| `POST` | `/codex/raw` | Restricted JSON-RPC bridge for allowlisted app-server methods only. |
| `POST` | `/pairing/start` | Create a short-lived pairing challenge and QR payload. |
| `POST` | `/pairing/complete` | Exchange a challenge response for mobile access and refresh tokens. |
| `GET` | `/network/interfaces` | Report loopback, private LAN, and mesh/VPN bridge URLs while hiding public hosts by default. |
| `GET` | `/sync/state` | Return the current `/goal`, tracked Codex tasks, tracked turn jobs, and sync events. |
| `GET` | `/sync/stream` | Push live sync snapshots through server-sent events. |
| `GET` | `/goal` | Read the current `/goal` objective. |
| `POST` | `/goal` | Set or replace the current `/goal` objective from mobile. |
| `GET` | `/tasks` | Read task progress and completion records. |
| `POST` | `/tasks` | Create a mobile-visible Codex task record. |
| `POST` | `/tasks/{id}/progress` | Update task status, progress percent, and summary. |
| `GET` | `/projects` | List authorized project roots. |
| `POST` | `/projects` | Add an authorized project root after local confirmation. |
| `GET` | `/files/list` | List one directory under an authorized root. |
| `GET` | `/files/read` | Read a UTF-8 text file preview under an authorized root, including `language=markdown` for `.md` files. |
| `GET` | `/files/hash` | Return a content hash for concurrency checks before patching. |
| `POST` | `/files/patch` | Apply an approved patch when the base hash still matches. |
| `GET` | `/conversations` | List mobile-visible Codex threads/conversations. |
| `POST` | `/conversations` | Start a new conversation bound to a project and cwd. |
| `GET` | `/conversations/{id}` | Read a conversation snapshot. |
| `POST` | `/conversations/{id}/messages` | Send user input or steer an active turn. |
| `GET` | `/approvals` | List pending command, file-change, permission, or tool-input approvals. |
| `POST` | `/approvals/{id}/resolve` | Approve, deny, or provide requested user input. |
| `GET` | `/audit` | Query redacted audit events. |
| `POST` | `/commands/preview` | Validate a command against policy and show risk/cwd/args. |
| `POST` | `/commands/run` | Execute an approved allowlisted command and stream output events. |

## Event Hub

SignalR hub:

```text
/hubs/events
```

Mobile event names:

- `message.created`
- `message.delta`
- `approval.requested`
- `approval.resolved`
- `patch.proposed`
- `patch.applied`
- `command.started`
- `command.output_delta`
- `command.finished`
- `file.changed`
- `task.status_changed`
- `goal.updated`
- `task.updated`

These events are derived from generated app-server notifications such as `thread/started`, `turn/started`, `item/agentMessage/delta`, `command/exec/outputDelta`, `item/fileChange/patchUpdated`, `fs/changed`, and `serverRequest/resolved`.

## Real-Time Sync

`/sync/state` includes a structured `jobs` array for mobile-started Codex turns. Each job has `id`, `threadId`, optional `conversationId`, `status` (`pending`, `running`, `completed`, `failed`), prompt preview, timestamps, last message, and optional error. `turn/start` returning from app-server only means the prompt was accepted/dispatched; a job becomes `completed` only after Bridge receives the app-server `turn/completed` notification for the same thread. This lets the phone leave and reopen a conversation page while Bridge continues tracking the real Windows Codex turn.

`/sync/stream` sends the current snapshot immediately, then sends a new snapshot whenever the Bridge receives a goal, task, turn job, or sync-event update. This gives the Flutter app bidirectional sync without exposing Codex credentials: mobile can set `/goal` and task intent through protected REST calls, while Windows/Codex-side work reports progress back through the same Bridge state and event stream.

Temporary network test hosts can be injected with `CODEX_MOBILE_BRIDGE_HOSTS=127.0.0.1,192.168.55.44,100.72.10.9`; public hosts remain hidden unless `CODEX_MOBILE_ALLOW_PUBLIC_BRIDGE=1` is explicitly set.

## Codex App-Server Adapter

The `/codex/*` endpoints are a safety wrapper around generated app-server methods. The Bridge owns the allowlist and rejects write-oriented filesystem methods such as `fs/writeFile` unless a future implementation routes them through diff approval.

Current allowlisted families:

- Config/account read: `config/read`, `account/read`, `account/rateLimits/read`.
- Thread/turn: `thread/list`, `thread/read`, `thread/start`, `thread/resume`, `thread/turns/list`, `thread/turns/items/list`, `turn/start`, `turn/steer`, `turn/interrupt`.
- Read-only filesystem: `fs/readDirectory`, `fs/readFile`, `fs/getMetadata`.
- Approval plumbing: `item/commandExecution/requestApproval`, `item/fileChange/requestApproval`, `item/permissions/requestApproval`, `serverRequest/resolved`.
- Tool/user-input and legacy approvals: `item/tool/requestUserInput`, `applyPatchApproval`, `execCommandApproval`.
- Discovery: `model/list`, `collaborationMode/list`.

Relevant event names tracked from generated assets include `thread/started`, `thread/status/changed`, `turn/started`, `turn/completed`, `turn/diff/updated`, `turn/plan/updated`, `fs/changed`, and `serverRequest/resolved`.

Adapter failures are redacted before mobile responses, including OpenAI-style secret tokens and `OPENAI_API_KEY=...` assignments.

## Request Notes

Default read roots can be pre-authorized at Bridge startup:

```powershell
$env:CODEX_MOBILE_DEFAULT_PROJECTS='AgentScope Java Harness 知识库=C:\path\to\AgentScope-Java-Harness-知识库'
```

Use semicolons to provide multiple roots. Paths are still canonicalized and must exist before they are exposed to paired devices.

`GET /files/list` accepts:

- `projectId`: authorized project id.
- `path`: absolute or project-relative path.
- `cursor`: optional pagination cursor.

`GET /files/read` accepts:

- `projectId`
- `path`
- `maxBytes`: server-enforced upper bound for preview.

`POST /files/patch` requires:

- `projectId`
- `path`
- `baseHash`
- `patch`
- `approvalId`

`POST /commands/run` requires:

- `cwd`
- `command`

Command execution is intentionally narrow: Bridge matches the entire command against fixed executable + argument templates, executes without a shell, and requires `cwd` to be inside an authorized project root. `git status` is the only directly executable read-only template today. Test/build/verification templates such as `dotnet test`, `flutter test`, `flutter analyze`, and `powershell -ExecutionPolicy Bypass -File scripts\verify.ps1` can be previewed but are rejected by `/commands/run` until a verified approval id is implemented.

Security policy rejections return JSON with `403`; invalid ids, missing paths, stale hashes, and malformed requests return handled JSON errors instead of unhandled server failures.

## Limitations

- Flutter does not directly read Windows drives.
- Flutter does not receive OpenAI API keys, Codex auth files, or raw secret environment variables.
- The MVP does not promise that the official Windows Codex App UI will immediately display all third-party Flutter actions. The generated protocol exposes thread/turn operations such as `thread/read`, `thread/resume`, `thread/loaded/list`, `thread/inject_items`, and `turn/start`, but no stable request for forcing an already-open Windows desktop Codex window to reload its visible conversation.
- Direct public exposure of the Bridge is out of scope; use LAN or VPN/mesh networking first.
