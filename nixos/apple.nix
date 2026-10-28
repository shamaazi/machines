{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Local Apple container machine only: the runtime owns kernel, network and disk.
  boot.isContainer = true;
  networking = {
    useDHCP = false;
    resolvconf.enable = false;
    firewall.enable = false;
  };
  environment.binsh = lib.mkForce (
    pkgs.writeShellScript "apple-machine-shell" ''
      export PATH="''${PATH:+$PATH:}${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:${pkgs.glibc.getent}/bin:/run/current-system/sw/bin"
        exec ${pkgs.bashInteractive}/bin/sh "$@"
    ''
  );
  users.users.root.shell = "${pkgs.bashInteractive}/bin/bash";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
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
  system.activationScripts.specialfs = lib.mkForce ''
    specialMount() {
      local device="$1" mountPoint="$2" options="$3" fsType="$4"
      mountpoint -q "$mountPoint" && return 0
      mkdir -p "$mountPoint"
      mount -t "$fsType" -o "$options" "$device" "$mountPoint" 2>/dev/null || true
    }
    source ${config.system.build.earlyMountScript}
  '';
}
