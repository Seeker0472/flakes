{ pkgs }:
(import ./media.nix { inherit pkgs; })
++ (import ./office.nix { inherit pkgs; })
++ (with pkgs; [
  netease-cloud-music-gtk
  obsidian
  qq
  vscode
  zotero
])
