{ pkgs }:
pkgs.stdenvNoCC.mkDerivation {
  pname = "codex";
  version = "0.165.0";
  src = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v0.165.0/codex-aarch64-unknown-linux-musl.tar.gz";
    hash = "sha256-ZSLgVtC+f1MdqRXJqBrgW8cIEbeCVCSZzAqXdtOr9dM=";
  };
  appServer = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v0.165.0/codex-app-server-package-aarch64-unknown-linux-musl.tar.gz";
    hash = "sha256-ZWlwp8eIp317fp1JDnZN9e6OE5Ancu1RgRyPsXrGvnU=";
  };
  dontUnpack = true;
  dontStrip = true;
  installPhase = ''
    mkdir -p $out/bin
    tar -xzf $src -C $out/bin
    mv $out/bin/codex-aarch64-unknown-linux-musl $out/bin/codex
    # The app server locates its helper and resources relative to its executable.
    tar -xzf $appServer -C $out
  '';
}
