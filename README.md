# Machines

Run on an Apple Silicon Mac:

```sh
curl -fsSL https://raw.githubusercontent.com/shamaazi/machines/main/bootstrap.sh | bash
```

One-time setup installs Lima if needed (using sudo), downloads our preconfigured
NixOS image, and opens a shell with git, gh and devenv. No Mac checkout, host Nix
or GitHub login is required. The VM starts at login.

Use `limactl shell dev` to connect, `limactl stop dev` to stop, and
`limactl start dev` to start. Editors and Codex use SSH host `lima-dev`;
devenv's `.localhost` URLs use automatic port forwarding. New VMs use all CPU
cores, RAM minus 8 GiB for macOS, and an 80 GiB disk. State lives in `~/.lima`.
Deployment targets are separate. Disable login startup with
`limactl autostart disable dev`.

Update an existing VM from inside it, then run `limactl restart dev` on the Mac:

```sh
sudo nixos-rebuild boot --flake github:shamaazi/machines#dev
```

Build and compress the release image on ARM64 Linux:

```sh
nix build .#image
gzip -c result/*.qcow2 > nixos-dev-aarch64.qcow2.gz
```

The image uses the same `nixosConfigurations.dev` as remote rebuilds, with
NixOS's built-in EFI image format. Replace the image in the `latest` release and
update its digest in `lima.yaml` when publishing. CI is disabled.
