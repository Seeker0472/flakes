_: {
  nixpkgs.config.allowUnfree = true;
  # FIXME: Remove once Zotero no longer uses Firefox ESR 140 (EOL 2026-10-13).
  nixpkgs.config.permittedInsecurePackages = [
    "firefox-esr-140-bin-unwrapped-140.17.0esr"
  ];
}
