{
  config,
  lib,
  pkgs,
  inputs,
  osConfig ? { },
  options,
  ...
}:
let
  cfg = config.programs.ai;
  persistDir = lib.attrByPath [ "machine" "btrfs" "impermanence" "persistdir" ] null osConfig;
  impermanenceEnabled = lib.attrByPath [ "machine" "impermanence" "enable" ] false osConfig;
  grokModelsBaseUrl = "${cfg.relayUrl}/v1";
  sessionUrls = {
    GROK_MODELS_BASE_URL = grokModelsBaseUrl;
    GROK_DISABLE_AUTOUPDATER = "1";
    # Codex's built-in OpenAI provider talks to the origin without /v1.
    OPENAI_BASE_URL = cfg.relayUrl;
    # kimi-code provider endpoint; ~/.kimi-code/config.toml is local runtime state.
    KIMI_BASE_URL = grokModelsBaseUrl;
  };
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.programs.ai = {
    enable = lib.mkEnableOption "Codex, Grok, and Kimi coding agents";

    relayUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://rust.cat";
      description = ''
        Shared OpenAI-compatible relay origin without a `/v1` suffix.
        Grok and Kimi use `{relayUrl}/v1`; Codex uses `{relayUrl}`.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = agents ? codex && agents ? grok && agents ? kimi-code;
          message = ''
            llm-agents.nix is missing required AI packages on ${pkgs.stdenv.hostPlatform.system}.
            Need: codex, grok, kimi-code (kimi-cli is shipped as kimi-code).
          '';
        }
      ];

      home = {
        # llm-agents.nix does not package kimi-cli; Moonshot ships it as kimi-code (`kimi`).
        packages = [
          agents.codex
          agents.grok
          agents.kimi-code
        ];
        sessionVariables = sessionUrls;
      };
    })
    (lib.optionalAttrs (options ? systemd.user.sessionVariables) {
      systemd.user.sessionVariables = lib.mkIf cfg.enable sessionUrls;
    })
    (lib.optionalAttrs ((options ? home.persistence) && persistDir != null) {
      home.persistence.${persistDir}.directories = lib.mkIf (cfg.enable && impermanenceEnabled) [
        {
          directory = ".codex";
          mode = "0700";
        }
        {
          directory = ".grok";
          mode = "0700";
        }
        {
          directory = ".kimi";
          mode = "0700";
        }
        {
          directory = ".kimi-code";
          mode = "0700";
        }
      ];
    })
  ];
}
