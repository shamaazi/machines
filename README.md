# Machines

A persistent NixOS development VM for Apple Silicon Macs, with git, gh and devenv.

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

## AI agents

The image does not bundle an AI agent. Install your preferred CLI in your user
Nix profile by running these commands inside the VM. For example, to install Codex:

```sh
nix profile add nixpkgs#codex
```

Use the corresponding Nixpkgs package name to install another agent.

Update one agent, or all packages in your user profile:

```sh
nix profile upgrade codex
nix profile upgrade --all
```

These commands do not require sudo or a VM rebuild. Updates use the version
available in the package source, which may lag the vendor's latest release.
Keep an updatable package reference such as `nixpkgs#codex` to receive updates;
a reference pinned to a specific commit stays pinned.

For tools installed this way, use Nix to update them rather than their built-in
updaters. Desktop apps that deploy their own remote runtimes manage those
separately; installing a CLI in a Nix profile does not control those runtimes.
