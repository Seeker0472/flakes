# Shared Willow relay data. Both the NixOS mihomo module and the Clash Verge
# package render from this file, so the server, port, cipher, UDP setting and
# OpenAI/Codex rules have a single source.
let
  name = "Willow";
in
{
  inherit name;

  server = "8.229.8.238";
  port = 28443;
  cipher = "2022-blake3-aes-256-gcm";
  udp = true;

  # The proxy name is the only variable: the NixOS config uses "Willow" as the
  # proxy, and the Clash Verge profiles use the same name.
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
