{
  description = "Generic NixOS machine foundations";
  outputs = _: {
    nixosModules = {
      base = ./nixos/base.nix;
      development = ./nixos/dev.nix;
      target = ./nixos/target.nix;
      apple = ./nixos/apple.nix;
      appleTarget = ./nixos/apple-target.nix;
    };
  };
}
