# Codex 移动端使用说明

这套东西分成两部分：Windows 上跑 Bridge，Android 手机上装 APK。手机不直接读取 Windows 磁盘，也不保存 OpenAI/Codex 密钥；所有项目、文件、对话历史和 `/goal` 同步都通过 Bridge 访问。

## 1. 启动 Windows Bridge

开发目录里启动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-bridge.ps1
```

如果希望一次命令同时打开 Windows Codex 桌面端和 Bridge，用：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-codex-mobile.ps1
```

发布包里同样可以运行：

```powershell
cd "%USERPROFILE%\Desktop\code\dev\codex_mobile_app\dist\bridge-windows"
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-codex-mobile.ps1
```

这个脚本做的是“同一个入口启动两个程序”：先检测/打开 Windows Codex 桌面端，再运行 Bridge。它不是把 Bridge 接进桌面 Codex 的同一个 app-server。当前 Windows 版 `codex app-server daemon` 生命周期不可用，`codex app-server proxy` 也没有可连接的控制 socket，所以 Bridge 仍然保持自己的 `stdio://` app-server 进程；手机端实时显示依靠 Bridge 的 `/sync/stream`、`/sync/state` 和对本地 Codex 历史的轮询刷新。

发布包里推荐直接启动 Windows exe：

```powershell
cd "%USERPROFILE%\Desktop\code\dev\codex_mobile_app\dist\bridge-windows"
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-bridge.ps1
```

`dist\bridge-windows\CodexMobile.Bridge.exe` 是自包含发布，不要求目标机器预装 .NET SDK。

默认监听：

```text
http://0.0.0.0:5010
```

这表示 Bridge 绑定所有本机网卡的 5010 端口。`0.0.0.0` 只是监听地址，不是手机要填写的 URL。手机连接时不要填 `0.0.0.0`，也不要填 `127.0.0.1`；手机里的 `127.0.0.1` 指的是手机自己，不是 Windows。

默认端口固定为 5010，不会在 5010 被占用时自动换成随机端口。端口冲突时先关闭旧 Bridge 进程，或者用 `-Urls http://0.0.0.0:固定端口` 显式指定另一个固定端口。

启动脚本会把“Windows 本机扫码页”和“手机 Bridge 地址”分开打印，类似：

```text
Windows QR page, open on this PC only:
  http://127.0.0.1:5010/connect
Phone Bridge base URLs, use in Android app or QR payload:
  http://192.168.31.25:5010
  http://100.72.10.9:5010
```

在 Windows 本机浏览器打开 `127.0.0.1` 那个扫码页；手机手动输入时只使用 `192.168.x.x`、`10.x.x.x`、`172.16-31.x.x`、`100.x.x.x` 或 HTTPS 隧道这类真实可达的 Bridge 基础地址，不要带 `/connect`。

如果手机走 5G/流量，不在同一个 Wi-Fi，`10.x.x.x`、`192.168.x.x`、`172.16-31.x.x` 这种内网地址通常不能直接连。默认启动脚本会尝试启动 Cloudflare 临时 HTTPS 隧道：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-bridge.ps1
```

脚本会优先使用包内 `tools\cloudflared.exe`、`CLOUDFLARED_PATH` 或 PATH 里的 `cloudflared`；都没有时会自动下载到 `tools\cloudflared.exe`。成功后会打印：

```text
External mobile URL: https://xxxx.trycloudflare.com
Use this base URL on Android when the phone is outside the LAN.
```

这时打开 Windows 本机 `http://127.0.0.1:5010/connect` 生成二维码，二维码会优先写入这个 HTTPS 隧道基础地址，手机流量网络也可以连接。临时隧道随 `start-bridge.ps1` 进程关闭而关闭，重启后 URL 会变化，需要重新扫码。

如果已经有自己的公网/内网穿透/Tailscale Funnel 地址，也可以直接配置：

```powershell
$env:CODEX_MOBILE_EXTERNAL_BRIDGE_URLS="https://你的公网地址"
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-bridge.ps1 -NoTunnel
```

Bridge 每次打开 `/connect` 都会重新读取 `CODEX_MOBILE_EXTERNAL_BRIDGE_URLS` 和 `bridge-external-urls.txt`，不需要重启 Bridge 才能更新二维码里的外部地址。

## 2. 找到手机要填的真实地址

优先用 Windows 的局域网 IP 或组网/VPN IP，例如：

```text
http://192.168.31.25:5010
http://100.x.x.x:5010
```

也可以在 Bridge 启动后通过接口查看候选地址：

```powershell
Invoke-RestMethod -Uri http://127.0.0.1:5010/network/interfaces
```

手机和 Windows 在同一个 Wi-Fi 下，用 `192.168.x.x` 这一类地址。跨网络时用 Tailscale、ZeroTier、WireGuard 等组网后的 `100.x.x.x` 或对应 VPN 地址。

Bridge 还提供一个 Windows 本机扫码连接页：

```text
http://127.0.0.1:5010/connect
```

只在 Windows 浏览器打开这个地址，页面会自动生成新的配对挑战、推荐真实 Bridge 地址，并显示二维码。二维码里同时包含 `bridgeUrl` 和 `bridgeUrls` 候选列表；手机端扫描后会按候选地址顺序尝试连接，一个地址在当前网络不可达时会自动尝试下一个。

`/connect` 和 `/pairing/start` 是本地启动入口，只允许从 Windows 本机访问。手机拿到 QR 里的真实 Bridge 地址和短期 challenge 后，再用 `/pairing/complete` 换取 Bridge 访问 token。配对码、challenge 和 token 都只用于 Bridge 配对，不是 OpenAI API Key，也不会把 `OPENAI_API_KEY` 或 Codex 凭据复制到手机。

配对后的访问 token 只保存在当前 App 会话里，用 `Authorization: Bearer ...` 调用 Bridge。Bridge 的设置页只显示 token 指纹、设备名和过期时间，不显示原始 token。没有 token 的请求访问 `/projects`、`/files`、`/codex/threads`、`/goal`、`/pairing/tokens` 等接口会返回 401。

## 3. 安装 Android APK

APK 路径：

```text
%USERPROFILE%\Desktop\code\dev\codex_mobile_app\dist\mobile-android\app-release.apk
```

把这个 APK 安装到手机。安装后打开应用，默认会进入“配对”页。

## 4. 配对

在手机“配对”页，推荐流程：

1. Windows 打开 `http://127.0.0.1:5010/connect`。
2. 手机点“扫描 Bridge QR”。
3. 扫描 Windows 页面上的二维码。
4. App 自动完成配对并保存当前会话的 Bridge 访问令牌。

手动流程也保留：

1. Windows 本机打开 `http://127.0.0.1:5010/connect`，刷新生成新的配对挑战。
2. 在手机“Bridge 地址”里填 Windows 的真实地址，例如 `http://192.168.31.25:5010`。
3. 按页面显示的二维码或明文内容，把 `challengeId` 和 6 位配对码交给手机。
4. 手机带着 `challengeId` 和配对码调用远端 `/pairing/complete`，Bridge 返回访问 token。

配对后再打开“项目”“文件”“对话”“审批”“目标”“设置”等页面。

## 5. 本机、局域网和模拟器地址

| 场景 | 应该使用的地址 |
|---|---|
| Windows 本机打开连接页 | `http://127.0.0.1:5010/connect` |
| Android 真机同 Wi-Fi | `http://Windows局域网IP:5010` |
| Android 真机 5G/跨网 | `https://xxxx.trycloudflare.com` 或自己的公网/隧道地址 |
| Tailscale/ZeroTier/WireGuard | `http://组网IP:5010` |
| Android Emulator | `http://10.0.2.2:5010` |

Android Emulator 的 `10.0.2.2` 会转到宿主机 Windows；真机不能用这个地址。真机必须使用 Windows 的真实局域网 IP 或组网 IP。

## 6. 文件下载和外部打开

文件页支持文本/Markdown 直接预览。图片、PDF、压缩包和其他二进制文件会先通过 Bridge 下载到手机，再交给系统“打开方式”选择器处理。Bridge 仍然只允许访问已信任项目根目录下的文件；手机不能绕过项目白名单读取 Windows 任意路径。

## 7. 侧边栏

手机默认没有常驻左侧栏，不会占窄屏宽度。每个页面顶部左侧固定一个菜单图标，点击后打开中文目录抽屉，再点任意入口会自动收回。

主要入口：

| 入口 | 用途 |
|---|---|
| 配对 | 输入真实 Bridge 地址并完成配对 |
| 概览 | 查看 Bridge 是否连接 |
| 项目 | 查看 Windows 上已信任的项目根目录 |
| 文件 | 浏览项目目录，打开 Markdown、Dart、代码文本 |
| 对话 | 查看真实本地 Codex 历史线程 |
| 审批 | 处理命令、文件修改等审批 |
| 目标 | 设置 `/goal`，查看任务进度 |
| 设置 | 查看可用于手机连接的 Bridge 地址和安全状态 |

## 8. 真实 Codex 历史和知识库

Bridge 会读取本机 Codex 历史：

```text
%USERPROFILE%\.codex\session_index.jsonl
%USERPROFILE%\.codex\sessions\...
%USERPROFILE%\.codex\archived_sessions\...
```

手机“对话”页显示的是这些真实线程，不是测试假数据。

Bridge 也会自动尝试加入 AgentScope Java Harness 知识库目录。进入“文件”页后选择这个项目，就可以打开 `00-总目录.md` 等 Markdown 文件。

## 9. 端口冲突和恢复

如果 5010 被占用，Bridge 会启动失败并在控制台显示端口绑定错误。处理方式：

1. 先关闭旧的 `CodexMobile.Bridge.exe`、`dotnet` Bridge 进程或占用 5010 的程序。
2. 重新运行 `scripts\start-bridge.ps1`。
3. 或临时换端口启动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-bridge.ps1 -Urls http://0.0.0.0:51910
```

换端口后，手机也必须使用新端口，例如 `http://192.168.31.25:51910`。旧 token 不会因为换端口自动失效，但手机保存的 Bridge 地址需要更新。

## 10. 常见问题

如果手机报 `address = 127.0.0.1`，说明填错地址了。改成 Windows 的真实局域网 IP 或组网 IP。

如果手机能看到端口但没有完成配对 token，除了 `/health`、`/security/status`、Windows 本机 `/connect` 和短期 `/pairing/complete` 外，Bridge 受保护接口都会拒绝访问。设置页“已配对设备密钥”只显示安全指纹，用来确认当前设备的配对状态，不是原始密钥。

如果手机连不上：

1. 确认 Bridge 正在运行。
2. 确认 Windows 和手机在同一网络，或已经通过 VPN/组网互通。
3. 在 Windows 上测试 `http://127.0.0.1:5010/health`。
4. 在手机浏览器里打开 `http://真实IP:5010/health`，能看到返回再进 App 配对。
5. 检查 Windows 防火墙是否放行 5010 端口。

如果连接页能打开但手机无法完成配对，重新刷新 Windows 上的 `/connect` 页面生成新的配对挑战。配对挑战是短期、一次性的，过期或已使用后需要重新生成。

如果跨公网使用，不要直接暴露 Bridge。先用 Tailscale、ZeroTier、WireGuard 这类私有组网。
