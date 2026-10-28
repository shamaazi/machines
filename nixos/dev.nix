{ pkgs, ... }:
{
  imports = [ ./base.nix ];
  networking.hostName = "dev-build";
  users.users.developer = {
    isNormalUser = true;
    # Match bootstrap's fixed guest identity, independent of the Mac user's UID.
    uid = 1000;
    group = "users";
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
  };
  security.sudo.wheelNeedsPassword = false;
  nix.settings = {
    # Deployment commands run as developer and need trusted Nix-store operations.
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
