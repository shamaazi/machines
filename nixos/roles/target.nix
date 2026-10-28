{ lib, ... }:
{
  imports = [ ../base.nix ];
  networking.hostName = lib.mkDefault "deployment-target";
  services.openssh = {
    enable = true;
    startWhenNeeded = false;
    ports = lib.mkDefault [ 22 ];
    settings = {
      AuthorizedKeysFile = "/var/lib/machines/authorized_keys";
      PermitRootLogin = "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
