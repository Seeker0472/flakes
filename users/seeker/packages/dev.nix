{ pkgs }:
with pkgs;
[
  nodejs_22
  cargo
  nixd
  coursier
  jdt-language-server
  ocamlPackages.junit
  ddcutil
  ranger
  gcc
  gdb
  gnumake
  lazygit
  clang-tools
  nixfmt
]
