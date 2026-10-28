{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Local Apple container machine only: the runtime owns kernel, network and disk.
  boot.isContainer = true;
  networking.useDHCP = false;
  networking.resolvconf.enable = false;
  # Apple runs account setup before /etc exists; Bash lets its optional sources fail.
  environment.binsh = lib.mkForce (
    pkgs.writeShellScript "apple-machine-shell" ''
      export PATH="/nix/var/nix/profiles/system/sw/bin:$PATH"
      exec ${pkgs.bashInteractive}/bin/bash "$@"
    ''
  );
  # Apple starts shells before /run/current-system is available.
  users.users.root.shell = "${pkgs.bashInteractive}/bin/bash";
  # Apple machine mode always mounts an agent socket. This server needs none.
  systemd.services.machine-isolation = {
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.util-linux ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      if mountpoint -q /var/host-services/ssh-auth.sock; then
        umount --lazy /var/host-services/ssh-auth.sock
      fi
    '';
  };
  # Keep Apple's mounts; NixOS still needs to create missing mounts such as /run.
  system.activationScripts.specialfs = lib.mkForce ''
    specialMount() {
      local device="$1" mountPoint="$2" options="$3" fsType="$4"
      mountpoint -q "$mountPoint" && return 0
      mkdir -p "$mountPoint"
      mount -t "$fsType" -o "$options" "$device" "$mountPoint"
    }
    source ${config.system.build.earlyMountScript}
  '';
}
