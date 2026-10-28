{
  role ? "target",
  username ? "developer",
}:
let
  lock = builtins.fromJSON (builtins.readFile ../devenv.lock);
  source = builtins.getFlake "github:NixOS/nixpkgs/${lock.nodes.nixpkgs.locked.rev}";
in
assert builtins.elem role [
  "dev"
  "target"
];
import "${source}/nixos/lib/eval-config.nix" {
  system = "aarch64-linux";
  modules =
    if role == "dev" then
      [
        ./apple.nix
        ./roles/development.nix
        { machine.user = username; }
      ]
    else
      [ ./apple-target.nix ];
}
