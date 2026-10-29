{ inputs, pkgs, ... }:
let
  linux = inputs.nixpkgs.legacyPackages.aarch64-linux;
  system =
    configuration:
    (linux.nixos [
      configuration
      "${inputs.lima}/lima.nix"
    ]).toplevel;
in
{
  outputs = {
    dev = system ./nixos/dev.nix;
    target = system ./nixos/base.nix;
  };
  tasks."machine:configure".exec = ''
    system=$(${pkgs.devenv}/bin/devenv build outputs.dev | ${pkgs.jq}/bin/jq -er '."outputs.dev"')
    sudo nix-env --profile /nix/var/nix/profiles/system --set "$system"
    sudo "$system/bin/switch-to-configuration" boot
  '';
  languages.nix.enable = true;
  git-hooks.hooks = {
    nixfmt.enable = true;
    statix.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;
  };
}
