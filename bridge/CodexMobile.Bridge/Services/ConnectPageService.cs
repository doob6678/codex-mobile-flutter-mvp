using System.Net;
using System.Text;
using System.Text.Encodings.Web;
using System.Text.Json;
using CodexMobile.Bridge.Models;
using QRCoder;

namespace CodexMobile.Bridge.Services;

public sealed class ConnectPageService
{
    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web)
    {
        WriteIndented = false,
    };

    private readonly PairingService pairing;
    private readonly NetworkInterfaceService network;

    public ConnectPageService(PairingService pairing, NetworkInterfaceService network)
    {
        this.pairing = pairing;
        this.network = network;
    }

    public ConnectPage Create(string scheme, int port, TimeSpan pairingTtl)
    {
        var challenge = pairing.Start(pairingTtl);
        var summary = network.ReadSummary(scheme, port);
        var preferred = SelectPreferredEndpoint(summary);
        var payload = new Dictionary<string, object?>
        {
            ["type"] = "codex-mobile-bridge",
            ["version"] = 1,
            ["bridgeUrl"] = preferred.Url,
            ["pairingCode"] = challenge.Code,
            ["expiresAt"] = challenge.ExpiresAt,
        };
        var payloadJson = JsonSerializer.Serialize(payload, JsonOptions);
        var qrSvg = CreateQrSvg(payloadJson);

        return new ConnectPage(
            payloadJson,
            qrSvg,
            RenderHtml(preferred, summary, challenge, payloadJson, qrSvg),
            preferred.Url,
            challenge.Code,
            challenge.ExpiresAt);
    }

    public static BridgeNetworkEndpoint SelectPreferredEndpoint(BridgeNetworkSummary summary)
    {
        var endpoints = summary.Endpoints;
        return endpoints.FirstOrDefault(endpoint => endpoint.Scope == "private-lan")
            ?? endpoints.FirstOrDefault(endpoint => endpoint.Scope == "mesh-vpn")
            ?? endpoints.FirstOrDefault(endpoint => endpoint.Scope == "link-local")
            ?? endpoints.FirstOrDefault(endpoint => endpoint.Scope == "public")
            ?? endpoints.FirstOrDefault(endpoint => endpoint.Scope == "loopback")
            ?? endpoints.First();
    }

    private static string CreateQrSvg(string payloadJson)
    {
        using var generator = new QRCodeGenerator();
        using var data = generator.CreateQrCode(payloadJson, QRCodeGenerator.ECCLevel.Q);
        var svg = new SvgQRCode(data).GetGraphic(
            8,
            "#111827",
            "#ffffff",
            true,
            SvgQRCode.SizingMode.ViewBoxAttribute,
            null!);
        var svgStart = svg.IndexOf("<svg", StringComparison.OrdinalIgnoreCase);
        return svgStart > 0 ? svg[svgStart..] : svg;
    }

    private static string RenderHtml(
        BridgeNetworkEndpoint preferred,
        BridgeNetworkSummary summary,
        PairingChallenge challenge,
        string payloadJson,
        string qrSvg)
    {
        var endpoints = string.Join(
            Environment.NewLine,
            summary.Endpoints.Select(endpoint =>
                $"""
                <li>
                  <span>{HtmlEncoder.Default.Encode(endpoint.Scope)}</span>
                  <code>{HtmlEncoder.Default.Encode(endpoint.Url)}</code>
                </li>
                """));
        var warnings = string.Join(
            Environment.NewLine,
            summary.Warnings.Select(warning => $"<p class=\"warning\">{HtmlEncoder.Default.Encode(warning)}</p>"));

        var builder = new StringBuilder();
        builder.Append($$"""
            <!doctype html>
            <html lang="zh-CN">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width, initial-scale=1">
              <title>连接 Codex Mobile Bridge</title>
              <style>
                :root { color-scheme: light; }
                * { box-sizing: border-box; }
                body { margin:0; background:#fff; color:#111827; font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif; }
                main { min-height:100vh; display:grid; place-items:center; padding:28px; }
                .panel { width:min(960px,100%); border:1px solid #e5e7eb; border-radius:18px; padding:28px; box-shadow:0 24px 70px rgba(15,23,42,.08); }
                .grid { display:grid; grid-template-columns:minmax(240px,340px) 1fr; gap:28px; align-items:start; }
                .qr { border:1px solid #e5e7eb; border-radius:16px; padding:18px; display:grid; place-items:center; }
                .qr svg { width:100%; height:auto; max-width:280px; }
                h1 { margin:0 0 10px; font-size:clamp(26px,5vw,44px); line-height:1.05; letter-spacing:0; }
                p { color:#4b5563; line-height:1.65; }
                .code { font-size:42px; font-weight:750; letter-spacing:.08em; margin:12px 0; }
                code, textarea { font-family:"Cascadia Mono","SFMono-Regular",Consolas,monospace; }
                code { overflow-wrap:anywhere; }
                textarea { width:100%; min-height:96px; border:1px solid #d1d5db; border-radius:12px; padding:12px; color:#111827; background:#f9fafb; }
                ul { list-style:none; padding:0; margin:16px 0 0; display:grid; gap:10px; }
                li { border:1px solid #e5e7eb; border-radius:12px; padding:12px; display:grid; gap:4px; }
                li span { color:#6b7280; font-size:13px; }
                .warning { color:#92400e; background:#fffbeb; border:1px solid #fde68a; border-radius:12px; padding:10px 12px; }
                @media (max-width: 720px) { main { padding:14px; } .panel { padding:18px; border-radius:14px; } .grid { grid-template-columns:1fr; } }
              </style>
            </head>
            <body>
              <main>
                <section class="panel">
                  <div class="grid">
                    <div class="qr" aria-label="Codex Mobile Bridge QR">{{qrSvg}}</div>
                    <div>
                      <h1>连接 Codex Mobile Bridge</h1>
                      <p>在手机端点击“扫描 Bridge QR”，扫描这里的二维码即可连接 Windows Bridge。手机不要使用 127.0.0.1；二维码里已经写入当前推荐的真实地址。</p>
                      <div class="code">{{HtmlEncoder.Default.Encode(challenge.Code)}}</div>
                      <p>推荐地址：<code>{{HtmlEncoder.Default.Encode(preferred.Url)}}</code></p>
                      <p>过期时间：{{HtmlEncoder.Default.Encode(challenge.ExpiresAt.LocalDateTime.ToString("yyyy-MM-dd HH:mm:ss"))}}</p>
                      <textarea readonly>{{WebUtility.HtmlEncode(payloadJson)}}</textarea>
                      <h2>可用地址</h2>
                      <ul>{{endpoints}}</ul>
                      {{warnings}}
                    </div>
                  </div>
                </section>
              </main>
            </body>
            </html>
            """);
        return builder.ToString();
    }
}

public sealed record ConnectPage(
    string PayloadJson,
    string QrSvg,
    string Html,
    string BridgeUrl,
    string PairingCode,
    DateTimeOffset ExpiresAt);
