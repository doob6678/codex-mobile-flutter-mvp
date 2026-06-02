# Codex Mobile Flutter MVP

Codex Mobile 是一个半成品但可运行的移动端/网页端远程控制台：Windows 上运行 Bridge，Android APK 或 iPad Web 通过 Bridge 浏览项目文件、查看 Codex 历史、发送 Codex turn、显示 `/goal` 和任务进度。

当前状态要说清楚：手机和 iPad 已经能通过 Bridge 对话通信和控制一部分 Codex 工作流，但还不是 Windows 桌面 Codex UI 的完美实时镜像。Windows 桌面窗口本身有时不会立刻刷新，手机端依靠 Bridge 的 `/sync/stream`、`/sync/state` 和本地历史轮询刷新。

## 直接下载整包使用

不想自己编译时，下载发布版整包：

[Codex Mobile MVP v0.1.1 complete package](https://github.com/doob6678/codex-mobile-flutter-mvp/releases/tag/v0.1.1)

下载资产：

```text
codex-mobile-v0.1.1-windows-android-ipad.zip
```

解压后目录结构大致是：

```text
bridge-windows\          # Windows Bridge exe、启动脚本、内置 iPad Web、cloudflared 工具
android\                 # Android APK
README-START.md          # 发布包内的快速启动说明
```

在解压后的目录里启动：

```powershell
cd .\bridge-windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-codex-mobile.ps1
```

启动后控制台会打印三类地址：

```text
Windows QR page, open on this PC only:
  http://127.0.0.1:5010/connect
iPad/Web URLs, copy to iPad Safari or another browser:
  http://192.168.x.x:5010/ipad/
  https://xxxx.trycloudflare.com/ipad/
Phone Bridge base URLs, use in Android app or QR payload:
  http://192.168.x.x:5010
  https://xxxx.trycloudflare.com
```

只在 Windows 本机打开 `http://127.0.0.1:5010/connect`。手机和 iPad 不要填 `0.0.0.0` 或 `127.0.0.1`。

Android APK 在整包里：

```text
android\codex-mobile-android-app-release.apk
```

iPad/Web 不需要单独部署。Bridge 启动后，直接打开控制台打印的 `.../ipad/` 地址。

如果只要 APK，可以下载单独的 Android 发布版：

[Codex Mobile Android APK v0.1.1](https://github.com/doob6678/codex-mobile-flutter-mvp/releases/tag/v0.1.1-android)

注意：发布版整包可以直接运行 Bridge 和移动端，但 Windows 机器仍然需要已经安装并登录 Codex 桌面端或 Codex CLI。只有从源码重新打包时才需要 .NET SDK、Flutter SDK、Android SDK。

## 依赖

- Windows 10/11，PowerShell 5+。
- Git。
- Codex 桌面端或 Codex CLI 已安装并在 Windows 上登录。
- .NET 8 SDK：源码开发、测试、发布 Bridge 时需要。
- Flutter SDK：构建 Android APK、iPad Web、Windows Flutter 客户端时需要。
- Android SDK：只在构建 APK 时需要。
- 可选：Cloudflare Tunnel、Tailscale、ZeroTier 或 WireGuard，用于手机/iPad 跨网络访问。

## 拉取和启动

```powershell
git clone https://github.com/doob6678/codex-mobile-flutter-mvp.git
cd codex-mobile-flutter-mvp
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-bridge.ps1
```

如果想一个命令同时尝试打开 Windows Codex 桌面端和 Bridge：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\start-codex-mobile.ps1
```

这只是同一个入口启动两个程序，不是把 Bridge 接进桌面 Codex 的同一个 app-server。Bridge 仍会维护自己的 `codex app-server --listen stdio://` 进程。

## 启动后看哪里

控制台会打印三类地址：

```text
Windows QR page, open on this PC only:
  http://127.0.0.1:5010/connect
iPad/Web URLs, copy to iPad Safari or another browser:
  http://192.168.x.x:5010/ipad/
  https://xxxx.trycloudflare.com/ipad/
Phone Bridge base URLs, use in Android app or QR payload:
  http://192.168.x.x:5010
  https://xxxx.trycloudflare.com
```

只在 Windows 本机打开 `http://127.0.0.1:5010/connect`。手机和 iPad 不要填 `0.0.0.0` 或 `127.0.0.1`，必须用局域网/VPN/隧道真实地址。

## Android

发布包构建后 APK 在：

```text
dist\mobile-android\app-release.apk
```

安装后进入“配对”，扫描 Windows 本机 `/connect` 页面二维码，或手动填写 Phone Bridge base URL。

## iPad/Web

iPad Safari 或其他浏览器打开控制台打印的：

```text
http://Windows局域网IP:5010/ipad/
https://xxxx.trycloudflare.com/ipad/
```

`/ipad/` 可以通过 LAN/VPN/Cloudflare 隧道暴露给 iPad 加载网页端。安全边界是：`/connect` 和 `/pairing/start` 只允许 Windows 本机访问，二维码配对挑战不要通过外网页面生成。

## 打包

从项目根目录运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\package.ps1
```

输出目录：

```text
dist\bridge-windows\CodexMobile.Bridge.exe
dist\bridge-windows\start-bridge.ps1
dist\bridge-windows\start-codex-mobile.ps1
dist\mobile-android\app-release.apk
dist\mobile-ipad-web\
```

发布包里启动：

```powershell
cd .\dist\bridge-windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\start-codex-mobile.ps1
```

## 后台恢复和断连

移动端会把 Bridge 地址和配对 token 保存在本机。手机/iPad 放后台后，如果 App 或浏览器进程被系统回收，重新打开会自动带着上次保存的地址和 token 访问 Bridge。

这不是让长连接永远不断。以下情况仍要重新配对或改地址：

- Windows Bridge 进程关了。
- Cloudflare 临时隧道重启后 URL 变了。
- token 过期、被撤销，或 Bridge 数据目录被清理。
- 手机从同 Wi-Fi 切到 5G，原来的 `192.168.x.x` 地址不可达。

## 验证

常用检查：

```powershell
dotnet run --no-restore --project .\bridge\CodexMobile.Bridge.Tests\CodexMobile.Bridge.Tests.csproj
Push-Location .\mobile_app
flutter analyze
flutter test
Pop-Location
```

完整脚本：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\verify.ps1
```

## 当前限制

- 移动端/网页端可以作为 Bridge 远程 UI 使用，但对话实时性仍依赖 Bridge 事件流和轮询。
- 现有 Windows 桌面 Codex UI 不能保证被 Bridge 强制刷新。
- Cloudflare 免费临时隧道首次加载 Flutter Web 可能较慢，重启后地址会变化。
- iPad/Web 的 `/ipad/` 可以外部访问；不要把 Windows 本机 `/connect` 暴露出去。
- 项目路径因人而异，README 里的命令都要求从仓库根目录执行，不依赖固定的 `C:\Users\...` 本机路径。
