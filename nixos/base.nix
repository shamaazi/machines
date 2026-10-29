{ lib, ... }:
{
  networking.hostName = lib.mkDefault "deployment-target";
  # Do not bump this with Nixpkgs; it controls persistent-state defaults.
  system.stateVersion = "26.05";
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    sandbox = true;
    sandbox-fallback = false;
  };
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = lib.mkDefault "prohibit-password";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
