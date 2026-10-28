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
  registration = pkgs.closureInfo { rootPaths = [ system ]; };
  name = "nixos-${role}";
  image = pkgs.dockerTools.buildLayeredImage {
    inherit name;
    tag = "local";
    extraCommands = ''
      mkdir -p sbin bin usr/bin etc/machine tmp run var home root
      ln -s /nix/var/nix/profiles/system/init sbin/init
      ln -s ${evaluated.config.environment.binsh} bin/sh
      ln -s ${pkgs.bashInteractive}/bin/bash bin/bash
      ln -s ${pkgs.bashInteractive}/bin/bash usr/bin/bash
      touch etc/resolv.conf
      printf '127.0.0.1 localhost\n' > etc/hosts
      printf 'root:x:0:0:root:/root:${pkgs.bashInteractive}/bin/bash\n' > etc/passwd
      printf 'root:x:0:\n' > etc/group
      printf '#!/bin/sh\nexit 0\n' > etc/machine/create-user.sh
      chmod +x etc/machine/create-user.sh
      chmod 1777 tmp
      export NIX_REMOTE="local?root=$PWD" USER=root
      ${pkgs.nix}/bin/nix-store --load-db < ${registration}/registration
      mkdir -p nix/var/nix/profiles
      ln -s ${system} nix/var/nix/profiles/system-1-link
      ln -s system-1-link nix/var/nix/profiles/system
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
