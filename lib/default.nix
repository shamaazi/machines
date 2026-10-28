{ nixpkgs }:
let
  image =
    name: module:
    let
      system = import "${nixpkgs}/nixos/lib/eval-config.nix" {
        system = "aarch64-linux";
        modules = [
          module
          {
            # Apply Apple boot and packaging settings only to the image variant.
            image.modules.apple = {
              imports = [ ./image.nix ];
              image.baseName = "nixos-${name}";
            };
          }
        ];
      };
    in
    system.config.system.build.images.apple;
in
{
  dev = image "dev" ../nixos/dev.nix;
  target = image "target" ../nixos/base.nix;
}
