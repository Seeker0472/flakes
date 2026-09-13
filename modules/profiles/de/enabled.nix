# Shared predicate: is machine.de.hyprland.enable set in the NixOS (osConfig) config?
lib: osConfig:
lib.attrByPath [
  "machine"
  "de"
  "hyprland"
  "enable"
] false osConfig
