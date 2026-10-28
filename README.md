# Machines

Persistent ARM64 NixOS development/build machines and local deployment targets,
provisioned with devenv and Apple Container machine mode. Requires Apple Silicon,
macOS 26 and Nix. Application repositories supply their own devenv toolchain,
packages and deployment configuration.

## Start on a fresh laptop

Install [Nix](https://nixos.org/download/), then fetch this public repository
without GitHub authentication:

```sh
nix shell nixpkgs#git nixpkgs#gh nixpkgs#devenv
git clone https://github.com/shamaazi/machines.git
cd machines
devenv tasks list
devenv tasks run dev:build --show-output
devenv tasks run dev:up --show-output
devenv shell
ssh -F "$MACHINES_HOME/ssh/dev/config" dev
```

The base development machine includes **git, gh and devenv**, plus SSH and basic
Linux tools. Inside it, authenticate GitHub if your application repository is
private, clone that repository, and use its normal `devenv shell`, `devenv up` and
`devenv test` commands. Application runtimes belong to that project's devenv.
Editors can connect using the SSH configuration printed by `dev:up`.

The dev machine defaults to 8 CPUs/10 GiB. The target defaults to 4 CPUs/8 GiB.
Their persistent disks retain checkouts, Nix caches and service data. No Mac home
or application source is mounted or copied into either machine. Host SSH-agent
forwarding is disabled, and the Apple-mounted agent socket is detached at boot.

## Deployment target

```sh
devenv tasks run target:build --show-output
devenv tasks run target:up --show-output
devenv tasks run target:pair --show-output
```

Pairing creates a deployment key **inside the dev machine**, authorizes only its
public key on the target, and pins the target host key through Apple's local
transport. In the dev machine, the resulting SSH configuration is
`~/.local/share/machines/target/ssh_config`, with destination `target`.
It is independent of any application checkout.

Application deployment must compose its NixOS services with
`inputs.machines.nixosModules.appleTarget` on every deployment. This module
provides the Apple platform and key-only target SSH on port 2222. Build the
application and system generation in the dev machine, then transfer and activate
with the application's deployment tooling. The target does not need a devenv
shell or source checkout to run installed services.

The flake exports `base`, `development`, `target`, `apple` and `appleTarget`
NixOS modules. It has no Nixpkgs input: the consuming project supplies its own
pin. `target` is the generic SSH/base role; `appleTarget` adds Apple's platform.
Other platforms supply their own hardware/boot modules alongside `target`.
No EC2 provisioning or production disk layout is defined here.

## Local settings and operation

State defaults to `.devenv/machines`. For a durable location outside the checkout,
create an ignored `devenv.local.nix` before setup:

```nix
{ ... }: {
  env = {
    MACHINES_HOME = "/absolute/path/to/machine-state";
    MACHINES_USER = "developer";
    MACHINES_DEV_CPUS = "8";
    MACHINES_DEV_MEMORY = "10G";
    MACHINES_TARGET_CPUS = "4";
    MACHINES_TARGET_MEMORY = "8G";
    MACHINES_DEV_LOCAL_PORT = "18081";
    MACHINES_DEV_REMOTE_PORT = "80";
    MACHINES_TARGET_LOCAL_PORT = "18080";
    MACHINES_TARGET_REMOTE_PORT = "80";
  };
}
```

`machine:setup` verifies and extracts Apple's signed 1.6.1 CLI into that state
directory, then starts its private runtime. Apple may report an initial user-setup
race while NixOS activates; `*:up` checks guest readiness and SSH before succeeding. Image builds use a separate Linux
bootstrap builder (4 CPUs/6 GiB), stopped after a successful build. This builder
only receives the generic NixOS modules and lockfile. Normal project builds use
the persistent development machine with Nix sandboxing.

`dev:forward` and `target:forward` run loopback-only SSH port forwarding in the
foreground; select ports matching the application's configuration. `dev:status`
and `target:status` inspect resources and failed systemd units. `dev:stop` and
`target:stop` stop guests while preserving their disks. Rerun `*:up` after a
restart to refresh pinned SSH addresses, then `target:pair` if its address changed.
Resource settings apply when creating a machine. Apple's `machine set` can change
CPU/memory for an existing machine after restart.

To adopt existing machines, set `MACHINES_HOME` to their existing runtime state,
`MACHINES_DEV_NAME` and `MACHINES_TARGET_NAME` to their names, and `MACHINES_USER`
to the existing development user. `*:up` resumes and configures SSH; it never
installs a base generation over an existing machine. Its SSH adoption override
lasts until reboot or NixOS activation, so deployed targets must include the
exported module and adopted dev machines must retain compatible SSH configuration.
It does not migrate users, disks or application data.

Apple supplies the kernel, network and virtual disk. This exercises NixOS
activation, services and rollback, but not bootloader/kernel installation.
Machine mode also retains allocated memory more aggressively than native macOS
processes; stopping an unused guest releases it. System rollback never restores
application databases or files. Backups and data migration policy belong to the
application owner.

Machine state, private keys, local settings and logs are ignored. Do not commit
credentials. Fresh-laptop public access needs no GitHub login; private projects
and `gh` operations may still require authentication.
