# Security Model

The mobile app is a remote console. The Windows Bridge owns authority over files, commands, pairing, audit logs, and Codex app-server access. The mobile app never receives OpenAI API keys or raw Codex credentials.

## Trust Boundaries

| Component | Trust level | Responsibilities |
|---|---|---|
| Flutter app | Untrusted display and input client | Stores short-lived Bridge tokens, renders files/events/approval cards, sends user actions. |
| Windows Bridge | Trusted local authority | Enforces pairing, project whitelist, path checks, command policy, audit logging, and app-server compatibility. |
| Codex app-server | Local Codex capability provider | Manages Codex account/config/thread/turn/filesystem primitives behind the Bridge. |
| OpenAI credentials | Local secret | Remain in Windows/Codex storage and are never copied to mobile. |

## Pairing

- Pairing is initiated locally through `POST /pairing/start`.
- The Bridge returns a short-lived QR payload or pairing code.
- `POST /pairing/complete` exchanges proof of possession for a device-bound access token and refresh token.
- Pairing challenges expire quickly and are single-use.
- Devices must be revocable by device id.

## Project Whitelist

- Agent-readable and agent-writable roots must be explicitly authorized.
- A path is accepted only after canonicalization.
- The canonical path must remain inside an authorized root.
- `..` traversal, symlink/junction/reparse-point escape, and whole-drive write scopes are rejected.
- Directory browsing and agent write access are separate permissions.

## Files

- Text previews default to UTF-8.
- Large files are bounded by size limits and should use pagination or range reads.
- Binary files are read-only in MVP unless a specific handler exists.
- Patch application requires a `baseHash` match to prevent overwriting concurrent edits.
- Sensitive directories such as `.ssh`, `.codex`, browser profiles, credential stores, and OS system directories are hidden or blocked by default.

## Commands

Commands are not arbitrary shell access. The Bridge enforces:

- Allowlisted command templates.
- Fixed or validated `cwd` under an authorized project.
- Argument validation.
- Timeout and output-size limits.
- Environment variable redaction.
- Approval before writes, installs, network-heavy operations, dangerous commands, or policy escalations.
- Deny-by-default handling for destructive system operations.

Recommended policy levels:

| Level | Examples | Default action |
|---|---|---|
| Read-only | `git status`, directory listing, safe metadata reads | Allow or low-friction approval. |
| Test/build | `dotnet test`, `flutter analyze`, `flutter test` | Allowlist, project scoped. |
| Write | Patch application, generated file writes | Require diff approval. |
| Risky | Dependency installs, deletes, moves, broad formatting, network calls | Strong approval. |
| Forbidden | Disk formatting, system-directory writes, secret exfiltration | Deny. |

## Approvals

App-server approval requests are converted into mobile approval cards:

- Command approvals: `item/commandExecution/requestApproval`, `execCommandApproval`.
- File approvals: `item/fileChange/requestApproval`, `applyPatchApproval`.
- Permission approvals: `item/permissions/requestApproval`.
- Tool-input prompts: `item/tool/requestUserInput`.

Approval cards must show command, cwd, target files, risk level, diff/patch summary, and expiry. Resolved approvals are logged and broadcast through the event hub.

## Audit Logs

The Bridge records append-only audit events for:

- Pairing, token refresh, and device revocation.
- Project whitelist changes.
- File reads, hashes, patch proposals, and patch application.
- Command previews, approvals, execution start/finish, exit code, and output hash.
- App-server approval requests and resolutions.

Audit entries must redact secrets. Suggested fields include timestamp, device id, project id, path, file hash, diff hash, command template, cwd, approval id, model id when available, stdout/stderr hash, exit code, and result.

## Network Exposure

- MVP target is LAN or VPN/mesh access, not direct public internet exposure.
- Prefer HTTPS/WSS even on LAN.
- Bind only to configured interfaces.
- `GET /network/interfaces` only reports loopback, private LAN, link-local, and mesh/VPN candidates by default.
- Public hosts are suppressed unless `CODEX_MOBILE_ALLOW_PUBLIC_BRIDGE=1` is set for an explicit temporary test.
- Do not expose raw app-server transport to the phone.
- Expose Codex app-server only through Bridge allowlisted methods; direct `fs/writeFile`, process, and command execution methods must stay behind approval-specific routes.
- A cloud relay, if added later, should route encrypted messages only and must not store source code, long-lived tokens, or OpenAI keys.

## Goal And Task Sync

- Mobile `/goal` writes and task creation are protected by pairing tokens.
- Windows/Codex-side task progress updates go through `/tasks/{id}/progress`.
- `/sync/state` and `/sync/stream` return redacted progress state only; they do not expose raw Codex auth files, OpenAI keys, or command output beyond approved summaries.
- Real-time sync uses Bridge-owned state and short-lived paired-device access, so both phone and Windows see the same goal/task lifecycle without placing secrets on the phone.

## Codex App UI Synchronization

The stable target is state synchronization between Flutter, Bridge, and local Codex app-server concepts. The MVP must not claim that third-party Flutter actions always appear live in the official Windows Codex App UI unless a future official contract or local verification proves it.
