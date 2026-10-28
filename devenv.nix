{
  config,
  lib,
  pkgs,
  ...
}:
{
  languages.nix.enable = true;
  packages = with pkgs; [
    git
    gh
    devenv
    jq
    openssh
    nixfmt
  ];
  env.MACHINES_HOME = lib.mkDefault "${config.git.root}/.devenv/machines";
  git-hooks.hooks = {
    nixfmt.enable = true;
    statix.enable = true;
    deadnix.enable = true;
    shellcheck.enable = true;

  };
  tasks = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.mapAttrs
      (name: description: {
        inherit description;
        exec = "bash ${config.git.root}/devenv/apple.sh ${lib.replaceStrings [ ":" ] [ " " ] name}";
      })
      {
        "machine:setup" = "Install and start the private Apple Container runtime";
        "dev:build" = "Build the generic ARM64 NixOS development image";
        "dev:up" = "Create or resume the persistent development machine";
        "dev:status" = "Inspect the development machine";
        "dev:stop" = "Stop the development machine, preserving its disk";
        "dev:forward" = "Forward a configured development port over SSH";
        "target:build" = "Build the generic ARM64 NixOS target image";
        "target:up" = "Create or resume a deployment target";
        "target:pair" = "Authorize a dev-machine deployment key on the target";
        "target:status" = "Inspect the deployment target";
        "target:stop" = "Stop the deployment target, preserving its disk";
        "target:forward" = "Forward a configured target port over SSH";
      }
  );
}
