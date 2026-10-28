{ lib, ... }:
{
  imports = [ ./base.nix ];
  # Application deployment configuration can supply the actual machine name.
  networking.hostName = lib.mkDefault "deployment-target";
  # Remote NixOS activation needs root; access is exclusively by provisioned keys.
  services.openssh.settings.PermitRootLogin = "prohibit-password";
}
