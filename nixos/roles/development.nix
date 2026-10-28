{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ../base.nix ];
  options.machine.user = lib.mkOption {
    type = lib.types.str;
    default = "developer";
    description = "Owner of the development workspace.";
  };
  config = {
    networking.hostName = lib.mkDefault "dev-build";
    users.users.${config.machine.user} = {
      isNormalUser = true;
      uid = 1000;
      group = "users";
      extraGroups = [ "wheel" ];
      shell = pkgs.bashInteractive;
    };
    security.sudo.wheelNeedsPassword = false;
    nix.settings = {
      trusted-users = [
        "root"
        config.machine.user
      ];
      max-jobs = 4;
      cores = 2;
    };
    environment.systemPackages = with pkgs; [
      git
      gh
      devenv
      openssh
      ripgrep
      procps
      util-linux
    ];
    services.openssh = {
      enable = true;
      startWhenNeeded = false;
      ports = [ 2223 ];
      settings = {
        AuthorizedKeysFile = "/var/lib/machines/authorized_keys";
        PermitRootLogin = "no";
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };
}
