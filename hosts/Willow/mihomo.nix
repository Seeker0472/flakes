# Willow is the final exit of the proxy chain. It deliberately does not
# fetch airport subscriptions or run TUN/DNS hijacking: clients dial this
# Shadowsocks 2022 listener (directly or through an airport node with
# mihomo's dialer-proxy) and the traffic leaves DIRECT.
{ config, ... }:
let
  ssPort = 28443;
in
{
  sops = {
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      willow_ss_password.sopsFile = ./mihomo.secrets.yaml;
      willow_controller_secret.sopsFile = ./mihomo.secrets.yaml;
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
            udp: false
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

  networking.firewall.allowedTCPPorts = [ ssPort ];
}
