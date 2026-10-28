{
  config,
  pkgs,
  modulesPath,
  ...
}:
let
  system = config.system.build.toplevel;
  name = config.image.baseName;
  # Register the closure in the image's Nix database so builds and copies work.
  image = pkgs.dockerTools.buildLayeredImageWithNixDb {
    inherit name;
    tag = "local";
    contents = [
      (pkgs.linkFarm "nixos-root" {
        # Apple boots /sbin/init; follow the selected generation after deployment.
        "sbin/init" = "/nix/var/nix/profiles/system/init";
        # Apple's provisioning shell must exist before NixOS activates /etc.
        "bin/sh" = config.environment.binsh;
        # Number the base generation so the first deployment can roll back to it.
        "nix/var/nix/profiles/system" = "system-1-link";
        "nix/var/nix/profiles/system-1-link" = system;
      })
      # Supply initial account lookup files until NixOS declares the real users.
      pkgs.dockerTools.fakeNss
    ];
  };
in
{
  imports = [
    # Use NixOS's standard filename metadata for the custom image variant.
    "${modulesPath}/image/file-options.nix"
    ./apple.nix
  ];
  image.extension = "oci.tar";
  # DockerTools emits a Docker archive; Apple's importer expects an OCI archive.
  # The source is our local derivation, so Skopeo needs no registry signing policy.
  system.build.image =
    pkgs.runCommand config.image.fileName { nativeBuildInputs = [ pkgs.skopeo ]; }
      ''
        mkdir -p "$out"
        skopeo --tmpdir "$TMPDIR" --insecure-policy copy docker-archive:${image} oci-archive:$out/${config.image.fileName}:${name}:local
      '';
}
