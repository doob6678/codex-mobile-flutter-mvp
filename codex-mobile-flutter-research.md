# Codex 移动端 Flutter 实现调研方案

调研日期：2026-05-30

## 目标

本方案用于评估并设计一个 Flutter 移动端应用，使手机可以实现类似 Codex 的远程开发体验：

- 在手机端查看和管理 Windows 本机项目。
- 浏览 Markdown、PDF、JS、代码文件等多种文件。
- 通过自然语言发起代码分析、修改、测试、命令执行等任务。
- 在手机端查看 Codex 任务进度、完成情况，并设置 `/goal` 目标。
- 支持多个子 agent 并行调研、执行和汇总结果。
- 使用本地 Windows 机器上的 OpenAI API key 或本地 Codex 能力，而不是在手机端暴露密钥。

核心结论：手机端不应直接运行 Codex 或直接读取 Windows 盘符。推荐架构是 Flutter App + Windows Bridge + OpenAI API/Codex app-server 可选集成。

## 官方 Codex 移动端现状

官方移动端入口更接近远程控制台：手机端发起任务、继续线程、查看 diff、测试和终端输出、审批操作；Windows/Mac 主机负责真实文件访问、命令执行、代码修改和本地工具调用。自研 Flutter App 也应采用这一边界。

## 推荐架构

```text
Flutter Mobile App
  - 配对、项目列表、文件管理器、预览、会话、审批、设置
  - HTTPS REST + SignalR/WebSocket

Windows Bridge
  - 设备配对和认证
  - 项目白名单
  - 文件浏览、读取、hash、patch
  - 会话、审批、命令 allowlist、审计日志
  - Codex app-server 协议适配

Windows 文件系统 / Git / Shell / Codex app-server
```

MVP 优先局域网直连，不做公网暴露。远程访问后续通过 VPN、Tailscale/ZeroTier、WireGuard 或云中继解决。

## 接入路线

优先级：

1. Flutter -> Windows Bridge -> `codex app-server`。
2. Flutter -> Windows Bridge -> `codex exec --json`。
3. Flutter -> Windows Bridge -> Responses API / Agents SDK 自研 agent loop。

Bridge 不应把 `.codex/auth.json`、OpenAI API key 或原始 app-server socket 暴露给手机。Flutter 只保存 Bridge 颁发的短期 token。

## 文件能力

Bridge 文件 API：

| API | 功能 |
|---|---|
| `GET /projects` | 获取授权项目列表 |
| `POST /projects` | 添加项目根目录 |
| `GET /files/list` | 获取目录列表 |
| `GET /files/read` | 读取 UTF-8 文本 |
| `GET /files/hash` | 获取文件 hash |
| `POST /files/patch` | 在 hash 匹配时应用 patch |

路径安全要求：

- 每个项目必须显式授权根目录。
- 所有路径必须 canonicalize。
- canonicalize 后必须确认仍位于授权根目录内。
- 禁止 `..` 路径逃逸、符号链接/junction/reparse point 逃逸。
- 全盘浏览默认只读，写入和删除必须单独授权。

## 命令和审批

不能让模型直接执行任意 shell。MVP 命令执行只支持 allowlist 模板，例如 `git status`、`dotnet test`、`flutter analyze`、`flutter test`。写文件、应用 patch、运行测试或高风险操作必须进入审批和审计日志。

## 子 agent 设计

Windows Bridge/主 agent 负责拆解任务，子 agent 可分为 Explorer、Researcher、Coder、Tester、Reviewer、Summarizer。子 agent 输出结构化报告或 patch，主 agent 汇总，Flutter 展示结果、diff 和审批按钮。

## MVP 开发路线

1. Windows Bridge：HTTP/SignalR 服务、配对、项目白名单、文件 API、patch、命令 allowlist、会话、审批、审计、协议摘要。
2. Flutter 客户端：配对、项目、文件、预览、会话、审批、设置。
3. Codex app-server 适配：生成协议资产，Bridge 做稳定移动 API 封装。
4. 测试：后端服务测试、HTTP smoke check、Flutter analyze/test、协议资产校验。
5. Git/GitHub：用分支、提交和远程仓库管理版本。

## 不建议的方案

- 不把 OpenAI API key 写进 Flutter App。
- 不让 Flutter 直接读取 Windows `C:\` 或 `.codex/auth.json`。
- 不直接公网暴露 Windows Bridge。
- 不承诺官方 Windows Codex App UI 一定同步显示第三方 Flutter 会话，除非官方契约或本地实测证明。

## 当前实现映射

本仓库实现了调研的 MVP 骨架：

- `bridge/CodexMobile.Bridge` 实现 Windows Bridge。
- `mobile_app` 实现 Flutter 移动端界面和 Bridge API client，包含 `/goal` 和任务进度面板。
- `generated/` 保存本地 Codex app-server 协议快照。
- `scripts/verify.ps1` 执行协议、后端、HTTP smoke、实时同步流、Flutter 的完整验证。
