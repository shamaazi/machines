{ ... }:
{
  imports = [
    ./apple.nix
    ./roles/target.nix
  ];
  services.openssh.ports = [ 2222 ];
}
