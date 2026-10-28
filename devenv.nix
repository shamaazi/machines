{ inputs, ... }:
{
  # Keep both builds available in devenv; onboarding selects only the dev image.
  outputs = import ./lib {
    inherit (inputs) nixpkgs;
  };
  # Validate provisioning's Nix and shell sources with the native devenv hooks.
  languages.nix.enable = true;
  git-hooks.hooks = {
    nixfmt.enable = true;
    statix.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;
  };
}
