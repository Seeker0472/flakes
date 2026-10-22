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
      "ai-claude-code-api-key" = secret "claude_code_api_key";
      "ai-deepseek-official-api-key" = secret "deepseek_official_api_key";
    };

    templates."ai-env" = {
      mode = "0400";
      content = ''
        CLAUDE_CODE_API_KEY=${config.sops.placeholder."ai-claude-code-api-key"}
        DEEPSEEK_OFFICIAL_API_KEY=${config.sops.placeholder."ai-deepseek-official-api-key"}
      '';
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
