{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.gclpr;

  gclpr = pkgs.stdenvNoCC.mkDerivation {
    pname = "gclpr";
    version = "2.3.1";
    src = pkgs.fetchzip {
      url = "https://github.com/rupor-github/gclpr/releases/download/v2.3.1/gclpr_linux_arm64.zip";
      hash = "sha256-vDsThGcvB4vDKjIr/ijPl9YUujYw8EbtRZPzraPav5g=";
      stripRoot = false;
    };
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src/gclpr" "$out/bin/gclpr"
      runHook postInstall
    '';
    meta = {
      description = "Signed localhost clipboard and browser-open bridge";
      homepage = "https://github.com/rupor-github/gclpr";
      license = lib.licenses.mit;
      platforms = [ "aarch64-linux" ];
      mainProgram = "gclpr";
    };
  };

  xclip = pkgs.writeShellApplication {
    name = "xclip";
    runtimeInputs = [ gclpr ];
    text = ''
      mode='copy'
      for argument in "$@"; do
        case "$argument" in
          -o|-out|-output) mode='paste' ;;
        esac
      done
      exec gclpr "$mode"
    '';
  };

  clientPackage = pkgs.runCommand "machines-gclpr" { } ''
    mkdir -p "$out/bin"
    ln -s ${gclpr}/bin/gclpr "$out/bin/gclpr"
    ln -s ${gclpr}/bin/gclpr "$out/bin/xdg-open"
    ln -s ${xclip}/bin/xclip "$out/bin/xclip"
  '';
in
{
  options.services.gclpr = {
    enable = lib.mkEnableOption "macOS clipboard and browser integration through gclpr";

    host = lib.mkOption {
      type = lib.types.str;
      default = "host.lima.internal";
      description = "Host running the gclpr server.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 2850;
      description = "TCP port used by the gclpr server.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ clientPackage ];
    environment.variables = {
      BROWSER = "xdg-open";
      GH_BROWSER = "xdg-open";
    };

    # gclpr deliberately connects to localhost. Proxy that stable guest
    # endpoint to the server bound to the Mac's loopback interface.
    systemd.sockets.gclpr-host-proxy = {
      wantedBy = [ "sockets.target" ];
      listenStreams = [ "127.0.0.1:${toString cfg.port}" ];
    };
    systemd.services.gclpr-host-proxy = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig.ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd ${lib.escapeShellArg "${cfg.host}:${toString cfg.port}"}";
    };
  };
}
