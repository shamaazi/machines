{ pkgs, ... }:
{
  imports = [ ./base.nix ];
  networking.hostName = "shamaazi";
  # Keep image builds and remote rebuilds on the upstream Lima GRUB bootloader.
  boot.loader.systemd-boot.enable = false;
  nix.settings = {
    max-jobs = 4;
    cores = 2;
  };
  environment.systemPackages = with pkgs; [
    git
    gh
    devenv
    openssh
    ripgrep
    bubblewrap
  ];
  services.openssh = {
    settings.PermitRootLogin = "no";
  };
}
