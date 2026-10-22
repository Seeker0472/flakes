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
  agents = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  options.programs.ai = {
    enable = lib.mkEnableOption "Codex and OMP";

    omp.enable = lib.mkEnableOption "the Oh My Pi (OMP) model registry";

    claudeCodeBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://allrouter.cc/v1";
      description = "OpenAI-compatible rustcat relay used only by the OMP Claude Code provider.";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = agents ? codex;
          message = ''
            llm-agents.nix is missing the Codex package on ${pkgs.stdenv.hostPlatform.system}.
          '';
        }
      ];

      home.packages = [ agents.codex ];
    })
    (lib.mkIf (cfg.enable && cfg.omp.enable) {
      assertions = [
        {
          assertion = agents ? omp;
          message = ''
            llm-agents.nix is missing the Oh My Pi package on ${pkgs.stdenv.hostPlatform.system}.
            Need: omp
          '';
        }
      ];

      home.packages = [ agents.omp ];

      # OMP keeps provider names explicit.  Only the Claude Code rustcat
      # provider remains; Codex itself uses the official OpenAI endpoint.
      home.file.".omp/agent/models.yml".text = ''
        providers:
          deepseek-official:
            baseUrl: https://api.deepseek.com/v1
            apiKey: DEEPSEEK_OFFICIAL_API_KEY
            api: openai-completions
            discovery:
              type: openai-models-list

          claude-code:
            baseUrl: ${cfg.claudeCodeBaseUrl}
            apiKey: CLAUDE_CODE_API_KEY
            discovery:
              type: proxy
      '';
    })
    (lib.optionalAttrs ((options ? home.persistence) && persistDir != null) {
      home.persistence.${persistDir}.directories = lib.mkIf (cfg.enable && impermanenceEnabled) [
        {
          directory = ".codex";
          mode = "0700";
        }
        {
          directory = ".omp";
          mode = "0700";
        }
      ];
    })
  ];
}
