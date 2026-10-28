{
  nixpkgs,
  role ? "dev",
}:
let
  evaluated = import "${nixpkgs}/nixos/lib/eval-config.nix" {
    system = "aarch64-linux";
    modules =
      if role == "dev" then
        [
          ./apple.nix
          ./dev.nix
        ]
      else
        [ ./apple-target.nix ];
  };
  inherit (evaluated) pkgs;
  system = evaluated.config.system.build.toplevel;
  name = "nixos-${role}";
  image = pkgs.dockerTools.buildLayeredImageWithNixDb {
    inherit name;
    tag = "local";
    contents = [
      (pkgs.linkFarm "nixos-root" {
        "sbin/init" = "/nix/var/nix/profiles/system/init";
        "bin/sh" = evaluated.config.environment.binsh;
        "bin/bash" = "${pkgs.bashInteractive}/bin/bash";
        "usr/bin/bash" = "${pkgs.bashInteractive}/bin/bash";
        "nix/var/nix/profiles/system" = system;
      })
      pkgs.dockerTools.fakeNss
    ];
    extraCommands = ''
      mkdir -p etc/machine tmp run var home root
      touch etc/resolv.conf
      printf '127.0.0.1 localhost\n' > etc/hosts
      printf '#!/bin/sh\nexit 0\n' > etc/machine/create-user.sh
      chmod +x etc/machine/create-user.sh
      chmod 1777 tmp
    '';
    config = {
      Cmd = [ "${pkgs.bashInteractive}/bin/bash" ];
      Env = [ "PATH=/bin:/usr/bin:/run/current-system/sw/bin" ];
    };
  };
in
assert builtins.elem role [
  "dev"
  "target"
];
pkgs.runCommand "${name}.oci.tar" { nativeBuildInputs = [ pkgs.skopeo ]; } ''
  skopeo --tmpdir "$TMPDIR" --insecure-policy copy docker-archive:${image} oci-archive:$out:${name}:local
''
