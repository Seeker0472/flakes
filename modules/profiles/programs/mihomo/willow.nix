# Shared Willow relay data. Both the NixOS mihomo module and the Clash Verge
# package render from this file, so the endpoints, smux settings, certificate
# fingerprint and OpenAI/Codex rules have a single source.
let
  # Fallback-group name; openaiRules targets this group, not a single proxy.
  name = "Willow";
in
{
  inherit name;

  server = "8.229.8.238";

  # Primary transport: Hysteria2 over UDP. QUIC multiplexes every browser
  # connection over one session, so a page load no longer pays a fresh
  # airport-to-Willow handshake per request.
  hy2Name = "WillowHY2";
  hy2Port = 28444;
  hy2Sni = "willow";
  # Hysteria2 Brutal bandwidth hints. Both peers need them: with the listener
  # ignoring client bandwidth (or the client omitting up/down) the handshake
  # fails, as tested against mihomo 1.19.x.
  hy2Up = "1000 Mbps";
  hy2Down = "1000 Mbps";
  # SHA256 of hosts/Willow/hysteria2.crt. Pinning avoids skip-cert-verify;
  # rotate the certificate and this value together.
  hy2Fingerprint = "8A:D8:AC:44:13:5A:74:26:FF:19:9B:F6:B3:BE:87:37:01:B1:D7:89:8D:FE:83:13:DB:77:C5:76:BF:1C:B5:3A";

  # Fallback transport: Shadowsocks 2022 over TCP. sing-mux collapses many
  # short browser connections into a few outer connections; UDP stays
  # unmuxed so QUIC keeps using the native SS UDP relay.
  ssName = "WillowSS";
  ssPort = 28443;
  ssCipher = "2022-blake3-aes-256-gcm";
  ssUdp = true;
  ssSmux = {
    enabled = true;
    protocol = "h2mux";
    maxConnections = 4;
    padding = true;
    onlyTcp = true;
  };

  openaiRules = proxyName: [
    "DOMAIN,dns.google,${proxyName}"
    "DOMAIN-SUFFIX,openai.com,${proxyName}"
    "DOMAIN-SUFFIX,chatgpt.com,${proxyName}"
    "DOMAIN-SUFFIX,oaistatic.com,${proxyName}"
    "DOMAIN-SUFFIX,oaiusercontent.com,${proxyName}"
    "DOMAIN-SUFFIX,oaistatsig.com,${proxyName}"
    "DOMAIN-SUFFIX,intercom.io,${proxyName}"
    "DOMAIN-SUFFIX,intercomcdn.com,${proxyName}"
    "DOMAIN,cdn.workos.com,${proxyName}"
    "DOMAIN,forwarder.workos.com,${proxyName}"
    "DOMAIN,frontend-apps-multi-region.workos.com,${proxyName}"
    "DOMAIN,setup.workos.com,${proxyName}"
    "DOMAIN,images.workoscdn.com,${proxyName}"
    "DOMAIN,workos.imgix.net,${proxyName}"
    "DOMAIN,js.stripe.com,${proxyName}"
    "DOMAIN-SUFFIX,ct.sendgrid.net,${proxyName}"
    "DOMAIN,challenges.cloudflare.com,${proxyName}"
    "DOMAIN,humb.apple.com,${proxyName}"
    "DOMAIN,o207216.ingest.sentry.io,${proxyName}"
    "DOMAIN,o33249.ingest.sentry.io,${proxyName}"
    "DOMAIN,rum.browser-intake-datadoghq.com,${proxyName}"
    "DOMAIN,cdn.openaimerge.com,${proxyName}"
  ];
}
