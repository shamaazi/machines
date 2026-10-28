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
  services.openssh = {
    enable = true;
    startWhenNeeded = false;
    settings = {
      AuthorizedKeysFile = "/etc/ssh/authorized_keys";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
