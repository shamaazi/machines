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
        "nix/var/nix/profiles/system" = "system-1-link";
        "nix/var/nix/profiles/system-1-link" = system;
      })
      pkgs.dockerTools.fakeNss
    ];
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
