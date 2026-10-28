{ lib, ... }:
{
  imports = [ ../modules/apple.nix ];
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
    startWhenNeeded = false;
    settings = {
      # Base targets need root for activation; dev.nix uses its sudo-enabled user.
      PermitRootLogin = lib.mkDefault "prohibit-password";
      # Bootstrap owns this public-key file. /var/lib/machines is reserved by
      # systemd-machined, which makes it unreadable to the dev user on activation.
      AuthorizedKeysFile = "/etc/ssh/authorized_keys";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
