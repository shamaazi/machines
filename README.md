# Machines

A persistent NixOS development VM for Apple Silicon Macs, with git, gh and devenv.

## Setup (Mac)

1. If Nix manages your SSH config, apply the setting below first.
2. Run:

   ```sh
   curl -fsSL https://raw.githubusercontent.com/shamaazi/machines/main/bootstrap.sh | bash
   ```

3. Paste the automatically copied GitHub code into the browser and approve access.

The VM can open your Mac browser and read or replace its clipboard.

## Nix-managed SSH config (optional)

Add and apply this Home Manager setting before setup:

```nix
programs.ssh.includes = [ "~/.lima/dev/ssh.config" ];
```

The include must be a standalone line before any `Host` or `Match` blocks.
Bootstrap adds it automatically for writable configs and leaves existing includes untouched.

## Connect (Mac)

```sh
ssh lima-dev
```

## Update the VM (Mac)

```sh
limactl shell dev -- sudo nixos-rebuild boot --flake github:shamaazi/machines#dev && limactl restart dev
```

## Change VM resources (Mac)

Defaults: all CPU cores, host RAM minus 8 GiB, and an 80 GiB disk.
Adjust the values below; omit flags you do not need. Disk size can only increase.

```sh
limactl stop dev
limactl edit dev --yes --cpus 8 --memory 16 --disk 120
limactl start dev
```

Memory and disk sizes are in GiB. Leave enough RAM for macOS.

## AI agents (inside the VM)

Install your preferred agent in your user Nix profile. Codex is an example;
replace it with another Nixpkgs package name.

```sh
nix profile add nixpkgs#codex
nix profile upgrade codex
nix profile upgrade --all
```

Use Nix to update these packages. Desktop apps manage their own remote runtimes separately.
