{ pkgs }:
{ name, configuration }:
(pkgs.nixos [
  configuration
  {
    # Register container packaging separately from the host's configuration.
    image.modules.container = {
      imports = [ ./image.nix ];
      image.baseName = name;
    };
  }
]).images.container
