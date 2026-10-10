{ config, lib, ... }:
let
  secretsFile = ./ai.secrets.json;
  secret = key: {
    sopsFile = secretsFile;
    format = "json";
    inherit key;
  };
in
lib.mkIf config.programs.ai.enable {
  sops = {
    secrets = {
      "ai-codex-api-key" = secret "codex_api_key";
      "ai-grok-api-key" = secret "grok_api_key";
      "ai-kimi-api-key" = secret "kimi_api_key";
      "ai-deepseek-official-api-key" = secret "deepseek_official_api_key";
    };

    templates = {
      "codex-auth.json" = {
        mode = "0600";
        path = "${config.home.homeDirectory}/.codex/auth.json";
        content = builtins.toJSON {
          OPENAI_API_KEY = config.sops.placeholder."ai-codex-api-key";
        };
      };

      "ai-env" = {
        mode = "0400";
        content = ''
          OPENAI_API_KEY=${config.sops.placeholder."ai-codex-api-key"}
          XAI_API_KEY=${config.sops.placeholder."ai-grok-api-key"}
          KIMI_API_KEY=${config.sops.placeholder."ai-kimi-api-key"}
          DEEPSEEK_OFFICIAL_API_KEY=${config.sops.placeholder."ai-deepseek-official-api-key"}
        '';
      };
    };
  };

  home.sessionVariablesExtra = ''
    if [ -r "${config.sops.templates."ai-env".path}" ]; then
      set -a
      . "${config.sops.templates."ai-env".path}"
      set +a
    fi
  '';
}
