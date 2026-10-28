{ lib, ... }:
{
  imports = [ ./base.nix ];
  networking.hostName = lib.mkDefault "deployment-target";
  services.openssh.settings.PermitRootLogin = "prohibit-password";
}
