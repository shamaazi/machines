{
  config,
  pkgs,
  modulesPath,
  ...
}:
let
  system = config.system.build.toplevel;
  name = config.image.baseName;
  image = pkgs.dockerTools.buildLayeredImageWithNixDb {
    inherit name;
    tag = "local";
    contents = [
      (pkgs.linkFarm "nixos-root" {
        "sbin/init" = "/nix/var/nix/profiles/system/init";
        "bin/sh" = config.environment.binsh;
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
{
  imports = [
    "${modulesPath}/image/file-options.nix"
    ./apple.nix
  ];
  image.extension = "oci.tar";
  system.build.image =
    pkgs.runCommand config.image.fileName { nativeBuildInputs = [ pkgs.skopeo ]; }
      ''
        mkdir -p "$out"
        skopeo --tmpdir "$TMPDIR" --insecure-policy copy docker-archive:${image} oci-archive:$out/${config.image.fileName}:${name}:local
      '';
}
