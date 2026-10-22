{
  config,
  ...
}:
let
  secretsFile = ./smtp.secrets.yaml;
in
{
  # QQ 邮箱 SMTP 授权码（不是登录密码）。加密文件由 sops 管理，
  # 填入方式:  sops users/seeker/smtp.secrets.yaml
  # 收件人列表见 .sops.yaml（users/seeker/smtp.secrets.yaml 那条规则）。
  sops.secrets."smtp-qq-auth-code" = {
    sopsFile = secretsFile;
    format = "yaml";
    key = "smtp_qq_auth_code";
  };

  # git 的凭据只能在运行时出现（nix store 里不能有明文），所以用
  # sops.templates 在 activation 时把 placeholder 渲染成 0400 的文件，
  # 再由 programs.git 生成的配置用 include.path 引入 [sendemail] 段。
  sops.templates."git-sendemail-credentials" = {
    mode = "0400";
    path = "${config.home.homeDirectory}/.config/git/sendemail-credentials";
    content = ''
      [sendemail]
      	smtpUser = gmx472@qq.com
      	smtpPass = ${config.sops.placeholder."smtp-qq-auth-code"}
    '';
  };

  # 内核补丁走 git send-email: QQ 的 SMTP 直连（465/SSL）。
  # from 用真名（DCO 要求），与补丁里的 Signed-off-by 一致。
  programs.git.settings = {
    include.path = "${config.home.homeDirectory}/.config/git/sendemail-credentials";
    sendemail = {
      smtpServer = "smtp.qq.com";
      smtpServerPort = 465;
      smtpEncryption = "ssl";
      smtpAuth = "LOGIN";
      from = "Mingxuan Guo <gmx472@qq.com>";
      confirm = "always";
    };
  };
}
