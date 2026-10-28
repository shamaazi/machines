{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Local Apple container machine only: the runtime owns kernel, network and disk.
  boot.isContainer = true;
  # Apple supplies the address and DNS file; a second DHCP/DNS manager conflicts.
  networking.useDHCP = false;
  networking.resolvconf.enable = false;
  services.openssh.ports = lib.mkDefault [ 2222 ];
  # Apple runs account setup before /etc exists. Bash (not sh mode) lets its
  # optional sources fail; the image's system profile supplies tools before /run.
  environment.binsh = lib.mkForce (
    pkgs.writeShellScript "apple-machine-shell" ''
      export PATH="/nix/var/nix/profiles/system/sw/bin:$PATH"
      exec ${pkgs.bashInteractive}/bin/bash "$@"
    ''
  );
  # Apple starts shells before /run/current-system is available.
  users.users.root.shell = "${pkgs.bashInteractive}/bin/bash";
  # Our policy: use guest-owned credentials instead of Apple's forwarded Mac agent.
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
  # NixOS's default activation remounts Apple's existing kernel filesystems.
  # Preserve them, but create missing mounts such as /run and report mount errors.
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
