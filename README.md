# Machines

Persistent ARM64 NixOS development/build machines and local deployment targets,
using Apple Container machine mode. Requires Apple Silicon and macOS 26.
**Nix, devenv and application toolchains run inside Linux, not on the Mac.**

## Start on a fresh laptop

Run this in the Mac's terminal. No Nix, Git or GitHub login is needed:

```sh
curl -fsSL https://raw.githubusercontent.com/shamaazi/machines/main/bootstrap.sh | bash
```

It downloads this public repository to `~/projects/machines`, installs the verified
Apple Container CLI, prepares the NixOS image in a temporary Linux builder,
starts the persistent dev VM and opens its SSH shell. The Mac only uses its
built-in shell, curl, tar, SSH and system utilities. You can [inspect the script](bootstrap.sh)
before running it. Rerunning it resumes the existing machine and reconnects;
it does not pull over an existing checkout or replace the installed system.
Set `MACHINES_REPO` to choose a different source directory.

Inside the dev VM, **git, gh and devenv** are already installed. Authenticate
GitHub when needed, clone your application repository and run its normal
`devenv shell`, `devenv up` and `devenv test` commands. Application runtimes and
services belong to that project's devenv. A remote editor connects with the
SSH configuration printed during setup and edits the VM's checkout directly.

The dev VM defaults to 8 CPUs/10 GiB. Its disk retains checkouts, Nix caches and
service data. No Mac home or application source is mounted or copied into it.
SSH-agent forwarding is disabled and the Apple-mounted agent socket is detached
at boot.

## Mac commands

From `~/projects/machines`, use the native `machine` command:

```sh
./machine dev up       # create or resume, building a missing base image
./machine dev shell    # reconnect over SSH
./machine dev status
./machine dev forward # loopback browser forwarding; keep running
./machine dev stop    # preserve the disk, release memory
```

Defaults forward Mac port 18081 to guest port 80. Match the application's port
using `MACHINES_DEV_REMOTE_PORT`, and optionally `MACHINES_DEV_LOCAL_PORT`.
For example, an app configured for port 18081 needs:

```sh
MACHINES_DEV_REMOTE_PORT=18081 ./machine dev forward
```

Configuration uses optional environment variables, not a required Nix file.
Persistent settings can go in an ignored `machines.env` beside the command;
it is sourced as shell configuration before each command:

```sh
MACHINES_DEV_MEMORY=12G
```

| Variable | Default |
| --- | --- |
| `MACHINES_HOME` | `~/.local/share/machines` |
| `MACHINES_DEV_NAME` / `MACHINES_TARGET_NAME` | `dev-build` / `deployment-target` |
| `MACHINES_USER` | `developer` |
| `MACHINES_DEV_CPUS` / `MACHINES_DEV_MEMORY` | `8` / `10G` |
| `MACHINES_TARGET_CPUS` / `MACHINES_TARGET_MEMORY` | `4` / `8G` |
| `MACHINES_DEV_LOCAL_PORT` / `MACHINES_DEV_REMOTE_PORT` | `18081` / `80` |
| `MACHINES_TARGET_LOCAL_PORT` / `MACHINES_TARGET_REMOTE_PORT` | `18080` / `80` |

Resource settings apply when creating a machine. Apple's `machine set` can change
CPU/memory allocations after restart. `*:up` refreshes SSH addresses after a
restart; repeat target pairing if its address changed. To adopt existing machines,
set their existing `MACHINES_HOME`, names and development user. Adoption only
resumes the guests and configures SSH; it preserves their installed systems,
users, disks and application data. Temporary SSH adoption settings last until
reboot/activation, so installed systems must retain compatible SSH configuration.

## Deployment target

The separate target defaults to 4 CPUs/8 GiB:

```sh
./machine target up
./machine target pair
```

Pairing creates a deployment key **inside the dev VM**, authorizes its public key
on the target and pins the target host key through Apple's local transport.
Inside the dev VM, use `~/.local/share/machines/target/ssh_config`, destination
`target`. Credentials belong to the machine, independently of application checkouts.

The application repository composes its NixOS services with
`inputs.machines.nixosModules.appleTarget` on every local deployment. This provides
the Apple platform and key-only target SSH on port 2222. Build applications and
NixOS generations inside the dev VM, then transfer/activate with the application's
deployment tooling. The target needs no source checkout or devenv shell.

`./machine target forward` defaults to Mac port 18080 and guest port 80; select
`MACHINES_TARGET_REMOTE_PORT` to match the deployed application. `target status`
and `target stop` work like their dev counterparts.

## NixOS modules and builds

The flake exports `base`, `development`, `target`, `apple` and `appleTarget` modules
without a Nixpkgs input; consuming projects supply their own pin. `target` is the
generic SSH/base role and `appleTarget` adds Apple's platform. Other platforms
supply their own hardware/boot configuration. No EC2 disk layout is defined here.

Initial image builds use a Linux bootstrap builder (4 CPUs/6 GiB), stopped after
a successful build. It only receives the generic NixOS sources and lockfile;
Nix is never installed on the Mac. Explicit `./machine dev build` and
`./machine target build` rebuild base images. Normal project builds use the
persistent dev VM with sandboxing. The optional devenv tasks wrap the same commands
for contributors who already use devenv; onboarding does not depend on them.

Apple supplies the kernel, network and virtual disk. This tests NixOS activation,
services and rollback, not bootloader/kernel installation. Apple may report an
early user-setup race while NixOS activates; `up` waits for readiness and verifies
SSH before succeeding. Stopping unused guests releases their allocated memory.
System rollback never restores databases/files; backups and data migration policy
belong to the application owner.

Private keys, machine state and local configuration must never be committed.
