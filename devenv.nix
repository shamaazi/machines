{ inputs, ... }:
let
  buildImage = import ./lib { inherit (inputs) nixpkgs; };
in
{
  # Keep both builds available in devenv; onboarding selects only the dev image.
  outputs = {
    dev = buildImage {
      name = "nixos-dev";
      configuration = ./nixos/dev.nix;
    };
    target = buildImage {
      name = "nixos-target";
      configuration = ./nixos/base.nix;
    };
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
