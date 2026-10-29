{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/b6c8664de9b6cc07fe5666a29f91884ba81197c4";
    lima = {
      url = "github:nixos-lima/nixos-lima/e0e086f24b6b8b3d062ca3a1dce1655eb681c237";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      lima,
      ...
    }:
    {
      nixosConfigurations = {
        dev = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            "${lima}/lima.nix"
            ./nixos/dev.nix
          ];
        };
        target = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            "${lima}/lima.nix"
            ./nixos/base.nix
          ];
        };
      };
      packages.aarch64-linux.image = self.nixosConfigurations.dev.config.system.build.images.qemu-efi;
    };
}
