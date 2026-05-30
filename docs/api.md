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
| `POST` | `/pairing/start` | Create a short-lived pairing challenge and QR payload. |
| `POST` | `/pairing/complete` | Exchange a challenge response for mobile access and refresh tokens. |
| `GET` | `/projects` | List authorized project roots. |
| `POST` | `/projects` | Add an authorized project root after local confirmation. |
| `GET` | `/files/list` | List one directory under an authorized root. |
| `GET` | `/files/read` | Read a UTF-8 text file preview under an authorized root. |
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

These events are derived from generated app-server notifications such as `thread/started`, `turn/started`, `item/agentMessage/delta`, `command/exec/outputDelta`, `item/fileChange/patchUpdated`, `fs/changed`, and `serverRequest/resolved`.

## Request Notes

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

- `projectId`
- `cwd`
- `command`
- `args`
- `approvalId` when policy requires approval.

## Limitations

- Flutter does not directly read Windows drives.
- Flutter does not receive OpenAI API keys, Codex auth files, or raw secret environment variables.
- The MVP does not promise that the official Windows Codex App UI will immediately display all third-party Flutter actions.
- Direct public exposure of the Bridge is out of scope; use LAN or VPN/mesh networking first.
