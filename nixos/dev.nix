{ lib, pkgs, ... }:
{
  imports = [ ./base.nix ];
  networking.hostName = lib.mkDefault "dev-build";
  users.users.developer = {
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
      "developer"
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
  ];
  services.openssh = {
    ports = [ 2223 ];
    settings.PermitRootLogin = "no";
  };
}
