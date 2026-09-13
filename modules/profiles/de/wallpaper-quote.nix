# Shared hitokoto wallpaper/quote helper used by both niri and Hyprland binds.
# Usage: wallpaper-quote [default|anime|alternate|none]
{ pkgs }:
pkgs.writeShellApplication {
  name = "wallpaper-quote";
  runtimeInputs = [
    pkgs.curl
    pkgs.jq
    pkgs.libnotify
    pkgs.wpaperd
  ];
  text = ''
    case "''${1:-default}" in
      default) url="https://hitokoto.mayx.eu.org/" ;;
      anime) url="https://hitokoto.mayx.eu.org/?c=a" ;;
      alternate) url="https://v1.hitokoto.mangofanfan.cn/?c=a" ;;
      none) url="" ;;
      *) echo "unknown quote source: $1" >&2; exit 2 ;;
    esac

    wpaperctl next-wallpaper
    if [[ -n "$url" ]]; then
      response="$(curl -fsSk "$url" || true)"
      message="$(jq -r 'if type == "object" and .hitokoto then .hitokoto + "\n-- " + (.from // "unknown") else empty end' <<< "$response" 2>/dev/null || true)"
      if [[ -n "$message" ]]; then
        notify-send --category=hitokoto -t 6000 "$message"
      fi
    fi
  '';
}
