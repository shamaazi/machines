{ inputs, ... }:
let
  image =
    role:
    import ./nixos/image.nix {
      inherit role;
      inherit (inputs) nixpkgs;
    };
in
{
  outputs = {
    dev = image "dev";
    target = image "target";
  };
  languages.nix.enable = true;
  git-hooks.hooks = {
    nixfmt.enable = true;
    statix.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;
  };
}
