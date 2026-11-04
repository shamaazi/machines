{pkgs, ...}: {
  imports = [
    ./base.nix
    ./modules/gclpr.nix
  ];
  networking.hostName = "shamaazi";
  # Keep image builds and remote rebuilds on the upstream Lima GRUB bootloader.
  boot.loader.systemd-boot.enable = false;
  nix.settings = {
    max-jobs = 4;
    cores = 2;
  };
  environment.systemPackages = with pkgs; [
    bubblewrap
    devenv
    git
    gh
    openssh
    ripgrep
  ];

  programs.nix-ld.enable = true;

  services.gclpr.enable = true;
  services.openssh = {
    settings.PermitRootLogin = "no";
  };
}
