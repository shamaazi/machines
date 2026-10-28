{ inputs, ... }:
let
  buildImage = import ./lib/image.nix {
    # Evaluate the hosts with Linux packages even when devenv runs on macOS.
    pkgs = inputs.nixpkgs.legacyPackages.aarch64-linux;
  };
in
{
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
  languages.nix.enable = true;
  git-hooks.hooks = {
    nixfmt.enable = true;
    statix.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;
  };
}
