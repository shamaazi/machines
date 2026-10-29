{ pkgs, ... }:
{
  imports = [ ./base.nix ];
  networking.hostName = "dev";
  environment.etc."machines-configured".text = "Configured by shamaazi/machines.\n";
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
