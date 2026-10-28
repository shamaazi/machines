{ lib, pkgs, ... }:
{
  imports = [ ./base.nix ];
  # Give fresh guests a role name while allowing a caller to override it.
  networking.hostName = lib.mkDefault "dev-build";
  users.users.developer = {
    isNormalUser = true;
    # Match bootstrap's fixed guest identity, independent of the Mac user's UID.
    uid = 1000;
    group = "users";
    extraGroups = [ "wheel" ];
    shell = pkgs.bashInteractive;
  };
  # The developer administers this private VM through SSH keys, without a password.
  security.sudo.wheelNeedsPassword = false;
  nix.settings = {
    # Let the VM administrator perform remote-store and builder operations.
    trusted-users = [
      "root"
      "developer"
    ];
    # Bound concurrent builds on the default eight-CPU VM to leave room for services.
    max-jobs = 4;
    cores = 2;
  };
  # Include the tools needed to authenticate, clone a project and enter its devenv.
  environment.systemPackages = with pkgs; [
    git
    gh
    devenv
    openssh
    ripgrep
  ];
  services.openssh = {
    # Match the dev transport in bootstrap; administration uses sudo as developer.
    ports = [ 2223 ];
    settings.PermitRootLogin = "no";
  };
}
