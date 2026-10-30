# Machines

A persistent NixOS development VM for Apple Silicon Macs, with git, gh, devenv and Codex.

Initial setup:

```sh
curl -fsSL https://raw.githubusercontent.com/shamaazi/machines/main/bootstrap.sh | bash
```

Sign in to GitHub in the browser when prompted.

Update from the Mac:

```sh
limactl shell dev -- sudo nixos-rebuild boot --flake github:shamaazi/machines#dev && limactl restart dev
```

The bootstrap links the VM with the Mac browser and clipboard. Any process in
the VM can read or replace the Mac clipboard.
