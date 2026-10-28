# Machines

Persistent NixOS development VMs on Apple Silicon/macOS 26. The Mac needs no Nix,
Git or GitHub login:

```sh
curl -fsSL https://raw.githubusercontent.com/shamaazi/machines/main/bootstrap.sh | bash
```

This downloads the tooling to `~/projects/machines`, installs Apple Container,
verifies the prebuilt dev image and opens its SSH shell. The VM has **git, gh and
devenv**, 8 CPUs and 10 GiB RAM. Clone your application inside it and use that
project's devenv. Repeating bootstrap resumes the VM; it never creates a deployment target.

From the Mac checkout:

```sh
./machine dev up
./machine dev shell
./machine dev status
./machine dev forward # Mac 18081 -> guest 80; keep running
./machine dev stop    # preserves the disk
```

State lives in `~/.local/share/machines`. Optional settings go in `machines.env`
(ignored), or the environment:

```sh
MACHINES_DEV_MEMORY=12G
MACHINES_DEV_REMOTE_PORT=18081 # match the application's configured browser port
```

Settings include `MACHINES_HOME`, `MACHINES_DEV_NAME`, `MACHINES_DEV_CPUS`,
`MACHINES_DEV_MEMORY`, `MACHINES_DEV_LOCAL_PORT` and `MACHINES_DEV_REMOTE_PORT`.
Resource settings apply at creation; use Apple's `machine set` and restart to
resize an existing VM. Editors can use the SSH config printed by `up`.
There is no Mac home sharing or SSH-agent forwarding.

## Optional deployment target

This is separate from onboarding. Create and pair it explicitly:

```sh
./machine target up
./machine target pair
```

The target defaults to 4 CPUs/8 GiB. It supports the same lifecycle commands and
`MACHINES_TARGET_*` settings; forwarding defaults to Mac 18080 -> guest 80.
Pairing creates a key inside the dev VM and pins the target's host key. Applications
use `~/.local/share/machines/target/ssh_config`, destination `target`.
Their NixOS deployment imports `inputs.machines.nixosModules.appleTarget` alongside
application services. Builds run in the dev VM; the target receives artifacts.
Apple owns the kernel/disk, so this tests activation and services, not NixOS boot
upgrades. System rollback does not restore application data.

## Image maintenance

`images.json` pins public release archives and SHA-256 checksums. The **Publish base
images** workflow builds both ARM64 roles from the Nixpkgs lock. Dispatch a new
`base-YYYY-MM-DD` release (append `-N` for another that day), test its images, then
commit the released `images.json`. Existing VMs are not reinstalled when pins change.

For local image work, run `nix-build --impure nixos/image.nix --argstr role dev`
(or `target`) in Linux. Import the resulting OCI archive on the Mac and set
`MACHINES_DEV_IMAGE=nixos-dev:local` to test it. `devenv test` runs repository checks.
