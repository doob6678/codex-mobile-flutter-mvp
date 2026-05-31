# Codex Mobile Flutter MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a tested MVP of the research target: a Flutter mobile console that talks to a Windows Bridge, which safely exposes project/file/session/approval/event capabilities and adapts to the local Codex app-server protocol assets.

**Architecture:** The Windows Bridge is the authority for project roots, file access, sessions, command approvals, audit logs, and Codex app-server compatibility metadata. The Flutter app is a lightweight client with pairing, project/file browsing, conversation, approvals, and settings screens. Generated Codex app-server schemas are checked into `generated/` and summarized by Bridge APIs instead of exposing raw local credentials.

**Tech Stack:** .NET 8 ASP.NET Core Minimal API, SignalR, xUnit, Flutter/Dart 3.9, Material 3, `flutter_test`, generated `codex app-server` TypeScript/JSON schema assets.

---

### Task 1: Repository And Protocol Baseline

**Files:**
- Create: `.gitignore`
- Create: `docs/superpowers/plans/2026-05-30-codex-mobile-mvp.md`
- Create: `docs/protocol-assets.md`
- Generate: `generated/codex-app-server-ts/**`
- Generate: `generated/codex-app-server-schema/**`

- [x] **Step 1: Initialize Git and feature branch**

Run: `git init -b main && git checkout -b feature/codex-mobile-mvp`

Expected: repository exists on `feature/codex-mobile-mvp`.

- [x] **Step 2: Generate Codex protocol assets**

Run:

```powershell
New-Item -ItemType Directory -Force -Path generated\codex-app-server-ts,generated\codex-app-server-schema | Out-Null
codex app-server generate-ts --experimental --out generated\codex-app-server-ts
codex app-server generate-json-schema --experimental --out generated\codex-app-server-schema
```

Expected: generated files include `generated/codex-app-server-ts/v2/ThreadStartParams.ts` and `generated/codex-app-server-schema/codex_app_server_protocol.v2.schemas.json`.

- [x] **Step 3: Document protocol source and supported MVP mapping**

Create `docs/protocol-assets.md` with the exact generation commands, local CLI version, and the Bridge endpoints that map to Codex concepts: config/account summary, thread list/read/start, turn events, approval cards, and filesystem read/list.

- [x] **Step 4: Commit baseline**

Run:

```powershell
git add .gitignore docs generated codex-mobile-flutter-research.md
git commit -m "chore: initialize codex mobile mvp baseline"
```

### Task 2: Windows Bridge Backend

**Files:**
- Create: `CodexMobile.sln`
- Create: `bridge/CodexMobile.Bridge/CodexMobile.Bridge.csproj`
- Create: `bridge/CodexMobile.Bridge.Tests/CodexMobile.Bridge.Tests.csproj`
- Create: `bridge/CodexMobile.Bridge/Program.cs`
- Create: `bridge/CodexMobile.Bridge/Models/*.cs`
- Create: `bridge/CodexMobile.Bridge/Services/*.cs`
- Create: `bridge/CodexMobile.Bridge/Hubs/BridgeHub.cs`
- Create: `bridge/CodexMobile.Bridge.Tests/*.cs`

- [x] **Step 1: Write failing tests first**

Add xUnit tests for path canonicalization, project whitelist enforcement, text file reading, patch hash mismatch rejection, command allowlist rejection, pairing token expiry, and audit log redaction.

Run: `dotnet test bridge/CodexMobile.Bridge.Tests/CodexMobile.Bridge.Tests.csproj`

Expected before implementation: FAIL because services do not exist.

- [x] **Step 2: Implement minimal Bridge**

Implement Minimal API endpoints:

```text
GET /health
GET /protocol/summary
POST /pairing/start
POST /pairing/complete
GET /projects
POST /projects
GET /files/list
GET /files/read
GET /files/hash
POST /files/patch
GET /conversations
POST /conversations
GET /conversations/{id}
POST /conversations/{id}/messages
GET /approvals
POST /approvals/{id}/resolve
GET /audit
POST /commands/preview
POST /commands/run
```

Add SignalR hub at `/hubs/events` for `message.created`, `approval.requested`, `patch.proposed`, and `command.finished`.

- [x] **Step 3: Verify backend tests**

Run: `dotnet test bridge/CodexMobile.Bridge.Tests/CodexMobile.Bridge.Tests.csproj`

Expected: PASS.

- [x] **Step 4: Commit backend**

Run:

```powershell
git add bridge CodexMobile.sln
git commit -m "feat: add tested windows bridge backend"
```

### Task 3: Flutter Mobile Client

**Files:**
- Create: `mobile_app/**`
- Create: `mobile_app/lib/main.dart`
- Create: `mobile_app/lib/src/api/*.dart`
- Create: `mobile_app/lib/src/models/*.dart`
- Create: `mobile_app/lib/src/screens/*.dart`
- Create: `mobile_app/test/*.dart`

- [x] **Step 1: Scaffold Flutter app**

Run: `flutter create --platforms=android,windows mobile_app`

Expected: Flutter app exists with Material baseline.

- [x] **Step 2: Write failing widget/model tests first**

Add tests for JSON parsing, service URL construction, navigation surfaces, project/file list rendering, approval action rendering, and release bridge safety text.

Run: `flutter test`

Expected before implementation: FAIL because app models/screens are absent.

- [x] **Step 3: Implement MVP UI and API client**

Implement screens: pairing, dashboard, projects, file manager, file preview, conversations, approvals, settings. Use injectable `CodexMobileApi` so widget tests run without a live server.

- [x] **Step 4: Verify Flutter tests and analysis**

Run:

```powershell
cd mobile_app
flutter analyze
flutter test
```

Expected: PASS.

- [x] **Step 5: Commit Flutter client**

Run:

```powershell
git add mobile_app
git commit -m "feat: add flutter codex mobile client"
```

### Task 4: Integration, Docs, And GitHub

**Files:**
- Create: `README.md`
- Create: `docs/api.md`
- Create: `docs/security.md`
- Create: `docs/testing.md`
- Create: `scripts/verify.ps1`

- [x] **Step 1: Add verification script**

Create `scripts/verify.ps1` to run backend tests, Flutter analyze, Flutter tests, and generated protocol asset checks.

- [x] **Step 2: Add docs**

Document local setup, pairing, project whitelist, file permissions, command approvals, audit logs, generated Codex app-server assets, and limitations of official Codex App UI synchronization.

- [x] **Step 3: Run full verification**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify.ps1`

Expected: all checks pass.

- [x] **Step 4: Final commit and GitHub push**

Run:

```powershell
git add README.md docs scripts
git commit -m "docs: document codex mobile mvp"
gh repo create codex-mobile-flutter-mvp --private --source . --remote origin --push
```

Expected: private GitHub repository exists and branch is pushed.

---

## 2026-05-31 Progress Record

- Bridge, Flutter mobile client, Codex protocol assets, docs, and verification script are implemented on `feature/codex-mobile-mvp`.
- Full verification passed with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\verify.ps1`: 21 Bridge service tests, backend HTTP smoke, Flutter analyze, and 16 Flutter widget/model tests.
- Release packaging is oriented around the real deployment shape: Windows Bridge folder plus Android APK. Current artifacts:
  - `dist\bridge-framework-dependent\start-bridge.ps1`
  - `dist\bridge-framework-dependent\CodexMobile.Bridge.dll`
  - `dist\bridge-framework-dependent\CodexMobile.Bridge.exe`
  - `dist\mobile-android\app-release.apk`
- Windows desktop Flutter build remains optional; the phone app plus Windows Bridge server is the primary deliverable.
