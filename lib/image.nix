{ pkgs }:
{ name, configuration }:
let
  imageModule =
    {
      config,
      pkgs,
      modulesPath,
      ...
    }:
    let
      imageName = config.image.baseName;
      root = pkgs.linkFarm "nixos-root" {
        # Follow the profile so reboots preserve deployments and rollbacks.
        "sbin/init" = "/nix/var/nix/profiles/system/init";
        # Provide a shell before NixOS activates /etc.
        "bin/sh" = config.environment.binsh;
        # Number the base generation so the first deployment can roll back to it.
        "nix/var/nix/profiles/system" = "system-1-link";
        "nix/var/nix/profiles/system-1-link" = config.system.build.toplevel;
      };
      image = pkgs.dockerTools.buildLayeredImageWithNixDb {
        name = imageName;
        tag = "local";
        contents = [
          root
          # Supply initial account lookup files until NixOS declares the real users.
          pkgs.dockerTools.fakeNss
        ];
      };
    in
    {
      imports = [
        "${modulesPath}/image/file-options.nix"
      ];
      image.baseName = name;
      image.extension = "oci.tar";
      # Apple's importer requires OCI; DockerTools emits a Docker archive.
      # The source is our local derivation, so Skopeo needs no registry signing policy.
      system.build.image =
        pkgs.runCommand config.image.fileName { nativeBuildInputs = [ pkgs.skopeo ]; }
          ''
            mkdir -p "$out"
            skopeo --tmpdir "$TMPDIR" --insecure-policy copy docker-archive:${image} oci-archive:$out/${config.image.fileName}:${imageName}:local
          '';
    };
in
(pkgs.nixos [
  configuration
  { image.modules.container = imageModule; }
]).images.container
