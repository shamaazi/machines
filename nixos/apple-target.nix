{
  imports = [
    ./apple.nix
    ./target.nix
  ];
  # Match the local target transport without changing the generic target's port.
  services.openssh.ports = [ 2222 ];
}
