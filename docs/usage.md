# Codex 移动端使用说明

这套东西分成两部分：Windows 上跑 Bridge，Android 手机上装 APK。手机不直接读取 Windows 磁盘，也不保存 OpenAI/Codex 密钥；所有项目、文件、对话历史和 `/goal` 同步都通过 Bridge 访问。

## 1. 启动 Windows Bridge

开发目录里启动：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-bridge.ps1
```

发布包里启动：

```powershell
cd C:\Users\doob\Desktop\code\dev\codex_mobile_app\dist\bridge-framework-dependent
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-bridge.ps1
```

默认监听：

```text
http://0.0.0.0:5010
```

这表示 Windows 会对本机网卡开放端口。手机连接时不要填 `127.0.0.1`，因为手机里的 `127.0.0.1` 指的是手机自己，不是 Windows。

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

## 3. 安装 Android APK

APK 路径：

```text
C:\Users\doob\Desktop\code\dev\codex_mobile_app\dist\mobile-android\app-release.apk
```

把这个 APK 安装到手机。安装后打开应用，默认会进入“配对”页。

## 4. 配对

在手机“配对”页：

1. 在“Bridge 地址”里填 Windows 的真实地址，例如 `http://192.168.31.25:5010`。
2. 点“开始配对”。
3. 应用会显示配对码。
4. 点“完成配对”后，手机会保存当前会话的 Bridge 访问令牌。

配对后再打开“项目”“文件”“对话”“审批”“目标”“设置”等页面。

## 5. 侧边栏

左侧默认是收起状态，只显示图标。点击左上角菜单按钮可以展开中文侧边栏，再点任意入口会自动收回。

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

## 6. 真实 Codex 历史和知识库

Bridge 会读取本机 Codex 历史：

```text
C:\Users\doob\.codex\session_index.jsonl
C:\Users\doob\.codex\sessions\...
C:\Users\doob\.codex\archived_sessions\...
```

手机“对话”页显示的是这些真实线程，不是测试假数据。

Bridge 也会自动尝试加入 AgentScope Java Harness 知识库目录。进入“文件”页后选择这个项目，就可以打开 `00-总目录.md` 等 Markdown 文件。

## 7. 常见问题

如果手机报 `address = 127.0.0.1`，说明填错地址了。改成 Windows 的真实局域网 IP 或组网 IP。

如果手机连不上：

1. 确认 Bridge 正在运行。
2. 确认 Windows 和手机在同一网络，或已经通过 VPN/组网互通。
3. 在 Windows 上测试 `http://127.0.0.1:5010/health`。
4. 在手机浏览器里打开 `http://真实IP:5010/health`，能看到返回再进 App 配对。
5. 检查 Windows 防火墙是否放行 5010 端口。

如果跨公网使用，不要直接暴露 Bridge。先用 Tailscale、ZeroTier、WireGuard 这类私有组网。
