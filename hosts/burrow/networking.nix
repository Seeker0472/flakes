# The home LAN CIDR and mihomo ports are duplicated with
# meta.nix (machine.programs.mihomo.share.allowedCIDRs / module defaults);
# keep them in one place here since the mihomo module lives outside hosts/.
# If the mihomo module grows an openFirewall-based rule, switch to that.
let
  homeLanCidr = "192.168.3.0/24";
  mihomoTcpPorts = "{ 7890, 7891 }";
  mihomoUdpPort = 7891;
in
{
  networking = {
    nftables.enable = true;
    networkmanager.wifi.powersave = false;
    firewall.extraInputRules = ''
      ip saddr ${homeLanCidr} tcp dport ${mihomoTcpPorts} accept comment "Mihomo from home LAN"
      ip saddr ${homeLanCidr} udp dport ${toString mihomoUdpPort} accept comment "Mihomo SOCKS UDP from home LAN"
    '';
  };
}
