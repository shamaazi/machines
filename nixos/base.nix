{ lib, ... }:
{
  imports = [ ../modules/apple.nix ];
  # Applications can supply their server name; dev.nix names development guests.
  networking.hostName = lib.mkDefault "deployment-target";
  # Preserve NixOS state-format defaults across package updates.
  system.stateVersion = "26.05";
  nix.settings = {
    # Devenv uses the modern Nix CLI and flake inputs.
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    # Keep source builds isolated; fail rather than silently build unsandboxed.
    sandbox = true;
    sandbox-fallback = false;
  };
  services.openssh = {
    enable = true;
    # Keep SSH ready for bootstrap health checks and remote NixOS activation.
    startWhenNeeded = false;
    settings = {
      # Base targets need root for activation; dev.nix uses its sudo-enabled user.
      PermitRootLogin = lib.mkDefault "prohibit-password";
      # Bootstrap owns this public-key file. /var/lib/machines is reserved by
      # systemd-machined, which makes it unreadable to the dev user on activation.
      AuthorizedKeysFile = "/etc/ssh/authorized_keys";
      # Bootstrap provisions keys locally; images contain no login passwords.
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
