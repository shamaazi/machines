# Machines

A persistent NixOS development VM for Apple Silicon Macs, with git, gh, devenv and Codex.

Initial setup:

```sh
curl -fsSL https://raw.githubusercontent.com/shamaazi/machines/main/bootstrap.sh | bash
```

Update from the Mac:

```sh
limactl shell dev -- sudo nixos-rebuild boot --flake github:shamaazi/machines#dev && limactl restart dev
```
