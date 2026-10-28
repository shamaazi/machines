{ inputs, ... }:
let
  image =
    role:
    let
      system = import "${inputs.nixpkgs}/nixos/lib/eval-config.nix" {
        system = "aarch64-linux";
        modules = [
          (./nixos + "/${role}.nix")
          {
            # Register Apple's boot environment only on the image variant.
            image.modules.apple = {
              imports = [
                ./nixos/image.nix
              ]
              ++ inputs.nixpkgs.lib.optional (role == "target") ./nixos/apple-target.nix;
              image.baseName = "nixos-${role}";
            };
          }
        ];
      };
    in
    system.config.system.build.images.apple;
in
{
  # Keep both builds available in devenv; onboarding selects only the dev image.
  outputs = {
    dev = image "dev";
    target = image "target";
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
