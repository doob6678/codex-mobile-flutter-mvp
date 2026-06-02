# Codex Mobile Progress

## Current State

- Bridge pairing now carries a `challengeId` in addition to the 6-digit code.
- `/connect` is local-only and `/pairing/start` is guarded against remote access.
- File browsing now supports text, markdown, image download, and external open paths.
- The mobile conversation page is split into thread list + chat pane.
- The mobile conversation page now shows Windows Codex history and phone-started Windows conversations in one entry point instead of hiding one source behind the other.
- Windows history threads can be opened and continued through Windows Codex; phone-started conversations bind to the same Windows Codex thread and reuse it for later messages.
- If a historical Codex thread is not loaded in the app-server yet, Bridge resumes it with `thread/resume` before retrying `turn/start`.
- Codex thread listing and reading now prefer `.codex` local JSONL history for fast mobile loading; sending and continuing a thread still uses the live app-server.
- Bridge keeps a persistent stdio app-server process so `thread/resume` and `turn/start` run on the same app-server connection instead of losing loaded-thread state between separate processes.
- Conversation detail panes automatically jump to the latest message after sending from mobile.
- The mobile conversation entry now calls `/codex/status` and shows whether it is in live Codex app-server mode or local-history fallback mode, including the backend recovery/error message.
- Bridge conversation details now treat linked Windows Codex thread messages as the authoritative chat stream; Bridge-local temporary messages are hidden when the real thread can be read.
- If Bridge cannot read the linked Codex thread, the mobile conversation panel shows the thread-read error while falling back to Bridge temporary messages for recovery.
- The packaged Bridge and Android release APK were refreshed after the authoritative Codex-thread sync fix, and the smoke check still passed.
- The app shell now keeps navigation collapsed by default on desktop and mobile; the top menu button opens the labeled drawer.
- The overview screen now includes a security card that shows `challengeId` + code pairing, local-only endpoints, and network exposure summary.
- `/sync/state` now restores the latest Windows goal from `.codex` history when Bridge starts empty, so the mobile goal panel can show the existing Windows `/goal` instead of blank state.
- Thread detail now hides command/reasoning/plan items by default and exposes them behind a toggle.
- `/goal` and task progress are visible in the overview screen.
- Windows start/package scripts print real `/connect` candidates before launching Bridge and suppress automatic browser popups with `CODEX_MOBILE_NO_BROWSER=1`.
- Bridge no longer auto-switches the default 5010 port to a random free port; start scripts now stop with a clear message if 5010 is occupied unless `-Urls` explicitly chooses another fixed port.
- `/connect` QR payloads now include a `bridgeUrls` candidate list, and the mobile pairing screen retries the next candidate when a scanned address fails with a socket/network route error.
- Bridge now supports explicit external/tunnel URLs from `CODEX_MOBILE_EXTERNAL_BRIDGE_URLS` or `bridge-external-urls.txt`; `/connect` prefers those `external` URLs before LAN addresses.
- `start-bridge.ps1` now attempts to launch/download `cloudflared.exe` and writes the temporary `https://*.trycloudflare.com` URL into the Bridge external URL file for 5G/cross-network phone pairing.
- 2026-06-02: Refined `scripts/start-bridge.ps1`, `scripts/bridge-tunnel.ps1`, and `scripts/package.ps1` so Windows-local `127.0.0.1` QR pages are printed separately from phone-usable LAN/VPN/tunnel base URLs. The package now copies the shared startup script instead of embedding divergent launch text, and the usage docs/README now say the phone must use real reachable Bridge base URLs, not `/connect` or `127.0.0.1`.

## Findings

### 2026-06-02 mobile conversation timeout

- Screenshot symptom: the mobile conversation list shows `Codex 后端：历史兜底` with `codex app-server status probe timed out`.
- Finding: `/codex/status` was probing `config/read` through the live `codex app-server`. When app-server startup/plugin sync is slow, this status check times out even though local Windows history can be read normally.
- Impact: the warning card is noisy and makes the user think the conversation page is broken. It should not block history loading, and it should not start or reset app-server just to render the list screen.
- Fix direction: make `/codex/status` a cheap Bridge-side state report, or label it as "local history mode" without touching app-server. Only send/start actions should require the live app-server.

### 2026-06-02 thread list/detail loading

- Finding: before the fast-path change, packaged Bridge measured about `4306ms` for `/codex/threads` and `4125ms` for `/codex/threads/{threadId}` because Bridge waited for live app-server before falling back to `.codex` history.
- Fix applied: list/detail now read local `.codex` history first when available.
- Verification: packaged Bridge measured `286ms` for `/codex/threads` and `66ms` for `/codex/threads/{threadId}` with `Source=local-codex-history` and `ItemCount=300`.
- Constraint: this only fixes opening and reading historical conversations. Continuing/sending still requires app-server because the assistant turn must execute on Windows.

### 2026-06-02 send over Cloudflare tunnel

- Screenshot symptom: sending from the mobile thread page fails with `HttpException: Software caused connection abort, uri = https://...trycloudflare.com/codex/turns`.
- Finding: `POST /codex/turns` is currently a long request. It waits for Windows Codex/app-server work and then the mobile client polls for a new assistant reply. Cloudflare temporary tunnels and mobile networks can abort long-held HTTP requests before the turn finishes.
- Impact: the message may reach Bridge or app-server, but the phone sees a transport failure and cannot reliably know whether Windows accepted it.
- Required fix direction: `/codex/turns` should acknowledge quickly, preferably with an accepted/job response, then run `turn/start` in the Bridge background. The mobile app should then poll `/codex/threads/{threadId}` or subscribe to an event stream for completion instead of keeping the send HTTP request open.
- Related endpoint design: this should also apply to `/conversations/{id}/messages`, because it relays to the same app-server turn path and can hit the same tunnel/mobile abort.

### 2026-06-02 single-signal turn lifecycle

- Finding: the older build pattern was not a true one-shot conversation model. It accepted one mobile signal first, then the later processing and completion records were written by Codex and only became visible after a later Codex launch/refresh.
- Meaning: the backend already has a real turn lifecycle with processing and finished records; the missing part was the mobile/Bridge path surfacing that lifecycle consistently.
- Decision: keep this as a recorded fact in the project notes so later fixes stay aligned with the real flow: accept the user signal, let Windows Codex process it, then surface the processing and completion records instead of treating the first signal as the whole conversation.

### 2026-06-02 applied fix for mobile tunnel abort

- Applied fix: `/codex/status` no longer probes or starts `codex app-server`; it reports cheap local Bridge/Codex-history state so the conversation list does not show `status probe timed out`.
- Applied fix: `POST /codex/turns` now returns quickly with `Sent=true`, `Accepted=true`, `Queued=true`, and a `JobId`, then dispatches `turn/start` to Windows Codex in the background.
- Applied fix: `POST /conversations/{id}/messages` also records the user message locally and dispatches the Windows Codex relay in the background instead of holding a mobile HTTP request open.
- Applied fix: Android polling for assistant replies was extended from about 20 seconds to about 180 seconds to match observed real turns such as a `1m39s` processed Codex reply.
- Verification: packaged Bridge check measured `/codex/status` at `10ms` and `/codex/turns` accepted/queued at `5ms`, avoiding long Cloudflare tunnel requests.

### 2026-06-02 app-server initialize transport failure

- Runtime symptom: a mobile send accepted by Bridge later logged `[turn_job_*] codex turn dispatch failed` with `codex app-server timed out waiting for 'initialize'` and app-server stderr `Failed to deserialize JSONRPCMessage: expected value at line 1 column 1`.
- Finding: Bridge was launching `codex app-server --listen stdio://` with `StandardInputEncoding = Encoding.UTF8`. On .NET this can emit a UTF-8 BOM at the start of redirected stdin, so the Rust JSON-RPC transport sees a non-JSON byte before `{` and rejects the first `initialize` frame.
- Applied fix: `StdioCodexAppServerClient` now uses `new UTF8Encoding(false)` for redirected stdin/stdout/stderr.
- Verification: packaged Bridge `/codex/raw` `config/read` completed in `172ms` with app-server initialization succeeding.
- Isolation check: posting a deliberately invalid `/codex/turns` job returned `Accepted=true`/`Queued=true`; two seconds later `/health` was still `ok`, `/codex/threads` still returned 142 threads, and the Bridge process was still alive. This confirms one failed turn dispatch no longer takes down the Bridge connection.

### 2026-06-02 turn progress and long-history follow-up

- Finding: long Codex history can make thread entry slow if Bridge parses and returns too many items. The local-history reader now keeps the newest 300 mapped items and de-duplicates identical user/assistant messages, so a huge thread does not flood the phone.
- Finding: the send problem was not just long history. The previous mobile flow treated one HTTP send as the whole operation, while Windows Codex can continue processing and writing records after the request is accepted.
- Applied fix: `/sync/state` now records generic Codex turn/job progress events, and `/sync/stream` can push them as part of the existing snapshot.
- Applied fix: `/codex/turns` and `/conversations/{id}/messages` record accepted, dispatch-started, completed, and failed events. `CodexAppServerGateway` records turn lifecycle events, and `StdioCodexAppServerClient` forwards app-server JSON-RPC notifications into mobile-visible sync events.
- Applied fix: Android sends JSON POST bodies as explicit UTF-8 bytes with a content length, reducing long-message ambiguity through tunnels.
- Applied fix: the conversation UI polls `/sync/state` and refreshes the same thread/conversation while a send is in progress, so the phone can show Windows Codex progress and later results without requiring a second user message.
- Applied fix: Markdown-rendered file names in conversation bubbles can be opened through the existing file preview path. The app matches the current conversation/thread working directory to a trusted Bridge project, opens text/HTML/Markdown with `readFile`, and downloads PDF/images before preview.
- Verification: Bridge tests passed with 58 tests, Flutter analyze passed, Flutter tests passed with 42 tests, packaged Bridge smoke passed with `ThreadCount=142`, `FirstThreadItems=300`, `GoalSynced=true`, and external URL QR support.

### 2026-06-02 streaming delta and file-link path fix

- Finding: Windows app-server was already emitting `item/agentMessage/delta` notifications. The phone still showed replies all at once because Bridge only recorded notification metadata and the mobile UI waited for local history to contain the completed assistant item.
- Applied fix: Bridge now includes the `delta` text for `item/agentMessage/delta` in `/sync/state` events. The mobile conversation screen aggregates deltas from the current send window and shows them in the pending assistant bubble until the completed history item replaces it.
- Finding: conversation file links failed when Codex output contained an absolute Windows path or an existing Markdown link. The first linkifier wrapped the Markdown label again, producing URL-encoded nested `file-ref` strings, then the phone sent an absolute path as a project-relative path. Bridge correctly rejected that as `Path escapes the authorized project root`, but the server logged it as an unhandled exception.
- Applied fix: existing Markdown links are left intact, `file-ref:` targets are URL-decoded, and absolute paths are matched against all trusted Bridge project roots using the longest-root match before sending only the relative path to `/files/read` or `/files/download`.
- Applied fix: `/files/list`, `/files/read`, `/files/download`, and `/files/hash` now return handled `400` JSON for invalid/escaped/missing paths instead of Kestrel unhandled exception logs.
- Verification: added regression tests for encoded Windows paths, existing Markdown links, longest-root project matching, and handled escaped-path file endpoint errors. Bridge tests passed with 59 tests, Flutter analyze passed, Flutter tests passed with 45 tests, and packaged Bridge smoke passed on port `51943`.

### 2026-06-02 conversation detail cleanup and active-state rendering

- Finding: `.codex` local history contains subagent metadata in `session_meta` (`thread_source=subagent`, `agent_nickname`, `agent_role`), but Bridge previously returned `null`, so mobile history could show subagent side conversations as normal conversations.
- Applied fix: Bridge now preserves local-history thread metadata and filters `thread_source=subagent` out of `/codex/threads`. Direct reads still preserve the metadata for diagnostics.
- Applied fix: Flutter also filters `CodexThreadSummary.isSubagent`, so app-server and local-history responses both avoid inserting subagent conversations into the main mobile thread list.
- Finding: one Codex request can produce multiple adjacent assistant message items. Rendering each as a separate bubble made one response look like several independent turns.
- Applied fix: `CodexThreadDetail` now merges adjacent assistant chunks into one assistant message while keeping user boundaries, so one request renders as one assistant bubble even when Codex wrote multiple points/items.
- Applied fix: project groups show only the newest 8 visible main threads by default with a "show remaining" control, and thread/conversation detail panes include a jump-to-bottom button.
- Applied fix: thread/conversation detail panes perform a fresh read of `/sync/state` plus the current thread/conversation when opened. Sending still polls `/sync/state` and aggregates `item/agentMessage/delta` text into the pending assistant bubble for streaming display.
- Applied fix: `/goal` is shown in a conversation only when the recovered goal belongs to the current thread. A current running/pending task is shown as a compact one-line row with a circular progress marker instead of dumping full task text into chat.
- Verification: added regressions for subagent filtering, adjacent assistant chunk merging, unrelated-goal suppression, current-goal display, active task row display, and conversation navigation stability.

### 2026-06-02 unscoped streaming delta fix

- Finding: the phone test log showed `item/agentMessage/delta` notifications arriving before `turn/completed`, but the pending assistant bubble stayed blank. The app-server delta notification can omit `threadId`; Bridge recorded the delta, but Flutter filtered it out because it did not match the current thread id.
- Applied fix: Bridge now tracks the active `turn/start` thread and maps unscoped `turn/*`, `item/*`, and `thread/*` notifications back to that active thread until `turn/completed`/failed/cancelled clears the context. `item/agentMessage/delta` events without their own `threadId` now carry the active `threadId` in `/sync/state`.
- Applied fix: Flutter also accepts unscoped `item/agentMessage/delta` events as a fallback when they arrive after the current send started and do not explicitly point at a different thread, so older Bridge builds or partially scoped notifications can still render live text in the pending assistant bubble.
- Applied fix: the conversation UI also polls the current thread/conversation detail while sending. If no delta is available but the refreshed history now contains a new assistant message after the current prompt, that assistant text is rendered in the same pending assistant bubble. The matching historical assistant item is temporarily hidden while pending so the UI does not render the same reply twice; completion replaces the pending bubble with the final history.
- Applied fix: thread and Bridge-conversation detail views now subscribe to `/sync/stream` while a send is pending. Incoming sync snapshots update the same pending assistant bubble immediately, so `item/agentMessage/delta` no longer waits for the 2-second polling loop. The existing `/sync/state` + thread/conversation polling remains as a fallback for history writes and missed stream events.
- Boundary: generated app-server protocol assets expose `thread/read`, `thread/resume`, `turn/start`, and related notification methods, but no stable method for forcing the existing Windows desktop Codex window to reload its visible conversation. The reliable mobile contract remains Bridge `/sync/state` plus repeated thread/conversation reads, independent of desktop UI refresh.
- Verification: added Bridge regression coverage for unscoped streaming deltas inheriting the active thread id, and Flutter widget coverage for a pending send rendering unscoped assistant deltas, `/sync/stream` pushed deltas without waiting for polling, and assistant text discovered by thread-history polling instead of the generic waiting text.

### 2026-06-02 passive Windows-history refresh

- Finding: a phone prompt can be accepted and processed by Bridge's own `codex app-server --listen stdio://` path while the already-open Windows desktop Codex window continues showing its previous UI state. The protocol snapshot includes `thread/inject_items`, `thread/loaded/list`, `thread/read`, `thread/resume`, and `turn/start`, but still no stable command that forces the existing desktop window to reload or display third-party mobile turns live.
- Applied fix: thread detail and Bridge-conversation detail now keep a passive 2-second refresh loop while the page is open and not actively sending. Each tick reads `/sync/state` plus the current thread/conversation detail, so Windows-side `.codex` history changes such as user messages or assistant replies appear on the phone without requiring another phone send.
- Applied fix: the mobile backend status label now says `Bridge 实时` instead of `实时同步`, making clear that the live contract is phone <-> Bridge/app-server plus local history reads, not guaranteed live mirroring inside the existing Windows desktop Codex UI.
- Verification: added a Flutter regression where the exact Windows-side message `在Windows发送时候手机没有收到` appears in the open phone thread after passive polling. `flutter analyze` and full `flutter test` passed with 52 tests.

### 2026-06-02 mobile USER overlay for phone-started turns

- Finding: `/codex/turns` accepted a phone prompt and dispatched it to Windows Codex, but Bridge only recorded job progress such as accepted/dispatch/completed. The phone showed the user bubble optimistically, while `/codex/threads/{threadId}` could still read local `.codex` history before that mobile user item appeared there. This made the phone reload path and the Windows desktop UI look inconsistent: assistant output could return, but the phone-sent USER was not a durable readable item.
- Boundary: `turn/start` does not expose `persistExtendedHistory`; that deprecated field exists on thread start/resume/fork parameters only. `thread/inject_items` can append raw model-visible items, but using it together with `turn/start` would risk showing the same user prompt to the model twice, so it is not used for this fix.
- Applied fix: Bridge now records a dedicated `codex.turn.mobile_user` event with the full redacted phone prompt when `/codex/turns` is accepted. `SyncStateService` stores these mobile user records by `threadId`, exposes them through `/sync/state`, and `CodexAppServerGateway.ReadThreadAsync` overlays them as normal `userMessage` items in `/codex/threads/{threadId}`.
- Applied fix: the overlay is explicitly marked `source=mobile-bridge` and is de-duplicated by role + text, so when local `.codex` history later catches up with the same user message the phone does not render two USER bubbles.
- Applied fix: Flutter model/widget regressions cover this path: a `mobile-bridge` `userMessage` parses as a normal USER message and the thread detail UI renders it after refresh instead of hiding it as technical output.
- Verification: Bridge tests passed with 64 tests after adding mobile-user overlay and de-duplication coverage. `flutter analyze`, `flutter test test\model_api_test.dart`, `flutter test test\app_widget_test.dart`, and full `flutter test` passed with 54 Flutter tests. `scripts\package.ps1` refreshed Bridge, Android APK, and Windows client artifacts, and `scripts\smoke-packaged-runtime.ps1 -Port 51946` passed with `ThreadCount=102`, `FirstThreadItems=300`, `ThreadSource=local-codex-history`, and `GoalSynced=true`.

## Verification

- `dotnet run --no-restore --project .\bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj`
- `flutter analyze`
- `flutter test`
- `powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -LiteralPath 'scripts\start-bridge.ps1' -Encoding UTF8 -Raw)) | Out-Null"`
- `powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -LiteralPath 'scripts\package.ps1' -Encoding UTF8 -Raw)) | Out-Null"`
- `powershell -NoProfile -Command "[scriptblock]::Create((Get-Content -LiteralPath 'scripts\smoke-packaged-runtime.ps1' -Encoding UTF8 -Raw)) | Out-Null"`
- `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\smoke-packaged-runtime.ps1 -Port 51906`
- Short manual launch check: `scripts\start-bridge.ps1 -Urls http://0.0.0.0:51907` printed `127.0.0.1` and LAN `/connect` candidates before startup, then was stopped with Ctrl+C.
- 2026-06-01: `flutter analyze`, `flutter test`, `flutter test test/model_api_test.dart`, and `dotnet run --no-restore --project bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj` passed after Windows goal recovery, security monitor card, combined conversations, technical-message hiding, and collapsed navigation work.
- 2026-06-01: `dotnet run --no-restore --project bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj` passed with 43 tests, `flutter test test/app_widget_test.dart` passed with 15 widget tests, `flutter analyze` reported no issues, and full `flutter test` passed with 31 tests after historical-thread resume and mobile conversation auto-scroll work.
- 2026-06-01: `scripts\package.ps1` refreshed `dist\bridge-framework-dependent`, `dist\bridge-windows`, and `dist\mobile-android\app-release.apk`; `scripts\smoke-packaged-runtime.ps1 -Port 51912` passed against the packaged Bridge after updating the smoke script for `challengeId`/`id` pairing.
- 2026-06-01: `dotnet run --no-restore --project bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj` passed with 44 tests after adding live-app-server-priority coverage. `flutter analyze` and full `flutter test` still passed. `scripts\package.ps1` refreshed Bridge/APK artifacts, and `scripts\smoke-packaged-runtime.ps1 -Port 51914` passed against packaged Bridge with app-server timeout fallback.
- 2026-06-01: `flutter test test/model_api_test.dart test/app_widget_test.dart` passed after adding `CodexBackendStatus` parsing and the conversation backend-mode card. Then `flutter analyze`, full `flutter test`, and `dotnet run --no-restore --project bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj` passed. `scripts\package.ps1` refreshed Bridge/APK artifacts, and `scripts\smoke-packaged-runtime.ps1 -Port 51915` passed.
- 2026-06-01: `flutter test test/model_api_test.dart test/app_widget_test.dart` passed with 33 tests after merging local mobile messages with linked Codex thread messages and rendering `codexThreadError` in the conversation panel. `flutter analyze` reported no issues.
- 2026-06-01: `flutter test test/model_api_test.dart test/app_widget_test.dart` first failed on the intended regression case where Bridge-local messages were mixed into a linked Codex thread, then passed after making Windows Codex thread messages authoritative. Full `flutter test`, `flutter analyze`, and `dotnet run --no-restore --project bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj` passed with 45 Bridge tests. `scripts\package.ps1` refreshed Bridge/APK artifacts, and `scripts\smoke-packaged-runtime.ps1 -Port 51918` passed against packaged Bridge.
- 2026-06-01: Removed the `path_provider` dependency so Windows build no longer drags in the `jni` FFI plugin chain. `flutter build windows --release` now passes and `scripts\package.ps1` refreshes `dist\mobile-windows\mobile_app.exe` alongside Bridge and Android APK. `flutter analyze`, full `flutter test`, Bridge tests, and `scripts\smoke-packaged-runtime.ps1 -Port 51919` all passed after the export helper and Windows build cleanup.
- 2026-06-01: Verified the Windows UI build path again after rejecting the `webview_windows` plugin route because it reintroduced the Windows symlink/plugin-build blocker. Mobile HTML rendering still uses `webview_flutter`; Windows keeps source preview plus download/open-with-external-app. `flutter analyze`, full `flutter test`, `flutter build windows --release`, `scripts\package.ps1`, and `scripts\smoke-packaged-runtime.ps1 -Port 51920` passed.
- 2026-06-01: Fixed unstable Bridge port behavior and mobile-data QR pairing fallback. Bridge tests passed with 45 tests, full `flutter test` passed with 36 tests, `flutter analyze` reported no issues, `scripts\package.ps1` refreshed Bridge/Android/Windows artifacts, and `scripts\smoke-packaged-runtime.ps1` passed with `ConnectQrHasBridgeUrls=true`, `NetworkEndpointCount=2`, and `NetworkNonLoopbackCount=1`.
- 2026-06-01: Added external/tunnel URL priority and pairing failure cooldown coverage. Bridge tests passed with 49 tests after adding `CODEX_MOBILE_EXTERNAL_BRIDGE_URLS` and `bridge-external-urls.txt` support.
- 2026-06-02: `dotnet run --no-restore --project bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj` passed with 58 tests after mobile-visible turn lifecycle events. `flutter analyze` and full `flutter test` passed with 42 tests after send-progress polling and conversation file-link opening. `dotnet publish bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj -c Release -r win-x64 --self-contained true --no-restore -o dist\bridge-windows` refreshed the Bridge. `flutter build apk --release` rebuilt Android and `dist\mobile-android\app-release.apk` was updated. `scripts\smoke-packaged-runtime.ps1 -Port 51942` passed against the packaged Bridge.
- 2026-06-02: `dotnet run --no-restore --project bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj` passed with 59 tests after the file endpoint safety wrapper and path regression tests. `flutter analyze` and full `flutter test` passed with 45 tests after streaming delta aggregation and absolute-path file-link fixes. `dotnet publish bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj -c Release -r win-x64 --self-contained true --no-restore -o dist\bridge-windows` refreshed the Bridge. `flutter build apk --release` rebuilt Android and `dist\mobile-android\app-release.apk` was updated. `scripts\smoke-packaged-runtime.ps1 -Port 51943` passed against the packaged Bridge.
- 2026-06-02: `dotnet run --no-restore --project bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj` passed with 60 tests after subagent local-history filtering. `flutter analyze`, `flutter test test\model_api_test.dart`, and `flutter test test\app_widget_test.dart` passed after adjacent assistant chunk merging, current-thread goal display, active task row display, and jump-to-bottom support.
- 2026-06-02: Full `flutter test` passed with 48 tests. `dotnet publish bridge\CodexMobile.Bridge\CodexMobile.Bridge.csproj -c Release -r win-x64 --self-contained true --no-restore -o dist\bridge-windows` refreshed the Bridge. `flutter build apk --release` rebuilt Android and `dist\mobile-android\app-release.apk` was updated. `scripts\smoke-packaged-runtime.ps1 -Port 51944` passed with `ThreadCount=102`, `FirstThreadItems=300`, `ThreadSource=local-codex-history`, and `GoalSynced=true`.

## Notes

- Windows bridge still binds to `0.0.0.0` by design; the user-facing connection URL comes from `/connect` and `network/interfaces`.
- The bridge console should not be treated as the connection URL.
- Binary files are downloaded before opening with external apps.
- Android Emulator uses `10.0.2.2`; real phones use the Windows LAN/VPN IP.
- If the default port is occupied, stop the old Bridge process or restart with a different explicit `-Urls` port and update the phone address. The Bridge will not silently choose a random port.
- The current packaged smoke passed and now verifies `/connect` exposes `bridgeUrls` plus the current network endpoint list.
- For mobile data/5G, use the generated Cloudflare tunnel URL or another routed external URL. Raw `10.x`, `192.168.x`, and `172.16-31.x` addresses only work when the phone network can route to the Windows machine.

## Next Work

- Add a Windows desktop Bridge management window if needed.
- Add richer file previews for more binary/text types.
- Improve live sync visibility for more Codex event types.
- Windows release packaging now succeeds without extra Developer Mode changes because the remaining Windows build dependencies no longer pull the FFI plugin chain that blocked symlink creation.
