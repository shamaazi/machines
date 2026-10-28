{
  description = "Generic NixOS machine foundations";
  outputs = _: {
    nixosModules = {
      base = ./nixos/base.nix;
      development = ./nixos/roles/development.nix;
      target = ./nixos/roles/target.nix;
      apple = ./nixos/apple.nix;
      appleTarget = ./nixos/apple-target.nix;
    };
  };
}
