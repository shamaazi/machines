{
  languages.nix.enable = true;
  git-hooks.hooks = {
    nixfmt.enable = true;
    statix.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;
  };
}
