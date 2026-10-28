{ pkgs, ... }:
{
  system.stateVersion = "26.05";
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    sandbox = true;
    sandbox-fallback = false;
  };
  environment.systemPackages = [
    pkgs.curl
    pkgs.jq
  ];
}
