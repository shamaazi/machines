{ nixpkgs }:
{ name, configuration }:
let
  system = import "${nixpkgs}/nixos/lib/eval-config.nix" {
    system = "aarch64-linux";
    modules = [
      configuration
      {
        # Register container packaging separately from the host's configuration.
        image.modules.container = {
          imports = [ ./image.nix ];
          image.baseName = name;
        };
      }
    ];
  };
in
system.config.system.build.images.container
