# Willow is the final exit of the proxy chain. It deliberately does not
# fetch airport subscriptions or run TUN/DNS hijacking: clients dial the
# Hysteria2 (UDP) or Shadowsocks 2022 (TCP) listener and traffic leaves DIRECT.
{ config, lib, ... }:
let
  willow = import ../../modules/profiles/programs/mihomo/willow.nix;
  ssPort = willow.ssPort;
  hy2Port = willow.hy2Port;
in
{
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      willow_ss_password.sopsFile = ./mihomo.secrets.yaml;
      willow_hy2_password.sopsFile = ./mihomo.secrets.yaml;
      willow_hy2_key.sopsFile = ./mihomo.secrets.yaml;
      willow_controller_secret.sopsFile = ./mihomo.secrets.yaml;
    };

    # The listener needs a readable PEM key path. Render it 0400 root and hand
    # it to mihomo through LoadCredential; the service runs as a DynamicUser.
    templates."willow-hy2-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "mihomo.service" ];
      content = config.sops.placeholder.willow_hy2_key;
    };

    templates."willow-mihomo.yaml" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "mihomo.service" ];
      content = ''
        mode: rule
        log-level: info
        ipv6: false
        external-controller: 127.0.0.1:9090
        secret: "${config.sops.placeholder.willow_controller_secret}"
        find-process-mode: off
        tcp-concurrent: true
        unified-delay: true

        dns:
          enable: true
          listen: 127.0.0.1:1053
          nameserver:
            - 8.8.8.8
            - 1.1.1.1
          fallback:
            - tls://8.8.4.4
            - tls://1.1.1.1

        listeners:
          - name: willow-exit
            type: shadowsocks
            listen: 0.0.0.0
            port: ${toString ssPort}
            cipher: 2022-blake3-aes-256-gcm
            password: "${config.sops.placeholder.willow_ss_password}"
            udp: true
            proxy: DIRECT

          - name: willow-exit-hy2
            type: hysteria2
            listen: 0.0.0.0
            port: ${toString hy2Port}
            users:
              willow: "${config.sops.placeholder.willow_hy2_password}"
            up: 1000
            down: 1000
            ignore-client-bandwidth: false
            alpn:
              - h3
            certificate: /run/credentials/mihomo.service/hy2.crt
            private-key: /run/credentials/mihomo.service/hy2.key
            proxy: DIRECT

        rules:
          - MATCH,DIRECT
      '';
    };
  };

  services.mihomo = {
    enable = true;
    configFile = config.sops.templates."willow-mihomo.yaml".path;
  };

  # mihomo only opens files below its home directory or SAFE_PATHS, so both
  # TLS files are delivered as credentials and that directory is allow-listed.
  systemd.services.mihomo.serviceConfig.LoadCredential = [
    "hy2.crt:${./hysteria2.crt}"
    "hy2.key:${config.sops.templates."willow-hy2-key".path}"
  ];
  systemd.services.mihomo.environment.SAFE_PATHS = "/run/credentials/mihomo.service";

  # UDP DIRECT needs netlink to discover the outbound route. The upstream
  # service sandbox allows only AF_INET and AF_INET6.
  systemd.services.mihomo.serviceConfig.RestrictAddressFamilies =
    lib.mkForce "AF_INET AF_INET6 AF_NETLINK";

  networking.firewall.allowedTCPPorts = [ ssPort ];
  networking.firewall.allowedUDPPorts = [
    ssPort
    hy2Port
  ];
}
